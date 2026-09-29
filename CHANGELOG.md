## 0.0.1

* Initial release.
* `CapWidget` — Flutter-native checkbox UI (no WebView presentation). Solving
  runs through an internal `CapSolver`: SHA-256 challenges in pure Dart,
  HashWX/RSW/instrumentation challenges in a hidden WebView running the
  official widget.
* `CapSolver` — headless solving via the widget's programmatic mode, with a
  `preferNative` option that tries `CapNativeSolver` first and falls back to
  the WebView when the challenge needs JS/WASM.
* `CapNativeSolver` — WebView-free solver for SHA-256 PoW keys with
  instrumentation disabled; works on WebViews too old for the widget.
* Readiness signaling: the solver page posts a `ready` event once the bridge
  functions are defined, and `CapSolver` waits for it — fixes
  `__capSolve is not a function` on engines where the load event precedes
  script evaluation (e.g. ArkWeb).
* The widget bundle is loaded with a classic `<script>` tag rather than
  `import()` — WKWebView rejects remote module imports in `loadData` pages.
* Web support: the widget script is loaded into the page and driven via
  `dart:js_interop` — no WebView indirection. `CapNativeSolver` also compiles
  for the web (sequential fallback, `preferNative` is skipped there).
* Windows declared (untested): `dart.library.io` selects the isolate pool and
  `HeadlessInAppWebView` paths; requires WebView2 at runtime. Apps using the
  CPF-Flutter override must also depend on the fork's
  `flutter_inappwebview_windows` subpackage.
* OpenHarmony support via the CPF-Flutter `flutter_inappwebview` fork
  (verified on OpenHarmony 6.1.1, API 24).
* `CapController` — programmatic `solve()`/`reset()`/`token` for `CapWidget`.
* `CapTheme` and `CapI18n` — styling and localization for the native UI.
* Configurable widget script/WASM asset URLs for the Standalone asset server.
