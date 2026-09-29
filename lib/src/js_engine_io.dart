import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'cap_error.dart';
import 'html_builder.dart';
import 'js_engine.dart';

CapJsEngine createCapJsEngine({
  required String apiEndpoint,
  int? workerCount,
  required String widgetJsUrl,
  String? wasmUrl,
  String? hashwxUrl,
  required Duration loadTimeout,
  required CapEngineEventCallback onEvent,
}) => _IoCapJsEngine(
  apiEndpoint: apiEndpoint,
  workerCount: workerCount,
  widgetJsUrl: widgetJsUrl,
  wasmUrl: wasmUrl,
  hashwxUrl: hashwxUrl,
  loadTimeout: loadTimeout,
  onEvent: onEvent,
);

/// IO engine: hosts the official widget in a [HeadlessInAppWebView] and
/// bridges its events through the `capEvent` JavaScript handler.
class _IoCapJsEngine implements CapJsEngine {
  _IoCapJsEngine({
    required this.apiEndpoint,
    required this.widgetJsUrl,
    required this.loadTimeout,
    required this.onEvent,
    this.workerCount,
    this.wasmUrl,
    this.hashwxUrl,
  });

  final String apiEndpoint;
  final int? workerCount;
  final String widgetJsUrl;
  final String? wasmUrl;
  final String? hashwxUrl;
  final Duration loadTimeout;
  final CapEngineEventCallback onEvent;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  Completer<void>? _readyCompleter;

  Uri get _endpointOrigin =>
      Uri.parse(apiEndpoint).replace(path: '/', query: '', fragment: '');

  @override
  Future<void> warmup() async {
    if (_headless != null) return _readyCompleter!.future;

    _readyCompleter = Completer<void>();
    _headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: buildCapHtml(
          apiEndpoint: apiEndpoint,
          workerCount: workerCount,
          widgetJsUrl: widgetJsUrl,
          wasmUrl: wasmUrl,
          hashwxUrl: hashwxUrl,
        ),
        baseUrl: WebUri.uri(_endpointOrigin),
      ),
      initialSettings: InAppWebViewSettings(
        domStorageEnabled: true,
        isFraudulentWebsiteWarningEnabled: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: kCapEventHandler,
          callback: _handleEvent,
        );
      },
      // NOTE: readiness is signaled by the page's 'ready' event (posted once
      // the module script has defined __capSolve) — not onLoadStop. Some
      // engines (e.g. ArkWeb on OpenHarmony) fire the load event before
      // top-level-await module scripts finish evaluating.
      onLoadStop: (controller, url) {},
      onReceivedError: (controller, request, error) {
        if ((request.isForMainFrame ?? false) &&
            !(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter?.completeError(
            CapError(
              message: 'Failed to load Cap widget page: ${error.description}',
            ),
          );
        }
      },
    );

    await _headless!.run();
    try {
      return await _readyCompleter!.future.timeout(loadTimeout);
    } catch (_) {
      // A timed-out/failed load leaves the completer incomplete — tear the
      // WebView down so the next call starts fresh instead of awaiting a
      // dead completer with no timeout.
      final headless = _headless;
      _headless = null;
      _controller = null;
      _readyCompleter = null;
      unawaited(headless?.dispose());
      rethrow;
    }
  }

  @override
  Future<String> solve() async {
    await warmup();
    final result = await _controller!.callAsyncJavaScript(
      functionBody: 'return await window.__capSolve()',
    );
    final value = result?.value;
    if (value is Map && value['token'] is String) {
      return value['token'] as String;
    }
    final errorMessage = result?.error?.toString();
    throw CapError(
      message: errorMessage ?? 'Cap solve returned no token.',
      raw: value,
    );
  }

  @override
  Future<void> reset() async {
    await _controller?.evaluateJavascript(source: 'window.__capReset()');
  }

  @override
  Future<void> dispose() async {
    _controller = null;
    // Unblock any pending warmup() awaiter instead of leaving it to the
    // loadTimeout.
    if (!(_readyCompleter?.isCompleted ?? true)) {
      _readyCompleter?.completeError(StateError('CapSolver was disposed'));
    }
    final headless = _headless;
    _headless = null;
    await headless?.dispose();
  }

  void _handleEvent(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) return;
    final event = args.first as Map;
    if (event['type'] == 'ready') {
      if (!(_readyCompleter?.isCompleted ?? true)) {
        _readyCompleter?.complete();
      }
      return;
    }
    onEvent(event['type']?.toString() ?? '', event['detail']);
  }
}
