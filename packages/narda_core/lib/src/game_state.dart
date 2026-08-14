import 'coords.dart';
import 'dice.dart';
import 'move.dart';
import 'player.dart';
import 'util/list_equality.dart';

/// Иммутабельное состояние партии. Любое изменение возвращает новый объект.
class GameState {
  GameState({
    required List<int> points,
    required this.turn,
    required this.roll,
    required List<int> remainingDice,
    this.whiteBorneOff = 0,
    this.blackBorneOff = 0,
    this.turnIndex = 0,
    this.headMovesUsed = 0,
  }) : assert(points.length == Coords.pointCount, 'points must have 24 entries'),
       points = List<int>.unmodifiable(points),
       remainingDice = List<int>.unmodifiable(remainingDice);

  /// Стартовая расстановка: 15 белых на абс. 24, 15 чёрных на абс. 12.
  factory GameState.initial({required Player first, required DiceRoll roll}) {
    final points = List<int>.filled(Coords.pointCount, 0);
    points[Coords.absIndex(Coords.headAbs(Player.white))] = checkersPerPlayer;
    points[Coords.absIndex(Coords.headAbs(Player.black))] = -checkersPerPlayer;
    return GameState(
      points: points,
      turn: first,
      roll: roll,
      remainingDice: roll.toRemaining(),
    );
  }

  /// Шашек у каждого игрока.
  static const int checkersPerPlayer = 15;

  /// Занятость пунктов: индекс = абсолютный пункт − 1,
  /// положительное значение — число белых шашек, отрицательное — чёрных.
  final List<int> points;

  final int whiteBorneOff;
  final int blackBorneOff;

  /// Чей сейчас ход.
  final Player turn;

  /// Текущий бросок (нужен для правил дубля и головы).
  final DiceRoll roll;

  /// Ещё не сыгранные числа текущего броска.
  final List<int> remainingDice;

  /// Сколько полных ходов уже завершено в партии.
  /// Первый ход каждого игрока — это `turnIndex` 0 и 1.
  final int turnIndex;

  /// Сколько шашек снято с головы в текущем (незавершённом) ходе.
  final int headMovesUsed;

  /// Является ли текущий ход первым ходом партии для игрока [turn].
  bool get isFirstTurnOfMover => turnIndex < 2;

  /// Знаковое количество шашек на абсолютном пункте [abs].
  int countAt(int abs) => points[Coords.absIndex(abs)];

  /// Сколько шашек игрока [player] стоит на абсолютном пункте [abs].
  int checkersAt(Player player, int abs) {
    final value = points[Coords.absIndex(abs)];
    if (player == Player.white) return value > 0 ? value : 0;
    return value < 0 ? -value : 0;
  }

  bool isOccupiedBy(Player player, int abs) => checkersAt(player, abs) > 0;

  /// Шашек игрока на доске (без выброшенных).
  int onBoard(Player player) {
    var total = 0;
    for (final value in points) {
      if (player == Player.white) {
        if (value > 0) total += value;
      } else {
        if (value < 0) total -= value;
      }
    }
    return total;
  }

  int borneOff(Player player) =>
      player == Player.white ? whiteBorneOff : blackBorneOff;

  /// Шашек на голове игрока.
  int checkersOnHead(Player player) =>
      checkersAt(player, Coords.headAbs(player));

