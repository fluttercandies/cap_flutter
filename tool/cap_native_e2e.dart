import 'dart:io';
import 'package:cap_flutter/src/cap_native_solver.dart';

/// Manual end-to-end check for the native solver against a real Standalone
/// instance:
///
/// ```sh
/// CAP_API_ENDPOINT='https://<instance>/<sha256-site-key>/' \
///   dart run tool/cap_native_e2e.dart
/// ```
void main() async {
  final endpoint = Platform.environment['CAP_API_ENDPOINT'];
  if (endpoint == null || endpoint.isEmpty) {
    stderr.writeln('Set CAP_API_ENDPOINT first (see file header).');
    exitCode = 64;
    return;
  }
  final sw = Stopwatch()..start();
  final solver = CapNativeSolver(
    apiEndpoint: endpoint,
    onProgress: (p) => stdout.write('\rprogress ${p.toStringAsFixed(0)}%'),
  );
  final token = await solver.solve();
  solver.close();
  stdout.writeln('\nsolved in ${sw.elapsedMilliseconds}ms');
  stdout.writeln('token: $token');
}
