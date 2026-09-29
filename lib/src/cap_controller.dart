import 'package:flutter/foundation.dart';

import 'cap_widget.dart';

/// Operations a [CapWidget] state exposes to its [CapController].
///
/// Internal interface — implemented by the widget state, not part of the
/// public API surface.
@internal
abstract interface class CapWidgetHandle {
  /// Triggers solving programmatically and resolves with the token.
  Future<String?> solve();

  /// Resets the widget to its initial state and clears the stored token.
  Future<void> reset();

  /// The token produced by the most recent successful solve, if any.
  String? get token;
}

/// Controls a [CapWidget].
///
/// Obtain a token either from the widget's `onSolved` callback or by calling
/// [solve] programmatically.
class CapController {
  CapWidgetHandle? _handle;

  /// The token produced by the most recent successful solve, if any.
  String? get token => _handle?.token;

  /// Whether the controller is currently attached to a [CapWidget].
  bool get isAttached => _handle != null;

  /// Triggers solving programmatically and resolves with the token.
  ///
  /// Equivalent to the user clicking the checkbox. Throws [StateError] when
  /// the controller isn't attached to a widget yet.
  Future<String?> solve() {
    final handle = _handle;
    if (handle == null) {
      throw StateError('CapController is not attached to a CapWidget yet.');
    }
    return handle.solve();
  }

  /// Resets the widget to its initial state and clears the stored token.
  Future<void> reset() => _handle?.reset() ?? Future.value();

  @internal
  // ignore: use_setters_to_change_properties
  void attach(CapWidgetHandle handle) => _handle = handle;

  @internal
  void detach(CapWidgetHandle handle) {
    if (_handle == handle) _handle = null;
  }
}
