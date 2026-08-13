import 'coords.dart';
import 'game_state.dart';
import 'move.dart';
import 'player.dart';

/// Предикаты легальности отдельного перемещения (§3.2, §3.3).
abstract final class Rules {
  /// Длина запрещённого «глухого забора».
  static const int blockLength = 6;

  /// Дубли, при которых на самом первом броске партии разрешено снять
  /// с головы ДВЕ шашки (§3.2.5).
  static const Set<int> firstTurnHeadExceptions = <int>{3, 4, 6};

  /// Маска всех 24 пунктов.
  static const int fullMask = 0xFFFFFF;

  /// Маска дома в собственной нумерации: пункты 1..6 — биты 0..5.
  static const int homeMask = 0x3F;

  /// Сколько шашек разрешено снять с головы за текущий ход.
  static int headLimit(GameState state) {
    if (state.isFirstTurnOfMover &&
        state.roll.isDouble &&
        firstTurnHeadExceptions.contains(state.roll.a)) {
      return 2;
    }
    return 1;
  }

  /// Поворот 24-битной маски на полкруга: перевод между абсолютной
  /// нумерацией и собственной нумерацией чёрных (сдвиг на 12 пунктов).
  /// Операция является инволюцией.
  static int rotateHalf(int mask) =>
      ((mask << 12) | (mask >> 12)) & fullMask;

  /// Маска занятости [player] в собственной нумерации игрока [viewer].
  static int maskInOwnNumbering({
    required int absoluteMask,
    required Player viewer,
  }) => viewer == Player.white ? absoluteMask : rotateHalf(absoluteMask);

  /// Может ли игрок выбрасывать шашки: все шашки на доске в его доме.
  static bool canBearOff(GameState state, Player player) =>
      state.allInHome(player);

  /// Занят ли абсолютный пункт [abs] шашками соперника игрока [player].
  static bool isBlockedFor(GameState state, Player player, int abs) =>
      state.checkersAt(player.opponent, abs) > 0;

  /// Легально ли одиночное перемещение [move] в состоянии [state].
  /// Проверяются все ограничения §3.2 и §3.3, включая правило блока.
  static bool isLegalSingle(GameState state, Move move) {
    if (move.player != state.turn) return false;
    if (!state.remainingDice.contains(move.die)) return false;
    if (state.checkersAt(move.player, move.fromAbs) <= 0) return false;
    if (move.isFromHead && state.headMovesUsed >= headLimit(state)) return false;

    final targetOwn = Coords.toOwn(move.player, move.fromAbs) - move.die;
    if (targetOwn >= 1) {
      if (move.isBearOff) return false;
      if (move.toAbs != Coords.toAbsolute(move.player, targetOwn)) return false;
      if (isBlockedFor(state, move.player, move.toAbs!)) return false;
    } else {
      if (!move.isBearOff) return false;
      if (!canBearOff(state, move.player)) return false;
      if (targetOwn < 0 &&
          state.farthestOwn(move.player) !=
              Coords.toOwn(move.player, move.fromAbs)) {
        return false;
      }
    }

    return !createsIllegalBlock(state.applyMove(move), move.player);
  }

  /// Нарушает ли позиция [state] правило шести подряд для игрока [mover]:
  /// 6+ подряд занятых им пунктов, перед которыми (по направлению движения
  /// соперника) не осталось ни одной шашки соперника.
  ///
  /// Считаем ряды в СОБСТВЕННОЙ нумерации соперника: именно её порядок
  /// описывает путь, который соперник обязан пройти, и «забор», разорванный
  /// концом его маршрута, стеной не является.
  static bool createsIllegalBlock(GameState state, Player mover) {
    final opponent = mover.opponent;
    if (state.borneOff(opponent) > 0) return false;
    return hasIllegalBlock(
      moverMask: maskInOwnNumbering(
        absoluteMask: state.occupancyMask(mover),
        viewer: opponent,
      ),
      opponentMask: maskInOwnNumbering(
        absoluteMask: state.occupancyMask(opponent),
        viewer: opponent,
      ),
    );
  }

  /// Битовая проверка правила блока. Обе маски заданы в собственной
  /// нумерации соперника: бит `own - 1`.
  static bool hasIllegalBlock({
    required int moverMask,
    required int opponentMask,
  }) {
    final runs =
        moverMask &
        (moverMask >> 1) &
        (moverMask >> 2) &
        (moverMask >> 3) &
        (moverMask >> 4) &
        (moverMask >> 5);
    if (runs == 0) return false;
    // Самый «ранний» забор строже всех: чем меньше его начало, тем меньше
    // пунктов остаётся впереди для шашек соперника.
    final lowestBit = (runs & -runs).bitLength - 1;
    final aheadMask = opponentMask & ((1 << lowestBit) - 1);
    return aheadMask == 0;
  }
}
