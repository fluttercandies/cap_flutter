import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'cap_error.dart';
import 'pow_core.dart';
import 'pow_pool.dart';

PowPool createPowPool() => _IoPowPool();

/// IO implementation: a persistent isolate pool with dynamic task dispatch.
class _IoPowPool implements PowPool {
  final List<Isolate> _workers = [];
  List<SendPort?> _taskPorts = [];
  ReceivePort? _resultPort;
  void Function(int workerId, int index, int nonce)? _onResult;
  void Function(Object error)? _onWorkerLost;
  var _poolSize = 0;
  var _solving = false;

  @override
  int get defaultWorkerCount => Platform.numberOfProcessors;

  Future<void> _ensurePool(int workers) async {
    if (_poolSize == workers) return;
    dispose();
    _poolSize = workers;
    final ready = Completer<void>();
    // Indexed by workerId — handshake arrival order isn't guaranteed to
    // match spawn order, so a length-based append would misroute dispatches.
    _taskPorts = List.filled(workers, null);
    _resultPort = ReceivePort();
    _resultPort!.listen((msg) {
      // Handshake: (workerId, taskSendPort). Result: (workerId, index, nonce).
      // onError payload: List [error, stackTrace]. onExit payload: null.
      if (msg is (int, SendPort)) {
        _taskPorts[msg.$1] = msg.$2;
        var allReady = true;
        for (final port in _taskPorts) {
          allReady &= port != null;
        }
        if (allReady && !ready.isCompleted) ready.complete();
      } else if (msg is (int, int, int)) {
        _onResult?.call(msg.$1, msg.$2, msg.$3);
      } else if (msg == null || msg is List) {
        _onWorkerLost?.call(StateError('$msg'));
      }
    });
    try {
      _workers.addAll(
        await Future.wait([
          for (var i = 0; i < workers; i++)
            Isolate.spawn(
              _workerMain,
              (i, _resultPort!.sendPort),
              onExit: _resultPort!.sendPort,
              onError: _resultPort!.sendPort,
            ),
        ]),
      );
    } catch (_) {
      dispose();
      rethrow;
    }
    await ready.future;
  }

  @override
  Future<List<int>> solveAll(
    List<(String, String)> pairs, {
    int? workerCount,
    void Function(double progress)? onProgress,
  }) async {
    if (_solving) {
      throw StateError('A solve is already in progress.');
    }
    _solving = true;
    try {
      final workers = math.max(
        1,
        math.min(workerCount ?? defaultWorkerCount, pairs.length),
      );
      await _ensurePool(workers);

      final solved = List<int>.filled(pairs.length, 0);
      var nextTask = 0;
      var completed = 0;
      final done = Completer<void>();

      void dispatch(SendPort? port) {
        if (port == null || nextTask >= pairs.length) return;
        final i = nextTask++;
        port.send((i, pairs[i].$1, pairs[i].$2));
      }

      _onResult = (workerId, index, nonce) {
        solved[index] = nonce;
        completed++;
        onProgress?.call(completed / pairs.length * 100);
        if (completed == pairs.length) {
          done.complete();
        } else {
          dispatch(_taskPorts[workerId]);
        }
      };
      // A worker exiting or erroring mid-solve must not leave `done` pending
      // forever — fail the whole solve instead.
      _onWorkerLost = (error) {
        if (!done.isCompleted) {
          done.completeError(
            CapError(
              message: 'A solver worker exited unexpectedly: $error',
              code: 'worker_error',
            ),
          );
        }
      };

      for (final port in _taskPorts) {
        dispatch(port);
      }
      await done.future;
      onProgress?.call(100);
      return solved;
    } finally {
      _onResult = null;
      _onWorkerLost = null;
      _solving = false;
    }
  }

  @override
  void dispose() {
    // Unblock an in-flight solveAll synchronously — kill() exit notifications
    // may be dropped once the result port is closed below.
    _onWorkerLost?.call(StateError('worker pool disposed'));
    for (final isolate in _workers) {
      isolate.kill();
    }
    _workers.clear();
    _taskPorts = [];
    _resultPort?.close();
    _resultPort = null;
    _onResult = null;
    _onWorkerLost = null;
    _poolSize = 0;
  }
}

/// Entry point of a persistent worker isolate. Receives
/// `(index, salt, target)` tasks on its task port and reports
/// `(workerId, index, nonce)` results back.
@pragma('vm:entry-point')
void _workerMain((int, SendPort) args) {
  final (workerId, resultPort) = args;
  final taskPort = ReceivePort();
  resultPort.send((workerId, taskPort.sendPort));
  taskPort.listen((task) {
    final (index, salt, target) = task as (int, String, String);
    resultPort.send((workerId, index, solvePowChallenge(salt, target)));
  });
}
