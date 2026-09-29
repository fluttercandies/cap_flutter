import 'package:cap_flutter/cap_flutter.dart';
import 'package:flutter/material.dart';

/// Cap endpoint of a deployed Standalone instance:
/// `https://<instance>/<site-key>/`. For local testing, `docker compose up -d`
/// at the repo root starts one on :3210 (reachable from a device via
/// `adb reverse tcp:3210 tcp:3210`).
///
/// Inject real endpoints at build time (kept out of source control):
///
/// ```sh
/// flutter run \
///   --dart-define=CAP_API_ENDPOINT=https://<instance>/<hashwx-key>/ \
///   --dart-define=CAP_SHA256_API_ENDPOINT=https://<instance>/<sha256-key>/
/// ```
///
/// This key should use HashWX + instrumentation — it exercises the
/// JavaScript-engine path.
const String kCapApiEndpoint = String.fromEnvironment(
  'CAP_API_ENDPOINT',
  defaultValue: 'https://cap.example.com/<site-key>/',
);

/// A SHA-256 PoW key with instrumentation disabled — exercises the
/// WebView-free [CapNativeSolver] path.
const String kCapSha256ApiEndpoint = String.fromEnvironment(
  'CAP_SHA256_API_ENDPOINT',
  defaultValue: 'https://cap.example.com/<site-key>/',
);

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cap_flutter example',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CapController _controller = CapController();
  final CapSolver _solver = CapSolver(apiEndpoint: kCapApiEndpoint);
  final CapSolver _nativeSolver = CapSolver(
    apiEndpoint: kCapSha256ApiEndpoint,
    preferNative: true,
  );

  String? _token;
  double _progress = 0;
  String _status = 'idle';

  @override
  void dispose() {
    _solver.dispose();
    _nativeSolver.dispose();
    super.dispose();
  }

  Future<void> _solve(
    CapSolver solver,
    String label, {
    bool warmup = true,
  }) async {
    setState(() {
      _status = warmup ? 'warming up ($label)…' : 'solving ($label)…';
      _token = null;
    });
    try {
      final sw = Stopwatch()..start();
      if (warmup) {
        await solver.warmup();
        setState(
          () => _status =
              'warmed ($label) in ${sw.elapsedMilliseconds}ms, solving…',
        );
      }
      final token = await solver.solve();
      setState(() {
        _token = token;
        _status = 'solved in ${sw.elapsedMilliseconds}ms';
      });
    } on CapError catch (e) {
      setState(() => _status = 'error: ${e.message}');
    } catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('cap_flutter example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Visible widget', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          CapWidget(
            apiEndpoint: kCapApiEndpoint,
            controller: _controller,
            i18n: const CapI18n(
              initialState: '验证你是人类',
              verifyingLabel: '验证中…',
              solvedLabel: '验证通过',
              errorLabel: '出错，请重试',
            ),
            theme: CapTheme(textColor: Theme.of(context).colorScheme.onSurface),
            onSolved: (token) => setState(() {
              _token = token;
              _status = 'solved';
            }),
            onProgress: (p) => setState(() {
              _progress = p;
              _status = 'solving… ${p.toStringAsFixed(0)}%';
            }),
            onError: (e) => setState(() => _status = 'error: ${e.message}'),
            onReset: () => setState(() {
              _token = null;
              _status = 'idle';
            }),
          ),
          const SizedBox(height: 32),
          const Text('Headless solver', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _solve(_solver, 'headless webview'),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Solve in background'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _solve(_nativeSolver, 'native', warmup: false),
            icon: const Icon(Icons.bolt_outlined),
            label: const Text('Solve natively (no WebView)'),
          ),
          const SizedBox(height: 32),
          Text('Status: $_status'),
          if (_progress > 0 && _progress < 100)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(value: _progress / 100),
            ),
          const SizedBox(height: 8),
          SelectableText(
            'Token: ${_token ?? '-'}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
