# cap_flutter

[English](README.md) | 中文

[Cap](https://github.com/tiagozip/cap) 的 Flutter 封装——可自托管、隐私友好
的人机校验方案，基于工作量证明（PoW）。

## 功能特性

- `CapWidget` — 复选框验证组件，提供 `onSolved` / `onProgress` /
  `onError` / `onReset` 回调
- `CapSolver` — 无界面 headless 求解，直接返回 token
- `CapNativeSolver` — SHA-256 PoW key 的纯 Dart 求解，不依赖 WebView
- `CapTheme` / `CapI18n` — 组件样式与文案定制

## 接入

需要一个运行中的 [Cap Standalone](https://trycap.dev/guide/standalone/)
实例，暴露形如 `https://<your-instance>/<site-key>/` 的端点。

**Android**（API 24+）：在 `android/app/src/main/AndroidManifest.xml` 中声明
`android.permission.INTERNET`。无需其他权限——`CapWidget` 的触觉反馈走
`HapticFeedback`，不需要 `VIBRATE`。

**iOS**：在 `ios/Podfile` 中设置 `platform :ios, '15.0'`。无需权限；端点为
纯 `http` 时（仅限开发）还需在 `Info.plist` 配置 ATS 例外。

**macOS**：开启 `com.apple.security.network.client` entitlement。

**Windows**（**未真机验证**——仅按 `flutter_inappwebview_windows` 的能力
声明支持）：需要 WebView2 运行时（多数 Windows 10/11 已预装）。若使用下
面的 CPF-Flutter override，还需显式依赖该 fork 的
`flutter_inappwebview_windows` 子包——fork 声明了 Windows 的
`default_package` 却没有依赖它，而 hosted 版本会与 fork 的
`flutter_inappwebview_platform_interface` 源冲突。SHA-256 key 的原生求
解不经过 WebView，不受影响。

**Web**：开箱即用——求解直接在页面中运行官方 widget（Web 端没有
WebView）。Cap 服务端需要允许你的源跨域访问（CORS）。

**OpenHarmony**：在 entry 模块的 `module.json5` 中声明
`ohos.permission.INTERNET`（`requestPermissions`），并在应用的
`pubspec.yaml` 中将 `flutter_inappwebview` 替换为 CPF-Flutter fork：

```yaml
dependency_overrides:
  flutter_inappwebview:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_inappwebview.git
      path: flutter_inappwebview
      ref: 6.1.5-ohos-1.0.0
```

## 用法

```dart
CapWidget(
  apiEndpoint: 'https://cap.example.com/<site-key>/',
  onSolved: (token) {
    // 把 token 发给后端，通过 /siteverify 校验
  },
  onError: (error) => debugPrint(error.message),
)
```

Headless 求解——保护后台操作、不展示 UI：

```dart
final solver = CapSolver(apiEndpoint: endpoint);
final token = await solver.solve();
await solver.dispose();
```

SHA-256 PoW key 可用 `CapNativeSolver` 全程在 Dart 中求解：

```dart
final solver = CapNativeSolver(apiEndpoint: endpoint);
final token = await solver.solve();
solver.close();
```

或让 `CapSolver` 自动选择——先尝试原生求解，遇到需要 JavaScript 的
协议（HashWX / instrumentation）时回落到隐藏 WebView：

```dart
final solver = CapSolver(apiEndpoint: endpoint, preferNative: true);
```

外观与文案通过 `CapTheme`、`CapI18n` 配置；如果 jsDelivr 不可达，将
`widgetJsUrl` 指向你的 Standalone 资源服务器（`/assets/widget.js`）。

## 校验 token

token 由你的后端调用 Cap 兼容 reCAPTCHA 的接口校验：

```http
POST https://<your-instance>/<site-key>/siteverify
Content-Type: application/json

{ "secret": "<key secret>", "response": "<token>" }
```

## License

Apache-2.0
