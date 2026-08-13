import 'package:flutter_test/flutter_test.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda_core/narda_core.dart';

import 'support/positions.dart';

void main() {
  test('бот считает ход в изоляте и возвращает легальную последовательность', () async {
    final BotOpponent opponent = BotOpponent(
      player: Player.black,
      level: BotLevel.oson,
      thinkTime: Duration.zero,
      seed: 5,
    );
    addTearDown(opponent.dispose);

    final GameState state = GameState.initial(
      first: Player.black,
      roll: const DiceRoll(3, 2),
    );
    final MoveSequence? sequence = await opponent.chooseSequence(state);

    expect(sequence, isNotNull);
    expect(sequence!.moves, hasLength(2));
    expect(
      const MoveGenerator()
          .generate(state)
          .map((MoveSequence s) => state.applySequence(s)),
      contains(state.applySequence(sequence)),
    );
  });

  test('выброс восстанавливается из плоской записи хода', () {
    final GameState state = position(
      turn: Player.white,
      roll: const DiceRoll(5, 2),
      white: <int, int>{3: 1, 2: 1},
      whiteBorneOff: 13,
    );
    final MoveSequence sequence = decodeFlatSequence(state, <int>[3, 5, 2, 2]);

    expect(sequence.moves.every((Move move) => move.isBearOff), isTrue);
    expect(state.applySequence(sequence).whiteBorneOff, 15);
  });
}
