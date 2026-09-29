import 'dart:convert';

/// Latest known `cap-widget` release served from jsDelivr.
///
/// Pass an explicit [widgetJsUrl] (or your Standalone asset server's
/// `/assets/widget.js`) to pin or self-host the widget script.
const String kDefaultWidgetJsUrl =
    'https://cdn.jsdelivr.net/npm/cap-widget@0.1.58';

/// Name of the JavaScript handler that bridges widget events into Dart.
const String kCapEventHandler = 'capEvent';

/// Serializes a string as a JavaScript string literal.
String _js(String value) => jsonEncode(value);

/// Builds the headless HTML page hosting the Cap solver.
///
/// The page loads the official `cap-widget` UMD bundle (which registers
/// `window.Cap` and the `<cap-widget>` custom element) and exposes
/// `__capSolve()`/`__capReset()` that drive a hidden `Cap` instance in
/// programmatic mode.
///
/// The bridge posts `{type, detail}` objects to the `capEvent` JavaScript
/// handler for the widget's `solve`, `progress`, `error` and `reset` events.
String buildCapHtml({
  required String apiEndpoint,
  int? workerCount,
  String widgetJsUrl = kDefaultWidgetJsUrl,
  String? wasmUrl,
  String? hashwxUrl,
}) {
  // ES5-only preflight: runs even on WebViews too old to parse the modern
  // script below, and reports a webview_too_old error instead of failing
  // silently.
  final globals = StringBuffer()
    ..write('''
(function () {
  var m = /Chrome\\/(\\d+)/.exec(navigator.userAgent);
  var chromeVer = m ? parseInt(m[1], 10) : null;
  var hasWasm = typeof WebAssembly !== 'undefined';
  var isIOSWebKit = /AppleWebKit/.test(navigator.userAgent) && !m;
  var tooOld = (chromeVer !== null && chromeVer < 80) || !hasWasm;
  if (!tooOld) return;
  var report = function () {
    try {
      window.flutter_inappwebview.callHandler('$kCapEventHandler', {
        type: 'error',
        detail: {
          code: 'webview_too_old',
          message: 'System WebView is too old for the Cap widget',
          chromeVersion: chromeVer,
          hasWasm: hasWasm,
          isIOSWebKit: isIOSWebKit
        }
      });
    } catch (_) {}
  };
  var tries = 0;
  var iv = setInterval(function () {
    if (window.flutter_inappwebview || ++tries > 50) {
      report();
      clearInterval(iv);
    }
  }, 200);
})();
''');
  if (wasmUrl != null) {
    globals.write('window.CAP_CUSTOM_WASM_URL=${_js(wasmUrl)};');
  }
  if (hashwxUrl != null) {
    globals.write('window.CAP_CUSTOM_HASHWX_URL=${_js(hashwxUrl)};');
  }

  return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<script>$globals</script>
</head>
<body>
<script>
const post = (type, detail) => {
  try {
    window.flutter_inappwebview?.callHandler('$kCapEventHandler', {
      type: type,
      detail: detail ?? {}
    });
  } catch (_) {}
};
const attach = (target) => {
  ['solve', 'progress', 'error', 'reset'].forEach((ev) =>
    target.addEventListener(ev, (e) => post(ev, e.detail)));
};

(async () => {
try {
  // The widget bundle ships as UMD (window.Cap + custom element). A classic
  // script tag is used instead of import() because WKWebView rejects remote
  // module imports inside pages loaded via loadData/loadHTMLString.
  await new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = ${_js(widgetJsUrl)};
    s.onload = resolve;
    s.onerror = () => reject(new Error('widget script failed to load: ' + s.src));
    document.head.appendChild(s);
  });
  const CapCtor = window.Cap;
  if (typeof CapCtor !== 'function') {
    throw new Error('window.Cap missing after widget script load');
  }
  window.__cap = null;
  window.__capSolve = async () => {
    if (!window.__cap) {
      window.__cap = new CapCtor({
        apiEndpoint: ${_js(apiEndpoint)}${workerCount != null ? ', workers: $workerCount' : ''}
      });
      attach(window.__cap);
    }
    return await window.__cap.solve();
  };
  window.__capReset = () => {
    if (window.__cap) window.__cap.reset();
  };
  post('ready', {});
} catch (e) {
  post('error', {
    message: 'cap_init_failed: ' + ((e && e.message) || String(e))
  });
}
})();
</script>
</body>
</html>''';
}
