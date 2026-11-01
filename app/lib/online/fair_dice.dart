import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:narda_core/narda_core.dart';

/// Честные кости без сервера: commit–reveal на цепочках хешей.
///
/// В начале партии каждый публикует вершину своей цепочки `x0 = H^N(seed)`.
/// Для броска номер `i` оба раскрывают `x_i` (`H^i(x_i) == x0`), а кости —
/// хеш обоих раскрытий. Свои значения заданы заранее, чужие будущие не
/// угадать, поэтому подкрутить бросок не может ни один из игроков.
class FairChain {
  FairChain(String seed, {this.length = fairChainLength})
    : _links = _build(seed, length);

  final int length;

  /// `_links[i]` — раскрытие для броска `i`; `_links[0]` — обязательство.
  final List<String> _links;

  String get commit => _links[0];

  String reveal(int slot) => _links[slot];

  static List<String> _build(String seed, int length) {
    final List<String> tail = <String>[_hash(seed)];
    for (int i = 0; i < length; i++) {
      tail.add(_hash(tail.last));
    }
    return tail.reversed.toList();
  }
}

/// Бросков на одну партию: розыгрыш первого хода плюс сами ходы.
const int fairChainLength = 1100;

/// Раскрытие [value] для броска [slot] сходится с уже проверенным звеном
/// [anchor] номер [anchorSlot] (по умолчанию — с обязательством).
bool verifyReveal(String anchor, int slot, String value, {int anchorSlot = 0}) {
  if (slot <= anchorSlot || slot > fairChainLength) return false;
  String current = value;
  for (int i = anchorSlot; i < slot; i++) {
    current = _hash(current);
  }
  return current == anchor;
}

/// Кости броска [slot] из раскрытий белых и чёрных.
DiceRoll fairRoll(String white, String black, int slot) {
  String digest = _hash('$white|$black|$slot');
  final List<int> faces = <int>[];
  while (faces.length < 2) {
    for (final int byte in _bytes(digest)) {
      // 252 = 42 * 6: без перекоса в сторону малых граней.
      if (byte < 252 && faces.length < 2) faces.add(byte % 6 + 1);
    }
    digest = _hash(digest);
  }
  return DiceRoll(faces[0], faces[1]);
}

/// Случайный секрет устройства: из него и комнаты растёт цепочка партии.
String newFairSecret([Random? random]) {
  final Random source = random ?? Random.secure();
  return List<String>.generate(
    32,
    (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

List<int> _bytes(String hex) => <int>[
  for (int i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];
