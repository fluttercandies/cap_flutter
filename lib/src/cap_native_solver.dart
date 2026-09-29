import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cap_error.dart';
import 'cap_prng.dart';
import 'pow_pool.dart';

/// Thrown when a challenge cannot be solved natively — e.g. it uses the
/// HashWX/RSW format or carries an instrumentation challenge, both of which
/// need a JavaScript/WASM environment. Callers should fall back to the
/// WebView-backed solver.
class CapNativeUnsupportedException implements Exception {
  /// Creates the exception.
  const CapNativeUnsupportedException(this.reason);

  /// Why the challenge can't be solved natively.
  final String reason;

  @override
  String toString() => 'CapNativeUnsupportedException: $reason';
}

/// Solves Cap SHA-256 proof-of-work challenges entirely in Dart — no WebView,
/// no JavaScript. Works on any platform Flutter runs on.
///
/// On IO platforms challenges are spread across an isolate pool; on the web
/// they run sequentially on the main thread (see [PowPool]).
///
/// Limitations (both are server-side key settings):
///
/// * the site key must use the **SHA-256 PoW** challenge protocol
/// * **instrumentation challenges must be off** — they execute obfuscated
///   JavaScript that can't run outside a browser engine
///
/// ```dart
/// final solver = CapNativeSolver(apiEndpoint: 'https://cap.example.com/<key>/');
/// final token = await solver.solve();
/// ```
class CapNativeSolver {
  /// Default `User-Agent` used for challenge/redeem requests.
  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  /// Creates a native solver.
  CapNativeSolver({
    required this.apiEndpoint,
    this.workerCount,
    this.userAgent = defaultUserAgent,
    this.onProgress,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The Cap API endpoint including the site key, e.g.
  /// `https://<your-instance>/<site-key>/`.
  final String apiEndpoint;

  /// Number of isolates used to solve challenges in parallel. Defaults to
  /// the platform worker count (`Platform.numberOfProcessors` on IO, `1` on
  /// the web).
  final int? workerCount;

  /// `User-Agent` header sent with challenge/redeem requests.
  ///
  /// Defaults to an Android WebView UA so the requests pass
  /// `blockNonBrowserUA` filtering when it is enabled on the key.
  final String userAgent;

  /// Called with solve progress in `[0, 100]`.
  final void Function(double progress)? onProgress;

  final http.Client _http;
  final PowPool _pool = PowPool();
  var _solving = false;

  String get _normalizedEndpoint =>
      apiEndpoint.endsWith('/') ? apiEndpoint : '$apiEndpoint/';

  Uri get _challengeUri => Uri.parse('${_normalizedEndpoint}challenge');
  Uri get _redeemUri => Uri.parse('${_normalizedEndpoint}redeem');

  /// Fetches a challenge and, when it is a plain seeded SHA-256 challenge,
  /// solves and redeems it — all in Dart.
  ///
  /// Throws [CapNativeUnsupportedException] when the challenge needs a
  /// JavaScript environment (HashWX/RSW format or instrumentation data), and
  /// [CapError] for network/protocol errors.
  Future<String> solve() async {
    final challenge = await fetchChallenge();
    final solutions = await solveChallenges(challenge);
    return redeem(challenge, solutions);
  }

  /// Pre-warms the HTTP connection (TCP+TLS handshake) so the first
  /// [fetchChallenge] skips the connection setup latency. Errors are
  /// swallowed — this is best-effort latency hiding.
  Future<void> warmup() async {
    try {
      await _http.head(
        Uri.parse(_normalizedEndpoint),
        headers: {'User-Agent': userAgent},
      );
    } catch (_) {}
  }

  /// Fetches a challenge from the server and validates it can be solved
  /// natively.
  Future<CapChallenge> fetchChallenge() async {
    final response = await _post(_challengeUri, const {});
    final body = _decode(response);
    return CapChallenge.parse(body);
  }

  /// Solves every `[salt, target]` pair in [challenge] across the platform
  /// worker pool and returns the nonces in challenge order.
  ///
  /// On IO, workers pull one challenge at a time (work-stealing): PoW solve
  /// times follow a geometric distribution, so a static chunked split lets
  /// the worker that happens to hold the hardest challenges stall every
  /// other idle core. Dynamic dispatch keeps all cores busy until the queue
  /// drains. On the web the work runs sequentially on the main thread.
  Future<List<int>> solveChallenges(CapChallenge challenge) async {
    if (_solving) {
      throw StateError('A solve is already in progress.');
    }
    _solving = true;
    try {
      final pairs = expandSeededChallenges(
        challenge.token,
        count: challenge.count,
        size: challenge.size,
        difficulty: challenge.difficulty,
      );
      return await _pool.solveAll(
        pairs,
        workerCount: workerCount,
        onProgress: onProgress,
      );
    } finally {
      _solving = false;
    }
  }

  /// Redeems [solutions] for [challenge] and returns the verification token.
  Future<String> redeem(CapChallenge challenge, List<int> solutions) async {
    final response = await _post(_redeemUri, {
      'token': challenge.token,
      'solutions': solutions,
    });
    final body = _decode(response);
    final token = body['token'];
    if (body['success'] == true && token is String) return token;
    throw CapError(
      message: body['error']?.toString() ?? 'Cap redeem failed.',
      code: 'redeem_failed',
      raw: body,
    );
  }

  /// Releases the HTTP client and terminates the worker pool.
  void close() {
    _pool.dispose();
    _http.close();
  }

  Future<http.Response> _post(Uri uri, Object body) async {
    final http.Response response;
    try {
      response = await _http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'User-Agent': userAgent},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw CapError(message: 'Network error: $e', code: 'network_error');
    }
    if (response.statusCode == 429) {
      throw const CapError(
        message: 'Rate limited by Cap server',
        code: 'network_error',
      );
    }
    return response;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
    } catch (_) {}
    throw CapError(
      message:
          'Unexpected response from Cap server (HTTP ${response.statusCode})',
      code: 'challenge_parse_error',
      raw: response.body,
    );
  }
}

