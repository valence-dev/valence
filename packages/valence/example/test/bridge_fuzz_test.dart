// Contracts §4.2 strict decoding, fuzzed through the dispatcher `valence codegen` generated for this app.
//
// Properties, for every input: the dispatcher never throws; the reply is one JSON object with a closed
// error code and stays under the message cap; a wrong or missing nonce reaches no handler; and a valid
// message mutated by an unknown field, a wrong-typed field or a missing required field reaches no
// handler either. The seed is fixed, so a failure reproduces.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:valence/valence.dart';
import 'package:valence_example/valence/bridge.g.dart';

/// Every handler call is recorded and refused, so a call that got through decoding is visible.
class _Recorder implements BridgeHandlers {
  final calls = <Symbol>[];
  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName);
    return Future<Never>.error(const BridgeError(BridgeErrorCode.unsupported, 'recorded'));
  }
}

const _nonce = 'fuzz-nonce';
const _codes = {
  BridgeErrorCode.unknown, BridgeErrorCode.params, BridgeErrorCode.unsupported, BridgeErrorCode.denied,
  BridgeErrorCode.cancelled, BridgeErrorCode.tooLarge, BridgeErrorCode.pending, BridgeErrorCode.offline,
  BridgeErrorCode.timeout, BridgeErrorCode.internal,
};

// Valid messages for methods whose params are all required strings, so any mutation must be refused.
const _seeds = <String, Map<String, Object?>>{
  'data.get': {'bucket': 'notes', 'key': 'k'},
  'open.external': {'url': 'https://example.com/'},
  'app.ready': {},
  'bundle.check': {},
};

Object? _junk(Random r, int depth) {
  switch (r.nextInt(depth > 2 ? 6 : 8)) {
    case 0: return null;
    case 1: return r.nextBool();
    case 2: return r.nextInt(1 << 31) - (1 << 30);
    case 3: return r.nextDouble() * 1e6;
    case 4: return String.fromCharCodes(List.generate(r.nextInt(12), (_) => r.nextInt(0x2FFF)));
    case 5: return r.nextBool() ? ' </script>' : '';
    case 6: return [for (var i = 0; i < r.nextInt(4); i++) _junk(r, depth + 1)];
    default: return {for (var i = 0; i < r.nextInt(4); i++) 'k${r.nextInt(5)}': _junk(r, depth + 1)};
  }
}

void _checkReply(String reply) {
  expect(utf8.encode(reply).length, lessThanOrEqualTo(maxMessageBytes), reason: 'reply over the cap');
  final j = jsonDecode(reply) as Map<String, Object?>;
  if (j['ok'] == true) return;
  expect(j['ok'], false);
  final code = (j['e'] as Map<String, Object?>)['code'];
  expect(_codes, contains(code), reason: 'open error code $code');
}

void main() {
  test('random messages never throw and always get a well-formed reply', () async {
    final r = Random(20261126);
    final h = _Recorder();
    final methods = [..._seeds.keys, 'data.put', 'prefs.set', 'sync.now', 'nope', '', '__proto__'];
    for (var i = 0; i < 3000; i++) {
      final String raw;
      switch (i % 4) {
        case 0: raw = String.fromCharCodes(List.generate(r.nextInt(40), (_) => r.nextInt(0x7F)));
        case 1: raw = jsonEncode(_junk(r, 0));
        default:
          raw = jsonEncode({
            'id': _junk(r, 2),
            'n': r.nextInt(3) == 0 ? _junk(r, 2) : _nonce,
            'm': r.nextInt(5) == 0 ? _junk(r, 2) : methods[r.nextInt(methods.length)],
            'p': _junk(r, 0),
          });
      }
      _checkReply(await bridgeDispatch(h, raw, nonce: _nonce));
    }
  });

  test('a wrong or missing nonce reaches no handler, whatever else the message holds', () async {
    final r = Random(7);
    final h = _Recorder();
    for (var i = 0; i < 500; i++) {
      final m = _seeds.keys.elementAt(r.nextInt(_seeds.length));
      final msg = <String, Object?>{'id': i, 'm': m, 'p': _seeds[m]};
      if (r.nextBool()) msg['n'] = _junk(r, 2);
      if (msg['n'] == _nonce) continue;
      final reply = jsonDecode(await bridgeDispatch(h, jsonEncode(msg), nonce: _nonce)) as Map<String, Object?>;
      expect((reply['e'] as Map)['code'], BridgeErrorCode.denied);
    }
    // An empty host nonce (no server) denies even a message that echoes it.
    final empty = jsonDecode(await bridgeDispatch(h, jsonEncode({'id': 1, 'n': '', 'm': 'app.ready'}), nonce: ''));
    expect((empty['e'] as Map)['code'], BridgeErrorCode.denied);
    expect(h.calls, isEmpty);
  });

  test('a mutated valid message is refused before any handler runs', () async {
    // Control: each unmutated seed does reach its handler, so "no call" below means something.
    for (final MapEntry(key: m, value: p) in _seeds.entries) {
      final h = _Recorder();
      final reply = jsonDecode(await bridgeDispatch(h, jsonEncode({'id': 0, 'n': _nonce, 'm': m, 'p': p}), nonce: _nonce));
      expect((reply['e'] as Map)['message'], 'recorded', reason: m);
      expect(h.calls, hasLength(1), reason: m);
    }
    final r = Random(11);
    for (var i = 0; i < 1000; i++) {
      final h = _Recorder();
      final m = _seeds.keys.elementAt(r.nextInt(_seeds.length));
      final p = Map<String, Object?>.of(_seeds[m]!);
      final keys = p.keys.toList();
      final kind = keys.isEmpty ? 0 : r.nextInt(3);
      if (kind == 0) {
        p['extra${r.nextInt(9)}'] = _junk(r, 1);
      } else if (kind == 1) {
        Object? v;
        do { v = _junk(r, 1); } while (v is String);
        p[keys[r.nextInt(keys.length)]] = v;
      } else {
        p.remove(keys[r.nextInt(keys.length)]);
      }
      final reply = jsonDecode(await bridgeDispatch(h, jsonEncode({'id': i, 'n': _nonce, 'm': m, 'p': p}), nonce: _nonce));
      expect((reply['e'] as Map)['code'], BridgeErrorCode.params, reason: '$m $p');
      expect(h.calls, isEmpty, reason: '$m $p reached a handler');
    }
  });

  test('an oversized id or params still produce a reply under the cap', () async {
    final h = _Recorder();
    final big = 'x' * (maxMessageBytes + 10);
    for (final msg in [
      {'id': big, 'n': 'wrong', 'm': 'app.ready'},
      {'id': big, 'n': _nonce, 'm': 'nope'},
      {'id': 1, 'n': _nonce, 'm': 'data.get', 'p': {'bucket': big, 'key': 'k', 'x': 1}},
    ]) {
      _checkReply(await bridgeDispatch(h, jsonEncode(msg), nonce: _nonce));
    }
    expect(h.calls, isEmpty);
  });
}
