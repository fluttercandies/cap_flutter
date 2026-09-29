import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'cap_error.dart';
import 'js_engine.dart';

CapJsEngine createCapJsEngine({
  required String apiEndpoint,
  int? workerCount,
  required String widgetJsUrl,
  String? wasmUrl,
  String? hashwxUrl,
  required Duration loadTimeout,
  required CapEngineEventCallback onEvent,
}) => _WebCapJsEngine(
  apiEndpoint: apiEndpoint,
  workerCount: workerCount,
  widgetJsUrl: widgetJsUrl,
  wasmUrl: wasmUrl,
  hashwxUrl: hashwxUrl,
  loadTimeout: loadTimeout,
  onEvent: onEvent,
);

/// `window.Cap` — the UMD bundle's constructor.
@JS('Cap')
extension type _Cap._(JSObject _) implements JSObject {
  external _Cap(JSObject options);
  external JSPromise<JSObject> solve();
  external void reset();
  external void addEventListener(String type, JSFunction listener);
}

@JS('Cap')
external JSObject? get _capGlobal;

/// Web engine: loads the official widget bundle into the page itself and
/// drives a `Cap` instance directly — the browser already is the JS runtime,
/// so no WebView indirection is needed.
class _WebCapJsEngine implements CapJsEngine {
  _WebCapJsEngine({
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

  _Cap? _cap;
  Future<void>? _scriptLoad;

  @override
  Future<void> warmup() async {
    if (_capGlobal == null) {
      // Custom WASM/asset URLs must be set before the bundle evaluates.
      if (wasmUrl != null) {
        web.window.setProperty('CAP_CUSTOM_WASM_URL'.toJS, wasmUrl!.toJS);
      }
      if (hashwxUrl != null) {
        web.window.setProperty('CAP_CUSTOM_HASHWX_URL'.toJS, hashwxUrl!.toJS);
      }
      _scriptLoad ??= _injectScript();
      await _scriptLoad!.timeout(loadTimeout);
      if (_capGlobal == null) {
        throw const CapError(
          message: 'window.Cap missing after widget script load',
        );
      }
    }
  }

  @override
  Future<String> solve() async {
    await warmup();
    _cap ??= _createInstance();
    final Object? result;
    try {
      result = (await _cap!.solve().toDart).dartify();
    } catch (e) {
      // The 'error' event carries the structured payload; the promise
      // rejection is surfaced as a plain CapError.
      throw CapError(message: 'Cap solve failed: $e');
    }
    if (result is Map && result['token'] is String) {
      return result['token'] as String;
    }
    throw CapError(message: 'Cap solve returned no token.', raw: result);
  }

  @override
  Future<void> reset() async {
    _cap?.reset();
  }

  @override
  Future<void> dispose() async {
    _cap = null;
  }

  _Cap _createInstance() {
    final options =
        {
              'apiEndpoint': apiEndpoint,
              if (workerCount != null) 'workers': workerCount,
            }.jsify()
            as JSObject;
    final cap = _Cap(options);
    for (final type in const ['solve', 'progress', 'error', 'reset']) {
      cap.addEventListener(
        type,
        ((web.Event e) {
          onEvent(type, (e as web.CustomEvent).detail.dartify());
        }).toJS,
      );
    }
    return cap;
  }

  Future<void> _injectScript() {
    final completer = Completer<void>();
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..src = widgetJsUrl
      ..async = true;
    script.addEventListener(
      'load',
      ((web.Event _) => completer.complete()).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) => completer.completeError(
        CapError(
          message: 'widget script failed to load: $widgetJsUrl',
          code: 'widget_script_failed',
        ),
      )).toJS,
    );
    web.document.head!.appendChild(script);
    return completer.future;
  }
}
