/// An error reported by the Cap widget's `error` event.
class CapError implements Exception {
  /// Creates a [CapError].
  const CapError({required this.message, this.code, this.raw});

  /// Human-readable error message from the widget.
  final String message;

  /// Machine-readable error code, if the widget provided one
  /// (e.g. `network_error`, `redeem_failed`, `wasm_load_failed`).
  final String? code;

  /// The raw `event.detail` payload.
  final Object? raw;

  /// Parses a `capEvent` detail payload into a [CapError].
  factory CapError.fromEventDetail(Object? detail) {
    if (detail is Map) {
      return CapError(
        message: detail['message']?.toString() ?? 'Unknown Cap error',
        code: detail['code']?.toString(),
        raw: detail,
      );
    }
    return CapError(message: detail?.toString() ?? 'Unknown Cap error');
  }

  @override
  String toString() =>
      'CapError(${code != null ? '$code, ' : ''}message: $message)';
}
