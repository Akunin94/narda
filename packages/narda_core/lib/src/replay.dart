import 'coords.dart';
import 'dice.dart';
import 'game_state.dart';
import 'move.dart';
import 'move_generator.dart';
import 'player.dart';
import 'result.dart';

/// Заглушка броска для позиции, чей бросок журналу ещё не известен.
const DiceRoll _pendingRoll = DiceRoll(1, 1);

/// Собирает перемещение по паре `fromAbs, die`: за пределы дома — выброс.
///
/// Бросает [FormatException] на числах вне доски — журнал может прийти
/// с чужого устройства, доверять ему нельзя.
Move decodeMove({
  required Player player,
  required int fromAbs,
  required int die,
}) {
  if (fromAbs < 1 || fromAbs > Coords.pointCount) {
    throw FormatException('Point $fromAbs is outside the board');
  }
  if (die < 1 || die > 6) {
    throw FormatException('Die $die is outside 1..6');
  }
  return Coords.toOwn(player, fromAbs) - die >= 1
      ? Move.point(player: player, fromAbs: fromAbs, die: die)
      : Move.bearOff(player: player, fromAbs: fromAbs, die: die);
}

/// Разбирает ход из плоского списка пар `fromAbs, die`.
MoveSequence decodeMoves(Player player, List<int> flat) {
  if (flat.length.isOdd) {
    throw FormatException('Move list has an odd length: ${flat.length}');
  }
  return MoveSequence(<Move>[
    for (var i = 0; i < flat.length; i += 2)
      decodeMove(player: player, fromAbs: flat[i], die: flat[i + 1]),
  ]);
}

/// Записывает ход плоским списком пар `fromAbs, die`.
List<int> encodeMoves(MoveSequence sequence) => <int>[
  for (final move in sequence.moves) ...<int>[move.fromAbs, move.die],
];

/// Один ход в журнале партии: бросок и сыгранная последовательность.
///
/// Последовательность хранится плоским списком пар `fromAbs, die` — в таком
/// виде её удобно передавать между устройствами. Пустой список означает
/// пропуск хода: либо легальных перемещений не было, либо ход просрочен
/// по таймеру онлайн-партии (§6).
class LoggedTurn {
  LoggedTurn({required this.roll, required List<int> moves})
    : moves = List<int>.unmodifiable(moves);

  LoggedTurn.sequence({required this.roll, required MoveSequence sequence})
    : moves = List<int>.unmodifiable(encodeMoves(sequence));

  final DiceRoll roll;

  /// Пары `fromAbs, die`. Пустой список — пропуск хода.
  final List<int> moves;

  bool get isPass => moves.isEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! LoggedTurn || other.roll != roll) return false;
    if (other.moves.length != moves.length) return false;
    for (var i = 0; i < moves.length; i++) {
      if (other.moves[i] != moves[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(roll, Object.hashAll(moves));

  @override
  String toString() => '$roll:${moves.join(',')}';
}

/// Журнал партии: кто ходит первым и все ходы по порядку.
///
/// Позиция партии полностью восстановима реплеем журнала — на этом держится
/// реконнект в онлайне (§6) и проверка чужих ходов.
class GameLog {
  GameLog({required this.first, List<LoggedTurn> turns = const <LoggedTurn>[]})
    : turns = List<LoggedTurn>.unmodifiable(turns);

  /// Кто сделал первый ход партии (§3.2.1).
  final Player first;

  final List<LoggedTurn> turns;

  int get length => turns.length;

  GameLog append(LoggedTurn turn) =>
      GameLog(first: first, turns: <LoggedTurn>[...turns, turn]);

  @override
  String toString() => '${first.code}|${turns.join(' ')}';
}

/// Итог реплея журнала.
class ReplayResult {
  const ReplayResult({required this.state, this.result, this.illegalTurn});

  /// Позиция после последнего разобранного хода.
  ///
  /// Бросок очередного хода журналу ещё не известен, поэтому [GameState.roll]
  /// здесь — заглушка: её обязан заменить согласованный бросок (в оффлайне
  /// это [DiceSource], в онлайне — публикация активного игрока).
  final GameState state;

  /// Итог партии, если она в журнале уже завершилась.
  final GameResult? result;

  /// Индекс первого хода, который не прошёл проверку правилами.
  /// `null` — журнал легален целиком.
  final int? illegalTurn;

  bool get isLegal => illegalTurn == null;

  bool get isFinished => result != null;
}

/// Прогоняет журнал через правила и возвращает позицию.
///
/// Разбор останавливается на первом нелегальном ходе: в [ReplayResult.state]
/// остаётся позиция перед ним, а его индекс — в [ReplayResult.illegalTurn].
ReplayResult replayGame(GameLog log) {
  const generator = MoveGenerator();
  var state = GameState.initial(
    first: log.first,
    roll: log.turns.isEmpty ? _pendingRoll : log.turns.first.roll,
  );

  for (var index = 0; index < log.turns.length; index++) {
    final turn = log.turns[index];
    state = state.copyWith(
      roll: turn.roll,
      remainingDice: turn.roll.toRemaining(),
      headMovesUsed: 0,
    );

    final MoveSequence sequence;
    try {
      sequence = decodeMoves(state.turn, turn.moves);
    } on FormatException {
      return ReplayResult(state: state, illegalTurn: index);
    }

    // Пустой ход принимается всегда: и когда ходов действительно нет,
    // и когда ход просрочен по таймеру — автопас (§6).
    if (sequence.isNotEmpty) {
      if (!generator.generate(state).contains(sequence)) {
        return ReplayResult(state: state, illegalTurn: index);
      }
      state = state.applySequence(sequence);
    }

    if (state.isFinished) {
      return ReplayResult(
        state: state,
        result: GameResult.fromState(state),
        // Ходы после победы в журнале лишние — журнал испорчен.
        illegalTurn: index + 1 < log.turns.length ? index + 1 : null,
      );
    }
    state = state.nextTurn(_pendingRoll);
  }

  return ReplayResult(state: state);
}
