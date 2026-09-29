import 'pow_pool_web.dart' if (dart.library.io) 'pow_pool_io.dart' as impl;

/// Platform pool that runs SHA-256 proof-of-work tasks.
///
/// On IO platforms this is a persistent isolate pool; on the web it falls
/// back to sequential solving on the main thread.
abstract class PowPool {
  /// Creates the platform pool.
  factory PowPool() => impl.createPowPool();

  /// Worker count used when the caller doesn't specify one.
  int get defaultWorkerCount;

  /// Solves every `(salt, target)` pair and returns the nonces in order.
  ///
  /// Progress is reported through [onProgress] in `[0, 100]`.
  Future<List<int>> solveAll(
    List<(String salt, String target)> pairs, {
    int? workerCount,
    void Function(double progress)? onProgress,
  });

  /// Terminates all workers and releases pool resources. The pool respawns
  /// lazily on the next [solveAll].
  void dispose();
}
