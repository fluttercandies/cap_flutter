import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cap_controller.dart';
import 'cap_error.dart';
import 'cap_i18n.dart';
import 'cap_solver.dart';
import 'cap_theme.dart';
import 'html_builder.dart' show kDefaultWidgetJsUrl;

/// Visual state of a [CapWidget].
enum _CapStatus {
  /// Waiting for the user to click the checkbox.
  idle,

  /// A challenge is being solved.
  verifying,

  /// The challenge was solved; [CapController.token] holds the token.
  solved,

  /// Solving failed; tap again to retry.
  error,
}

/// A Flutter-native Cap checkbox widget.
///
/// Renders the checkbox UI with Flutter widgets — no WebView is used for
/// presentation. On tap it solves the challenge through an internal
/// [CapSolver]: SHA-256 challenges run in pure Dart, while HashWX/RSW and
/// instrumentation challenges automatically fall back to a hidden WebView
/// running the official widget.
///
/// ```dart
/// CapWidget(
///   apiEndpoint: 'https://cap.example.com/<site-key>/',
///   onSolved: (token) => submit(token),
/// )
/// ```
class CapWidget extends StatefulWidget {
  /// Creates a Cap widget.
  const CapWidget({
    super.key,
    required this.apiEndpoint,
    this.controller,
    this.i18n = const CapI18n(),
    this.theme = const CapTheme(),
    this.workerCount,
    this.disableHaptics = false,
    this.preferNative = true,
    this.nativeUserAgent,
    this.widgetJsUrl = kDefaultWidgetJsUrl,
    this.wasmUrl,
    this.hashwxUrl,
    this.onSolved,
    this.onProgress,
    this.onError,
    this.onReset,
  });

  /// The Cap API endpoint including the site key, e.g.
  /// `https://<your-instance>/<site-key>/`. A trailing slash is added if
  /// missing.
  final String apiEndpoint;

  /// Optional controller for [CapController.solve] and [CapController.reset].
  final CapController? controller;

  /// Localization labels. `null` fields fall back to the English defaults
  /// matching the official widget.
  final CapI18n i18n;

  /// Visual theme.
  final CapTheme theme;

  /// Number of solver worker threads/isolates. Defaults to the device's
  /// reported core count.
  final int? workerCount;

  /// Disables haptic feedback (vibration) on mobile devices.
  final bool disableHaptics;

  /// Try solving natively in Dart first, without a WebView.
  ///
  /// Works when the site key uses the SHA-256 PoW protocol and has
  /// instrumentation challenges disabled. Other protocols automatically fall
  /// back to a hidden WebView running the official widget.
  final bool preferNative;

  /// `User-Agent` for the native solver's HTTP requests.
  final String? nativeUserAgent;

  /// URL of the `cap-widget` script used by the hidden-WebView fallback.
  /// Defaults to jsDelivr; point this at your Standalone asset server
  /// (`/assets/widget.js`) to self-host.
  final String widgetJsUrl;

  /// Custom `cap_wasm` URL (`window.CAP_CUSTOM_WASM_URL`), e.g. your
  /// Standalone asset server's `/assets/cap_wasm_bg.wasm`.
  final String? wasmUrl;

  /// Custom HashWX WASM URL (`window.CAP_CUSTOM_HASHWX_URL`), e.g. your
  /// Standalone asset server's `/assets/hashwx.wasm`.
  final String? hashwxUrl;

  /// Called when the challenge is solved, with the verification token.
  final void Function(String token)? onSolved;

  /// Called with solve progress in `[0, 100]`.
  final void Function(double progress)? onProgress;

  /// Called when solving fails.
  final void Function(CapError error)? onError;

  /// Called when the widget resets to its initial state.
  final VoidCallback? onReset;

  @override
  State<CapWidget> createState() => _CapWidgetState();
}

class _CapWidgetState extends State<CapWidget> implements CapWidgetHandle {
  _CapStatus _status = _CapStatus.idle;
  String? _token;
  double _progress = 0;
  CapSolver? _solver;
  Future<String?>? _solveFuture;
  int _epoch = 0;

  /// The token produced by the most recent successful solve, if any.
  @override
  String? get token => _token;

  CapSolver get _solverInstance => _solver ??= CapSolver(
    apiEndpoint: widget.apiEndpoint,
    workerCount: widget.workerCount,
    widgetJsUrl: widget.widgetJsUrl,
    wasmUrl: widget.wasmUrl,
    hashwxUrl: widget.hashwxUrl,
    preferNative: widget.preferNative,
    nativeUserAgent: widget.nativeUserAgent,
    onProgress: (p) {
      // Late progress from a superseded solve (post-reset/config-change)
      // must not overwrite state or reach the user's callback.
      if (_status != _CapStatus.verifying) return;
      _progress = p / 100;
      if (mounted) setState(() {});
      widget.onProgress?.call(p);
    },
  );

  /// Solves the challenge programmatically. Equivalent to the user clicking
  /// the checkbox. Returns the token, `null` when the solve was superseded by
  /// a reset or config change, and throws on failure.
  @override
  Future<String?> solve() => _solve();

  /// Resets the widget to its initial state and clears the stored token.
  /// An in-flight solve keeps running but its result is discarded.
  @override
  Future<void> reset() async {
    _epoch++;
    final hadState = _status != _CapStatus.idle || _token != null;
    await _solver?.reset();
    _token = null;
    _progress = 0;
    if (_status != _CapStatus.idle && mounted) {
      setState(() => _status = _CapStatus.idle);
    }
    if (hadState) widget.onReset?.call();
  }

