/// Port of cap-core's `prng.js` — the seeded challenge expansion shared by the
/// official widget, the M2M solver, and the server's verification.
///
/// All arithmetic reproduces JavaScript's 32-bit semantics: `<<` truncates to
/// int32, `^=` converts operands to int32, and `>>>`/`>>> 0` mean "unsigned".
library;

const int _fnvOffset = 2166136261;
const int _mask32 = 0xFFFFFFFF;

/// FNV-1a hash of [str] continued from [state].
int fnv1a(String str, [int state = _fnvOffset]) {
  var h = state;
  for (var i = 0; i < str.length; i++) {
    h ^= str.codeUnitAt(i);
    h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) & _mask32;
  }
  return h;
}

/// xorshift32 producing a lowercase hex string of exactly [length] chars.
String prngFromHash(int state, int length) {
  var s = state & _mask32;
  final out = StringBuffer();
  while (out.length < length) {
    s ^= (s << 13) & _mask32;
    s ^= s >> 17;
    s ^= (s << 5) & _mask32;
    s &= _mask32;
    out.write(s.toRadixString(16).padLeft(8, '0'));
  }
  return out.toString().substring(0, length);
}

/// Expands a seeded challenge token into `c` `[salt, target]` pairs, matching
/// the server-side derivation in `validateChallenge`:
///
/// ```js
/// saltSeed   = fnv1aResume(fnv1a(token), String(i + 1))
/// targetSeed = fnv1aResume(saltSeed, "d")
/// ```
List<(String, String)> expandSeededChallenges(
  String token, {
  required int count,
  required int size,
  required int difficulty,
}) {
  final tokenHash = fnv1a(token);
  return List.generate(count, (i) {
    final saltSeed = fnv1a('${i + 1}', tokenHash);
    final targetSeed = fnv1a('d', saltSeed);
    return (prngFromHash(saltSeed, size), prngFromHash(targetSeed, difficulty));
  });
}
