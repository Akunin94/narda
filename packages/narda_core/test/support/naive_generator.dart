import 'package:narda_core/narda_core.dart';

/// Заведомо простой эталонный генератор для перекрёстной проверки.
///
/// Не использует ни битовых масок, ни черновой доски: перебирает все пункты,
/// проверяет каждое перемещение через [Rules.isLegalSingle] и строит новое
/// состояние через [GameState.applyMove]. Медленный, но прямолинейный —
/// расхождение с [MoveGenerator] означает ошибку в оптимизированном коде.
class NaiveGenerator {
  const NaiveGenerator();

  List<MoveSequence> generate(GameState state) {
    if (state.isFinished || state.remainingDice.isEmpty) {
      return <MoveSequence>[];
    }
    final results = <MoveSequence>[];
    var best = 0;

    void walk(GameState current, List<Move> path) {
      var extended = false;
      for (final die in current.remainingDice.toSet()) {
        for (var abs = 1; abs <= Coords.pointCount; abs++) {
          if (current.checkersAt(current.turn, abs) == 0) continue;
          final own = Coords.toOwn(current.turn, abs);
          final target = own - die;
          final move = target >= 1
              ? Move(
                  player: current.turn,
                  fromAbs: abs,
                  die: die,
                  toAbs: Coords.toAbsolute(current.turn, target),
                )
              : Move.bearOff(player: current.turn, fromAbs: abs, die: die);
          if (!Rules.isLegalSingle(current, move)) continue;
          extended = true;
          walk(current.applyMove(move), <Move>[...path, move]);
        }
      }
      if (extended || path.isEmpty) return;
      if (path.length > best) {
        best = path.length;
        results.clear();
      }
      if (path.length == best) results.add(MoveSequence(path));
    }

    walk(state, <Move>[]);

    if (best == 1 && !state.roll.isDouble && state.remainingDice.length > 1) {
      final highest = state.remainingDice.reduce((int a, int b) => a > b ? a : b);
      final withHighest = results
          .where((MoveSequence s) => s.moves.first.die == highest)
          .toList();
      if (withHighest.isNotEmpty) return withHighest;
    }
    return results;
  }
}
