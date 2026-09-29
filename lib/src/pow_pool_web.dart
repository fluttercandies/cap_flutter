import 'pow_core.dart';
import 'pow_pool.dart';

PowPool createPowPool() => _WebPowPool();

/// Web fallback: `dart:isolate` doesn't exist in the browser, so tasks run
/// sequentially on the main thread. Correct but slow — a full challenge set
/// can block the UI for seconds, which is why `preferNative` is skipped on
/// the web. Direct `CapNativeSolver` use still works for callers that accept
/// the jank.
class _WebPowPool implements PowPool {
  var _busy = false;

  @override
  int get defaultWorkerCount => 1;

  @override
  Future<List<int>> solveAll(
    List<(String, String)> pairs, {
    int? workerCount,
    void Function(double progress)? onProgress,
  }) async {
    if (_busy) {
      throw StateError('A solve is already in progress.');
    }
    _busy = true;
    try {
      final solved = List<int>.filled(pairs.length, 0);
      for (var i = 0; i < pairs.length; i++) {
        // Let pending microtasks/events breathe between challenges — a single
        // challenge still runs to completion without yielding.
        await Future(() {});
        solved[i] = solvePowChallenge(pairs[i].$1, pairs[i].$2);
        onProgress?.call((i + 1) / pairs.length * 100);
      }
      onProgress?.call(100);
      return solved;
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {}
}
