import 'coords.dart';
import 'player.dart';

/// Одно перемещение шашки на [die] пунктов вперёд по маршруту игрока.
///
/// [toAbs] равен `null`, если перемещение является выбросом (chiqarish).
class Move {
  const Move({
    required this.player,
    required this.fromAbs,
    required this.die,
    this.toAbs,
  });

  /// Обычное перемещение внутри доски.
  Move.point({required this.player, required this.fromAbs, required this.die})
    : toAbs = Coords.toAbsolute(player, Coords.toOwn(player, fromAbs) - die);

  /// Выброс шашки с пункта [fromAbs].
  const Move.bearOff({
    required this.player,
    required this.fromAbs,
    required this.die,
  }) : toAbs = null;

  final Player player;
  final int fromAbs;
  final int die;
  final int? toAbs;

  bool get isBearOff => toAbs == null;

  /// Собственный номер пункта отправления.
  int get fromOwn => Coords.toOwn(player, fromAbs);

  /// Снимается ли шашка с головы.
  bool get isFromHead => fromAbs == Coords.headAbs(player);

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.player == player &&
      other.fromAbs == fromAbs &&
      other.die == die &&
      other.toAbs == toAbs;

  @override
  int get hashCode => Object.hash(player, fromAbs, die, toAbs);

  @override
  String toString() => isBearOff ? '$fromAbs/off($die)' : '$fromAbs/$toAbs';
}

/// Ход целиком: 2 перемещения при обычном броске, до 4 при дубле.
/// Пустая последовательность означает пропуск хода («yurish yo'q»).
class MoveSequence {
  MoveSequence(List<Move> moves) : moves = List<Move>.unmodifiable(moves);

  static final MoveSequence empty = MoveSequence(const <Move>[]);

  final List<Move> moves;

  int get length => moves.length;

  bool get isEmpty => moves.isEmpty;

  bool get isNotEmpty => moves.isNotEmpty;

  /// Сколько шашек снято с головы этой последовательностью.
  int get headMoves => moves.where((Move m) => m.isFromHead).length;

  @override
  bool operator ==(Object other) {
    if (other is! MoveSequence || other.moves.length != moves.length) {
      return false;
    }
    for (var i = 0; i < moves.length; i++) {
      if (other.moves[i] != moves[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(moves);

  @override
  String toString() => moves.isEmpty ? '(pas)' : moves.join(' ');
}