/// A fetched Cap challenge in the seeded SHA-256 format.
class CapChallenge {
  /// Creates a challenge.
  const CapChallenge({
    required this.token,
    required this.count,
    required this.size,
    required this.difficulty,
    this.expires,
  });

  /// The signed challenge token (seed for the PRNG expansion).
  final String token;

  /// Number of challenges to solve (`c`).
  final int count;

  /// Salt size in hex chars (`s`).
  final int size;

  /// Difficulty in hex chars (`d`).
  final int difficulty;

  /// Expiry timestamp (ms since epoch), if provided.
  final int? expires;

  /// Parses a `/challenge` response body.
  ///
  /// Throws [CapNativeUnsupportedException] for non-SHA-256 formats and for
  /// challenges carrying instrumentation data.
  factory CapChallenge.parse(Map<String, dynamic> body) {
    final error = body['error'];
    if (error != null) {
      throw CapError(message: error.toString(), raw: body);
    }
    if (body['instrumentation'] != null) {
      throw const CapNativeUnsupportedException(
        'challenge carries instrumentation data',
      );
    }
    final token = body['token'];
    final challenge = body['challenge'];
    if (token is! String || challenge is! Map) {
      throw const CapNativeUnsupportedException(
        'unexpected challenge response format',
      );
    }
    final c = challenge['c'], s = challenge['s'], d = challenge['d'];
    if (c is! int || s is! int || d is! int) {
      throw const CapNativeUnsupportedException(
        'challenge is not the seeded SHA-256 format',
      );
    }
    if (_jwtPayloadHasInstr(token)) {
      throw const CapNativeUnsupportedException(
        'challenge token requires instrumentation',
      );
    }
    return CapChallenge(
      token: token,
      count: c,
      size: s,
      difficulty: d,
      expires: (body['expires'] as num?)?.toInt(),
    );
  }

  static bool _jwtPayloadHasInstr(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['ei'] != null;
    } catch (_) {
      return false;
    }
  }
}