  void _solveFromTap() {
    // Failures already surface through the error state and onError.
    _solve().catchError((_) => null);
  }

  Future<String?> _solve() async {
    final inFlight = _solveFuture;
    if (inFlight != null) {
      if (_status == _CapStatus.verifying) return inFlight;
      // A superseded solve is still settling — wait for it so the solver's
      // in-flight guard doesn't reject the new attempt.
      try {
        await inFlight;
      } catch (_) {}
      return _solve();
    }
    final future = _runSolve();
    _solveFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_solveFuture, future)) _solveFuture = null;
    }
  }

  Future<String?> _runSolve() async {
    final epoch = ++_epoch;
    setState(() {
      _status = _CapStatus.verifying;
      _progress = 0;
    });
    try {
      final token = await _solverInstance.solve();
      if (!mounted || epoch != _epoch) return null;
      _token = token;
      setState(() => _status = _CapStatus.solved);
      if (!widget.disableHaptics) {
        unawaited(HapticFeedback.mediumImpact());
      }
      widget.onSolved?.call(token);
      return token;
    } on CapError catch (e) {
      if (!mounted || epoch != _epoch) return null;
      setState(() => _status = _CapStatus.error);
      widget.onError?.call(e);
      rethrow;
    } catch (e) {
      if (!mounted || epoch != _epoch) return null;
      final error = CapError(message: e.toString());
      setState(() => _status = _CapStatus.error);
      widget.onError?.call(error);
      throw error;
    }
  }

  String get _label => switch (_status) {
    _CapStatus.idle => widget.i18n.initialState ?? "Verify you're human",
    _CapStatus.verifying => widget.i18n.verifyingLabel ?? 'Verifying...',
    _CapStatus.solved => widget.i18n.solvedLabel ?? "You're a human",
    _CapStatus.error => widget.i18n.errorLabel ?? 'Error. Try again.',
  };

  String get _semanticsLabel => switch (_status) {
    _CapStatus.idle =>
      widget.i18n.verifyAriaLabel ?? "Click to verify you're a human",
    _CapStatus.verifying =>
      widget.i18n.verifyingAriaLabel ?? "Verifying you're a human, please wait",
    _CapStatus.solved =>
      widget.i18n.verifiedAriaLabel ??
          "We have verified you're a human, you may now continue",
    _CapStatus.error =>
      widget.i18n.errorAriaLabel ?? 'An error occurred, please try again',
  };

  Widget _buildIndicator() {
    final theme = widget.theme;
    final size = theme.checkboxSize ?? 25;
    final iconSize = size * 0.8;
    return switch (_status) {
      _CapStatus.verifying => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: _progress > 0 ? _progress : null,
          strokeWidth: theme.spinnerThickness ?? 3,
          color: theme.spinnerColor ?? Colors.black,
          backgroundColor:
              theme.spinnerBackgroundColor ?? const Color(0xFFEEEEEE),
        ),
      ),
      _CapStatus.solved => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.check,
          color: theme.checkmarkColor ?? const Color(0xFF00A67D),
          size: iconSize,
        ),
      ),
      _CapStatus.error => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.close,
          color: theme.errorColor ?? const Color(0xFFF55B5B),
          size: iconSize,
        ),
      ),
      _CapStatus.idle => Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(top: theme.checkboxMargin ?? 2),
        decoration: BoxDecoration(
          color: theme.checkboxBackgroundColor ?? const Color(0x91FAFAFA),
          border: Border.all(
            color: theme.checkboxBorderColor ?? const Color(0xD1AAAAAA),
            width: theme.checkboxBorderWidth ?? 1,
          ),
          borderRadius: BorderRadius.circular(theme.checkboxBorderRadius ?? 6),
        ),
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(CapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.apiEndpoint != widget.apiEndpoint ||
        oldWidget.workerCount != widget.workerCount ||
        oldWidget.widgetJsUrl != widget.widgetJsUrl ||
        oldWidget.wasmUrl != widget.wasmUrl ||
        oldWidget.hashwxUrl != widget.hashwxUrl ||
        oldWidget.preferNative != widget.preferNative ||
        oldWidget.nativeUserAgent != widget.nativeUserAgent) {
      // Solver settings changed — invalidate an in-flight solve's result,
      // drop the old solver so the next solve rebuilds one with the new
      // configuration, and bring a spinning widget back to idle.
      _epoch++;
      unawaited(_solver?.dispose());
      _solver = null;
      _token = null;
      if (_status == _CapStatus.verifying) {
        setState(() => _status = _CapStatus.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tappable = _status == _CapStatus.idle || _status == _CapStatus.error;
    return Semantics(
      button: true,
      enabled: tappable,
      label: _semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? _solveFromTap : null,
        child: Container(
          width: theme.widgetWidth ?? 260,
          height: theme.widgetHeight ?? 58,
          padding: EdgeInsets.symmetric(horizontal: theme.widgetPadding ?? 14),
          decoration: BoxDecoration(
            color: theme.backgroundColor ?? const Color(0xFFFDFDFD),
            border: Border.all(
              color: theme.borderColor ?? const Color(0x8FDDDDDD),
            ),
            borderRadius: BorderRadius.circular(theme.borderRadius ?? 14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIndicator(),
              SizedBox(width: theme.gap ?? 12),
              Flexible(
                child: Text(
                  _label,
                  style: TextStyle(
                    color: theme.textColor ?? const Color(0xFF212121),
                    fontFamily: theme.fontFamily,
                    fontSize: theme.fontSize ?? 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _epoch++;
    widget.controller?.detach(this);
    unawaited(_solver?.dispose());
    super.dispose();
  }
}