  /// Сумма расстояний до выброса по всем шашкам игрока.
  int pipCount(Player player) {
    var pips = 0;
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      final count = checkersAt(player, abs);
      if (count > 0) pips += count * Coords.toOwn(player, abs);
    }
    return pips;
  }

  /// Маска занятости игрока в абсолютной нумерации (бит `abs - 1`).
  int occupancyMask(Player player) {
    var mask = 0;
    for (var index = 0; index < Coords.pointCount; index++) {
      final value = points[index];
      final occupied = player == Player.white ? value > 0 : value < 0;
      if (occupied) mask |= 1 << index;
    }
    return mask;
  }

  /// Все ли шашки игрока (кроме выброшенных) стоят в его доме.
  bool allInHome(Player player) {
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      if (checkersAt(player, abs) > 0 && !Coords.isHomeAbs(player, abs)) {
        return false;
      }
    }
    return true;
  }

  /// Самый дальний от выброса занятый собственный пункт, `null` — шашек нет.
  int? farthestOwn(Player player) {
    for (var own = Coords.pointCount; own >= 1; own--) {
      if (checkersAt(player, Coords.toAbsolute(player, own)) > 0) return own;
    }
    return null;
  }

  bool get isFinished =>
      whiteBorneOff >= checkersPerPlayer || blackBorneOff >= checkersPerPlayer;

  Player? get winner {
    if (whiteBorneOff >= checkersPerPlayer) return Player.white;
    if (blackBorneOff >= checkersPerPlayer) return Player.black;
    return null;
  }

  /// Применяет одно перемещение. Очередь хода не передаётся,
  /// использованное число вычёркивается из [remainingDice].
  GameState applyMove(Move move) {
    final next = List<int>.of(points);
    final sign = move.player.sign;
    next[Coords.absIndex(move.fromAbs)] -= sign;

    var white = whiteBorneOff;
    var black = blackBorneOff;
    if (move.isBearOff) {
      if (move.player == Player.white) {
        white++;
      } else {
        black++;
      }
    } else {
      next[Coords.absIndex(move.toAbs!)] += sign;
    }

    final dice = List<int>.of(remainingDice)..remove(move.die);
    return GameState(
      points: next,
      turn: turn,
      roll: roll,
      remainingDice: dice,
      whiteBorneOff: white,
      blackBorneOff: black,
      turnIndex: turnIndex,
      headMovesUsed: headMovesUsed + (move.isFromHead ? 1 : 0),
    );
  }

  /// Применяет ход целиком.
  GameState applySequence(MoveSequence sequence) {
    var state = this;
    for (final move in sequence.moves) {
      state = state.applyMove(move);
    }
    return state;
  }

  /// Передаёт очередь сопернику и выставляет новый бросок.
  GameState nextTurn(DiceRoll nextRoll) => GameState(
    points: points,
    turn: turn.opponent,
    roll: nextRoll,
    remainingDice: nextRoll.toRemaining(),
    whiteBorneOff: whiteBorneOff,
    blackBorneOff: blackBorneOff,
    turnIndex: turnIndex + 1,
    headMovesUsed: 0,
  );

  GameState copyWith({
    List<int>? points,
    Player? turn,
    DiceRoll? roll,
    List<int>? remainingDice,
    int? whiteBorneOff,
    int? blackBorneOff,
    int? turnIndex,
    int? headMovesUsed,
  }) => GameState(
    points: points ?? this.points,
    turn: turn ?? this.turn,
    roll: roll ?? this.roll,
    remainingDice: remainingDice ?? this.remainingDice,
    whiteBorneOff: whiteBorneOff ?? this.whiteBorneOff,
    blackBorneOff: blackBorneOff ?? this.blackBorneOff,
    turnIndex: turnIndex ?? this.turnIndex,
    headMovesUsed: headMovesUsed ?? this.headMovesUsed,
  );

  /// Список нарушений инвариантов. Пустой список — состояние корректно.
  List<String> validate() {
    final problems = <String>[];
    if (points.length != Coords.pointCount) {
      problems.add('points length ${points.length} != ${Coords.pointCount}');
    }
    for (final player in Player.values) {
      final total = onBoard(player) + borneOff(player);
      if (total != checkersPerPlayer) {
        problems.add('${player.name}: $total checkers instead of $checkersPerPlayer');
      }
      if (borneOff(player) < 0 || borneOff(player) > checkersPerPlayer) {
        problems.add('${player.name}: borne off ${borneOff(player)} out of range');
      }
    }
    for (var abs = 1; abs <= Coords.pointCount; abs++) {
      if (checkersAt(Player.white, abs) > 0 &&
          checkersAt(Player.black, abs) > 0) {
        problems.add('point $abs holds both colours');
      }
    }
    final allowed = roll.toRemaining();
    for (final die in remainingDice) {
      if (!allowed.remove(die)) {
        problems.add('remaining die $die is not part of roll $roll');
      }
    }
    return problems;
  }

  /// Компактная строка состояния: для логов, дедупликации и P4.
  String encode() {
    final buffer = StringBuffer()
      ..writeAll(points, ',')
      ..write('|$whiteBorneOff|$blackBorneOff|${turn.code}')
      ..write('|${roll.a}-${roll.b}|')
      ..writeAll(remainingDice, ',')
      ..write('|$turnIndex|$headMovesUsed');
    return buffer.toString();
  }

  static GameState decode(String encoded) {
    final parts = encoded.split('|');
    if (parts.length != 8) {
      throw FormatException('Bad GameState encoding', encoded);
    }
    final rollParts = parts[4].split('-').map(int.parse).toList();
    return GameState(
      points: parts[0].split(',').map(int.parse).toList(),
      whiteBorneOff: int.parse(parts[1]),
      blackBorneOff: int.parse(parts[2]),
      turn: Player.fromCode(parts[3]),
      roll: DiceRoll(rollParts[0], rollParts[1]),
      remainingDice: parts[5].isEmpty
          ? const <int>[]
          : parts[5].split(',').map(int.parse).toList(),
      turnIndex: int.parse(parts[6]),
      headMovesUsed: int.parse(parts[7]),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! GameState) return false;
    if (other.turn != turn ||
        other.roll != roll ||
        other.whiteBorneOff != whiteBorneOff ||
        other.blackBorneOff != blackBorneOff ||
        other.turnIndex != turnIndex ||
        other.headMovesUsed != headMovesUsed) {
      return false;
    }
    return sameItems(other.remainingDice, remainingDice) &&
        sameItems(other.points, points);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(points),
    Object.hashAll(remainingDice),
    whiteBorneOff,
    blackBorneOff,
    turn,
    roll,
    turnIndex,
    headMovesUsed,
  );

  @override
  String toString() =>
      'GameState(turn: ${turn.name}, roll: $roll, remaining: $remainingDice, '
      'off: $whiteBorneOff/$blackBorneOff)';
}
