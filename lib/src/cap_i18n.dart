/// Localization labels for the Cap widget.
///
/// Fields left `null` fall back to the English defaults matching the
/// official widget's built-in copy.
class CapI18n {
  /// Creates a set of widget labels.
  const CapI18n({
    this.initialState,
    this.verifyingLabel,
    this.solvedLabel,
    this.errorLabel,
    this.troubleshootingLabel,
    this.wasmDisabled,
    this.verifyAriaLabel,
    this.verifyingAriaLabel,
    this.verifiedAriaLabel,
    this.requiredLabel,
    this.errorAriaLabel,
  });

  /// Label shown before verification (default `Verify you're human`).
  final String? initialState;

  /// Label shown while solving (default `Verifying...`).
  final String? verifyingLabel;

  /// Label shown after a successful solve (default `You're a human`).
  final String? solvedLabel;

  /// Label shown when solving fails (default `Error. Try again.`).
  final String? errorLabel;

  /// Semantics label for the initial state (default
  /// `Click to verify you're a human`).
  final String? verifyAriaLabel;

  /// Semantics label while solving (default
  /// `Verifying you're a human, please wait`).
  final String? verifyingAriaLabel;

  /// Semantics label after a successful solve (default
  /// `We have verified you're a human, you may now continue`).
  final String? verifiedAriaLabel;

  /// Semantics label for the error state (default
  /// `An error occurred, please try again`).
  final String? errorAriaLabel;

  /// Unused — kept for API compatibility with the official widget's i18n set.
  final String? troubleshootingLabel;

  /// Unused — kept for API compatibility with the official widget's i18n set.
  final String? wasmDisabled;

  /// Unused — kept for API compatibility with the official widget's i18n set.
  final String? requiredLabel;
}
