import 'html_builder.dart' show kDefaultWidgetJsUrl;
import 'js_engine_web.dart' if (dart.library.io) 'js_engine_io.dart' as impl;

/// Callback for widget events forwarded by the engine. [type] is one of
/// `solve`, `progress`, `error`, `reset`; [detail] is the event payload.
typedef CapEngineEventCallback = void Function(String type, Object? detail);

/// Platform backend that runs the official `cap-widget` JavaScript.
///
/// On IO platforms this is a [HeadlessInAppWebView] hosting a small bridge
/// page; on the web the widget script is loaded into the page itself and
/// driven directly through `dart:js_interop` — no WebView exists there.
abstract class CapJsEngine {
  /// Creates the platform engine.
  factory CapJsEngine({
    required String apiEndpoint,
    int? workerCount,
    String widgetJsUrl = kDefaultWidgetJsUrl,
    String? wasmUrl,
    String? hashwxUrl,
    required Duration loadTimeout,
    required CapEngineEventCallback onEvent,
  }) => impl.createCapJsEngine(
    apiEndpoint: apiEndpoint,
    workerCount: workerCount,
    widgetJsUrl: widgetJsUrl,
    wasmUrl: wasmUrl,
    hashwxUrl: hashwxUrl,
    loadTimeout: loadTimeout,
    onEvent: onEvent,
  );

  /// Loads the widget script/engine so [solve] doesn't pay its latency.
  Future<void> warmup();

  /// Runs `Cap.solve()` and resolves with the verification token.
  ///
  /// Throws a [CapError] when solving fails.
  Future<String> solve();

  /// Resets the underlying widget instance.
  Future<void> reset();

  /// Releases engine resources. The engine cannot be used afterwards.
  Future<void> dispose();
}
