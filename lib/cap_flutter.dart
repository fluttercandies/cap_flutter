/// Flutter wrapper for [Cap](https://github.com/tiagozip/cap), the
/// proof-of-work CAPTCHA alternative.
///
/// Two ways to verify a user:
///
/// * [CapWidget] — a Flutter-native checkbox widget. Solving runs through an
///   internal solver: SHA-256 challenges in pure Dart, HashWX/RSW and
///   instrumentation challenges via a hidden WebView running the official
///   `cap-widget` JavaScript.
/// * [CapSolver] — headless solver that returns a token without any UI.
///
/// Between the two, every challenge protocol the upstream widget supports
/// works here — SHA-256 natively, the rest through the official widget.
library;

export 'src/cap_controller.dart' show CapController;
export 'src/cap_error.dart';
export 'src/cap_i18n.dart';
export 'src/cap_native_solver.dart';
export 'src/cap_solver.dart';
export 'src/cap_theme.dart';
export 'src/cap_widget.dart';
export 'src/html_builder.dart' show kDefaultWidgetJsUrl;
