import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cap_error.dart';
import 'cap_native_solver.dart';
import 'html_builder.dart' show kDefaultWidgetJsUrl;
import 'js_engine.dart';

/// Headless Cap client that solves challenges without any visible UI.
///
/// Solving runs through the official widget's programmatic mode
/// (`new Cap(...).solve()`) — inside a [HeadlessInAppWebView] on IO
/// platforms, or directly in the page through `dart:js_interop` on the web —
/// so every challenge protocol the official widget supports works, including
/// HashWX and instrumentation challenges.
///
/// ```dart
/// final solver = CapSolver(apiEndpoint: 'https://cap.example.com/<key>/');
/// final token = await solver.solve();
/// // ... send `token` to your backend, which verifies it via /siteverify
/// await solver.dispose();
/// ```
class CapSolver {
  /// Creates a headless solver.
  CapSolver({
    required this.apiEndpoint,
    this.workerCount,
    this.widgetJsUrl = kDefaultWidgetJsUrl,
    this.wasmUrl,
    this.hashwxUrl,
    this.loadTimeout = const Duration(seconds: 30),
    this.preferNative = false,
    this.nativeUserAgent,
    this.onProgress,
    this.onError,
  });

  /// The Cap API endpoint including the site key, e.g.
  /// `https://<your-instance>/<site-key>/`.
  final String apiEndpoint;

  /// Number of solver worker threads. Defaults to the device's core count.
  final int? workerCount;

  /// URL of the `cap-widget` script. Defaults to jsDelivr; point this at your
  /// Standalone asset server (`/assets/widget.js`) to self-host.
  final String widgetJsUrl;

  /// Custom `cap_wasm` URL (`window.CAP_CUSTOM_WASM_URL`).
  final String? wasmUrl;

  /// Custom HashWX WASM URL (`window.CAP_CUSTOM_HASHWX_URL`).
  final String? hashwxUrl;

  /// Maximum time [warmup] waits for the widget script/engine to load.
  final Duration loadTimeout;

  /// Try solving natively in Dart first, without a WebView.
  ///
  /// Works when the site key uses the SHA-256 PoW protocol and has
  /// instrumentation challenges disabled. If the fetched challenge needs a
  /// JS/WASM environment (HashWX, RSW, or instrumentation), the solver
  /// automatically falls back to the JavaScript engine path. On the web this
  /// flag is ignored — the JS engine is already native to the browser and
  /// the Dart worker pool would only block the main thread.
  final bool preferNative;

  /// `User-Agent` for the native solver's HTTP requests. Defaults to an
  /// Android WebView UA; see [CapNativeSolver.userAgent].
  final String? nativeUserAgent;

  /// Called with solve progress in `[0, 100]`.
  final void Function(double progress)? onProgress;

  /// Called when solving fails.
  final void Function(CapError error)? onError;

  CapJsEngine? _engine;
  CapNativeSolver? _native;
  bool _solving = false;
  String? _token;

  /// The token produced by the most recent successful solve, if any.
  String? get token => _token;

  /// Whether a [solve] call is currently in flight.
  bool get solving => _solving;

  String get _normalizedEndpoint =>
      apiEndpoint.endsWith('/') ? apiEndpoint : '$apiEndpoint/';

  CapJsEngine get _jsEngine => _engine ??= CapJsEngine(
    apiEndpoint: _normalizedEndpoint,
    workerCount: workerCount,
    widgetJsUrl: widgetJsUrl,
    wasmUrl: wasmUrl,
    hashwxUrl: hashwxUrl,
    loadTimeout: loadTimeout,
    onEvent: _handleEvent,
  );

  /// Loads the widget script/engine so a later [solve] skips its startup
  /// latency.
  ///
  /// Called automatically by [solve]; invoke it eagerly (e.g. right before
  /// showing a form). When [preferNative] is set, the native solver's HTTP
  /// connection is pre-warmed at the same time.
  Future<void> warmup() async {
    if (preferNative && !kIsWeb) {
      unawaited(_nativeSolver.warmup());
    }
    await _jsEngine.warmup();
  }

  /// Requests a challenge, solves it and returns the verification token.
  ///
  /// When [preferNative] is set (IO platforms only), tries the WebView-free
  /// [CapNativeSolver] first and only spins up the JavaScript engine when the
  /// challenge can't be solved natively.
  ///
  /// Throws [CapError] if solving fails. Progress is reported through
  /// [onProgress].
  Future<String> solve() async {
    if (_solving) {
      throw StateError('A solve is already in progress.');
    }
    _solving = true;
    try {
      if (preferNative && !kIsWeb) {
        try {
          return await _solveNatively();
        } on CapNativeUnsupportedException {
          // Fall back to the JavaScript engine path below.
        }
      }
      return _token = await _jsEngine.solve();
    } finally {
      _solving = false;
    }
  }

  /// Clears the stored token and resets the underlying widget.
  Future<void> reset() async {
    _token = null;
    await _engine?.reset();
  }

  CapNativeSolver get _nativeSolver => _native ??= CapNativeSolver(
    apiEndpoint: apiEndpoint,
    workerCount: workerCount,
    userAgent: nativeUserAgent ?? CapNativeSolver.defaultUserAgent,
    onProgress: onProgress,
  );

  Future<String> _solveNatively() async {
    // Reuse the native solver so its HTTP keep-alive connection survives
    // across solves — a fresh instance would redo the TLS handshake (~100ms+)
    // on every call.
    final solver = _nativeSolver;
    try {
      return _token = await solver.solve();
    } on CapError catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  /// Disposes the solver's engine. The solver cannot be used afterwards.
  Future<void> dispose() async {
    _token = null;
    _solving = false;
    _native?.close();
    _native = null;
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }

  void _handleEvent(String type, Object? detail) {
    switch (type) {
      case 'solve':
        final token = detail is Map ? detail['token']?.toString() : null;
        if (token != null) _token = token;
      case 'progress':
        final raw = detail is Map ? detail['progress'] : null;
        if (raw is num) onProgress?.call(raw.toDouble());
      case 'error':
        onError?.call(CapError.fromEventDetail(detail));
      case 'reset':
        _token = null;
    }
  }
}
