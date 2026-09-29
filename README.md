# cap_flutter

English | [中文](README-zh.md)

Flutter wrapper for [Cap](https://github.com/tiagozip/cap) — a self-hosted,
privacy-friendly CAPTCHA alternative based on proof-of-work.

## Features

- `CapWidget` — checkbox verification widget with `onSolved` / `onProgress` /
  `onError` / `onReset` callbacks
- `CapSolver` — headless solver that returns a token without showing UI
- `CapNativeSolver` — pure-Dart solver for SHA-256 PoW keys, no WebView needed
- `CapTheme` / `CapI18n` — widget styling and localization

## Setup

You need a running [Cap Standalone](https://trycap.dev/guide/standalone/)
instance exposing an endpoint like `https://<your-instance>/<site-key>/`.

**Android** (API 24+): declare `android.permission.INTERNET` in
`android/app/src/main/AndroidManifest.xml`. No other permissions are needed —
`CapWidget`'s haptic feedback uses `HapticFeedback`, not `VIBRATE`.

**iOS**: set `platform :ios, '15.0'` in `ios/Podfile`. No permissions needed;
a plain-`http` endpoint (dev only) additionally requires an ATS exception in
`Info.plist`.

**macOS**: enable the `com.apple.security.network.client` entitlement.

**Windows** *(untested — declared but not verified on real hardware)*:
requires the WebView2 runtime (preinstalled on most Windows 10/11 systems).
If you override `flutter_inappwebview` with the CPF-Flutter fork below, you
must also depend on the fork's `flutter_inappwebview_windows` subpackage —
the fork declares the Windows `default_package` but doesn't depend on it,
and the hosted release conflicts over `flutter_inappwebview_platform_interface`'s
source. SHA-256 keys solve without the WebView entirely.

**Web**: works out of the box — solving runs the official widget directly in
the page (no WebView exists there). The Cap server must allow CORS from your
origin.

**OpenHarmony**: declare `ohos.permission.INTERNET` in the entry module's
`module.json5` (`requestPermissions`), and override `flutter_inappwebview`
with the CPF-Flutter fork in the app's `pubspec.yaml`:

```yaml
dependency_overrides:
  flutter_inappwebview:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_inappwebview.git
      path: flutter_inappwebview
      ref: 6.1.5-ohos-1.0.0
```

## Usage

```dart
CapWidget(
  apiEndpoint: 'https://cap.example.com/<site-key>/',
  onSolved: (token) {
    // send `token` to your backend, verify via /siteverify
  },
  onError: (error) => debugPrint(error.message),
)
```

Headless solving, for protecting background actions without UI:

```dart
final solver = CapSolver(apiEndpoint: endpoint);
final token = await solver.solve();
await solver.dispose();
```

For SHA-256 PoW keys, `CapNativeSolver` solves entirely in Dart:

```dart
final solver = CapNativeSolver(apiEndpoint: endpoint);
final token = await solver.solve();
solver.close();
```

Or let `CapSolver` pick automatically — native first, hidden-WebView fallback
for protocols that need JavaScript (HashWX / instrumentation):

```dart
final solver = CapSolver(apiEndpoint: endpoint, preferNative: true);
```

Appearance and copy are configured with `CapTheme` and `CapI18n`; if jsDelivr
is unreachable, point `widgetJsUrl` at your Standalone asset server
(`/assets/widget.js`).

## Verifying the token

The token is verified by your backend against Cap's reCAPTCHA-compatible
endpoint:

```http
POST https://<your-instance>/<site-key>/siteverify
Content-Type: application/json

{ "secret": "<key secret>", "response": "<token>" }
```

## License

Apache-2.0
