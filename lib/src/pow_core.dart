import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Finds a nonce where `sha256(salt + decimal(nonce))` has [target] as its
/// hex prefix — mirrors `solve_pow` in `@cap.js/wasm`.
///
/// Pure Dart — compiles on every platform including the web (where it runs
/// on the main thread and blocks the UI while it works).
int solvePowChallenge(String salt, String target) {
  final saltBytes = ascii.encode(salt);
  final msg = Uint8List(saltBytes.length + 20)
    ..setRange(0, saltBytes.length, saltBytes);
  final expected = List.generate(
    target.length,
    (i) => int.parse(target[i], radix: 16),
  );

  // 2^53-1 — the largest nonce bound that compiles to JS (web ints are
  // IEEE-754 doubles). Practically unbounded for PoW purposes.
  for (var nonce = 0; nonce < 0x1FFFFFFFFFFFFF; nonce++) {
    final len = writeDecimalNonce(nonce, msg, saltBytes.length);
    // sublistView shares the buffer — avoids a per-iteration copy+alloc.
    final digest = sha256.convert(
      Uint8List.sublistView(msg, 0, saltBytes.length + len),
    );
    if (digestMatches(digest.bytes, expected)) return nonce;
  }
  throw StateError('unreachable');
}

int writeDecimalNonce(int value, Uint8List out, int offset) {
  var digits = 0;
  var v = value;
  do {
    digits++;
    v ~/= 10;
  } while (v > 0);
  v = value;
  for (var i = digits - 1; i >= 0; i--) {
    out[offset + i] = 0x30 + v % 10;
    v ~/= 10;
  }
  return digits;
}

bool digestMatches(List<int> digest, List<int> expectedNibbles) {
  for (var i = 0; i < expectedNibbles.length; i++) {
    final nibble = (digest[i >> 1] >> ((i & 1) == 0 ? 4 : 0)) & 0xF;
    if (nibble != expectedNibbles[i]) return false;
  }
  return true;
}
