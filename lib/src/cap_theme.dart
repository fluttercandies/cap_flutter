import 'dart:ui';

/// Visual theme for [CapWidget].
///
/// Fields left `null` fall back to defaults matching the official widget's
/// built-in look (260x58, `#fdfdfd` background, `#00a67d` checkmark).
class CapTheme {
  /// Creates a widget theme.
  const CapTheme({
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.widgetHeight,
    this.widgetWidth,
    this.widgetPadding,
    this.gap,
    this.textColor,
    this.checkboxSize,
    this.checkboxBorderColor,
    this.checkboxBorderWidth,
    this.checkboxBorderRadius,
    this.checkboxBackgroundColor,
    this.checkboxMargin,
    this.fontFamily,
    this.fontSize,
    this.spinnerColor,
    this.spinnerBackgroundColor,
    this.spinnerThickness,
    this.checkmarkColor,
    this.errorColor,
  });

  /// Container background color (official default `#fdfdfd`).
  final Color? backgroundColor;

  /// Container border color (official default `#dddddd8f`).
  final Color? borderColor;

  /// Container corner radius (official default `14`).
  final double? borderRadius;

  /// Widget height (official default `58`).
  final double? widgetHeight;

  /// Widget width (official default `260`).
  final double? widgetWidth;

  /// Horizontal padding inside the container (official default `14`).
  final double? widgetPadding;

  /// Gap between the checkbox and the label (official default `12`).
  final double? gap;

  /// Label text color (official default `#212121`).
  final Color? textColor;

  /// Checkbox edge length (official default `25`).
  final double? checkboxSize;

  /// Checkbox border color (official default `#aaaaaad1`).
  final Color? checkboxBorderColor;

  /// Checkbox border width (official default `1`).
  final double? checkboxBorderWidth;

  /// Checkbox corner radius (official default `6`).
  final double? checkboxBorderRadius;

  /// Checkbox fill color (official default `#fafafa` at ~57% opacity).
  final Color? checkboxBackgroundColor;

  /// Top margin of the checkbox (official default `2`).
  final double? checkboxMargin;

  /// Font family name for the label (`TextStyle.fontFamily`).
  final String? fontFamily;

  /// Label font size (official default `15`).
  final double? fontSize;

  /// Progress indicator color (official default `#000`).
  final Color? spinnerColor;

  /// Progress indicator track color (official default `#eee`).
  final Color? spinnerBackgroundColor;

  /// Progress indicator stroke width (official default `3`).
  final double? spinnerThickness;

  /// Checkmark color in the solved state (official default `#00a67d`).
  final Color? checkmarkColor;

  /// Error indicator color in the error state (official default `#f55b5b`).
  final Color? errorColor;
}
