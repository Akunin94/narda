import 'package:flutter_test/flutter_test.dart';
import 'package:narda/game/turn_planner.dart';
import 'package:narda_core/narda_core.dart';

import 'support/positions.dart';

void main() {
  group('правило головы', () {
    test('стартовый дубль 6-6 разрешает ровно две шашки с головы', () {
      final GameState state = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(6, 6),
      );
      final TurnPlanner planner = TurnPlanner(base: state);

      expect(planner.maxMoves, 2);
      expect(planner.sources, <int>[24]);

      planner.apply(planner.moveTo(24, 18)!);
      expect(planner.sources, <int>[24], reason: 'вторая шашка с головы');

      planner.apply(planner.moveTo(24, 18)!);
      expect(planner.isComplete, isTrue);
      expect(planner.sources, isEmpty);
      expect(planner.current.checkersAt(Player.white, 18), 2);
      expect(planner.current.checkersAt(Player.white, 24), 13);
    });

    test('обычный первый бросок снимает с головы только одну шашку', () {
      final GameState state = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(6, 5),
      );
      final TurnPlanner planner = TurnPlanner(base: state);

      planner.apply(planner.moveTo(24, 18)!);
      expect(planner.sources, isNot(contains(24)));
      expect(planner.movesFrom(18).single.toAbs, 13);
    });
  });

  group('обязательность полного хода', () {
    test('когда играбельно одно число — предлагается только большее', () {
      // Белая шашка на 10: 10-2 = 8 занято чёрными, 10-5 = 5 свободно,
      // но продолжения 5-2 = 3 нет — тоже занято.
      final GameState state = position(
        turn: Player.white,
        roll: const DiceRoll(5, 2),
        white: <int, int>{10: 1},
        black: <int, int>{8: 1, 3: 1},
      );
      final TurnPlanner planner = TurnPlanner(base: state);

      expect(planner.maxMoves, 1);
      expect(planner.movesFrom(10).single.die, 5);
      expect(planner.movesFrom(10).single.toAbs, 5);
    });

    test('перемещение, ломающее максимальность хода, недоступно', () {
      // Оба числа играются только через 9->4->1. Ход 20->15 легален сам по
      // себе, но после него второе число сыграть нечем, поэтому запрещён.
      final GameState state = position(
        turn: Player.white,
        roll: const DiceRoll(5, 3),
        white: <int, int>{9: 1, 20: 1},
        black: <int, int>{6: 1, 17: 1, 12: 1},
      );
      final TurnPlanner planner = TurnPlanner(base: state);

      expect(planner.maxMoves, 2);
      expect(planner.movesFrom(20), isEmpty);
      expect(planner.movesFrom(9).single.toAbs, 4);

      planner.apply(planner.moveTo(9, 4)!);
      expect(planner.movesFrom(4).single.toAbs, 1);
    });
  });

  group('выброс', () {
    test('точное и превышающее число выбрасывают шашки', () {
      final GameState state = position(
        turn: Player.white,
        roll: const DiceRoll(5, 2),
        white: <int, int>{3: 1, 2: 1},
        whiteBorneOff: 13,
      );
      final TurnPlanner planner = TurnPlanner(base: state);

      expect(planner.maxMoves, 2);
      // 5 больше самого дальнего занятого пункта 3 — выброс разрешён с него.
      planner.apply(planner.moveTo(3, null)!);
      planner.apply(planner.moveTo(2, null)!);

      expect(planner.isComplete, isTrue);
      expect(planner.current.whiteBorneOff, 15);
      expect(planner.current.isFinished, isTrue);
    });
  });

  group('сбор хода', () {
    GameState freePosition() => position(
      turn: Player.white,
      roll: const DiceRoll(5, 3),
      white: <int, int>{9: 1, 20: 1},
    );

    test('порядок перемещений игрока приводится к варианту ядра', () {
      final GameState state = freePosition();
      final TurnPlanner planner = TurnPlanner(base: state);
      // Сначала меньшее число, потом большее — ядро такой порядок схлопывает.
      planner.apply(planner.moveTo(20, 17)!);
      planner.apply(planner.moveTo(9, 4)!);

      final MoveSequence? canonical = planner.canonicalSequence;
      expect(canonical, isNotNull);
      expect(planner.options, contains(canonical));
      expect(state.applySequence(canonical!), planner.current);
    });

    test('отмена и сброс возвращают состояние хода', () {
      final GameState state = freePosition();
      final TurnPlanner planner = TurnPlanner(base: state);
      planner.apply(planner.moveTo(9, 4)!);
      expect(planner.canUndo, isTrue);

      planner.undo();
      expect(planner.canUndo, isFalse);
      expect(planner.current, state);

      planner
        ..apply(planner.moveTo(9, 4)!)
        ..apply(planner.moveTo(4, 1)!)
        ..reset();
      expect(planner.played, isEmpty);
      expect(planner.current, state);
    });
  });

  test('когда ходов нет, план пуст', () {
    // Единственная белая шашка на 4: 4-3 = 1 и 4-1 = 3 заняты чёрными.
    final GameState state = position(
      turn: Player.white,
      roll: const DiceRoll(3, 1),
      white: <int, int>{4: 1},
      black: <int, int>{1: 1, 3: 1},
    );
    final TurnPlanner planner = TurnPlanner(base: state);

    expect(planner.options, isEmpty);
    expect(planner.maxMoves, 0);
    expect(planner.isComplete, isFalse);
    expect(planner.sources, isEmpty);
  });
}
