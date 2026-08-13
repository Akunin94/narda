import 'package:flutter_test/flutter_test.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/match_controller.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda/game/settings.dart';
import 'package:narda_core/narda_core.dart';

import 'support/match_helpers.dart';
import 'support/positions.dart';

void main() {
  test('hotseat: ход собирается тапами, доска переворачивается', () async {
    final MatchController controller = MatchController(
      setup: const GameSetup.hotseat(),
      settings: SettingsController.inMemory(autoMove: false),
      dice: scriptedDice(roll: const DiceRoll(6, 5)),
      opponent: const HotseatOpponent(Player.black),
      timing: const MatchTiming.instant(),
    );
    addTearDown(controller.dispose);

    controller.start();
    await settle();

    expect(controller.phase, TurnPhase.choosing);
    expect(controller.state.turn, Player.white);
    expect(controller.perspective, Player.white);

    controller.tapPoint(24);
    expect(controller.selected, 24);
    expect(controller.destinations, containsAll(<int?>[18, 19]));

    controller.tapPoint(18);
    expect(controller.state.checkersAt(Player.white, 18), 1);
    expect(controller.canConfirm, isFalse);
    expect(controller.canUndo, isTrue);

    controller.tapPoint(18);
    controller.tapPoint(13);
    expect(controller.canConfirm, isTrue);

    controller.confirm();
    await settle();

    expect(controller.state.turn, Player.black);
    expect(controller.perspective, Player.black, reason: 'доска перевернулась');
    expect(controller.lastTurnMoves, hasLength(2));
  });

  test('отмена возвращает шашку до подтверждения хода', () async {
    final MatchController controller = MatchController(
      setup: const GameSetup.hotseat(),
      settings: SettingsController.inMemory(autoMove: false),
      dice: scriptedDice(roll: const DiceRoll(6, 5)),
      opponent: const HotseatOpponent(Player.black),
      timing: const MatchTiming.instant(),
    );
    addTearDown(controller.dispose);

    controller.start();
    await settle();

    controller.tapPoint(24);
    controller.tapPoint(18);
    expect(controller.state.checkersAt(Player.white, 24), 14);

    controller.undo();
    expect(controller.state.checkersAt(Player.white, 24), 15);
    expect(controller.canUndo, isFalse);
  });

  test('бот отвечает и очередь возвращается игроку', () async {
    final MatchController controller = MatchController(
      setup: const GameSetup.vsBot(BotLevel.orta),
      settings: SettingsController.inMemory(),
      dice: scriptedDice(roll: const DiceRoll(6, 5)),
      opponent: StubBot(Player.black),
      timing: const MatchTiming.instant(),
    );
    addTearDown(controller.dispose);

    controller.start();
    await settle();
    expect(controller.state.turn, Player.white);

    playLocalTurn(controller);
    await settle();

    expect(controller.state.turn, Player.white, reason: 'бот уже сходил');
    expect(controller.phase, TurnPhase.choosing);
    expect(controller.perspective, Player.white, reason: 'доска не вертится');
    expect(controller.state.checkersAt(Player.black, 12), lessThan(15));
  });

  test('партии доигрываются до конца и остаются легальными', () async {
    for (int game = 0; game < 3; game++) {
      final MatchController controller = MatchController(
        setup: const GameSetup.vsBot(BotLevel.oson),
        settings: SettingsController.inMemory(),
        dice: RandomDiceSource.seeded(game),
        opponent: StubBot(Player.black),
        timing: const MatchTiming.instant(),
      );
      controller.start();

      var guard = 0;
      while (controller.phase != TurnPhase.finished && guard++ < 5000) {
        await settle();
        if (controller.canInteract) playLocalTurn(controller);
        expect(
          controller.state.validate(),
          isEmpty,
          reason: 'партия $game, шаг $guard',
        );
      }

      expect(controller.phase, TurnPhase.finished, reason: 'партия $game');
      expect(controller.result, isNotNull);
      expect(controller.state.isFinished, isTrue);
      controller.dispose();
    }
  });

  test('сдача завершает партию марсом', () async {
    final MatchController controller = MatchController(
      setup: const GameSetup.vsBot(BotLevel.oson),
      settings: SettingsController.inMemory(),
      dice: scriptedDice(),
      opponent: StubBot(Player.black),
      timing: const MatchTiming.instant(),
    );
    addTearDown(controller.dispose);

    controller.start();
    await settle();
    controller.resign();

    expect(controller.phase, TurnPhase.finished);
    final GameResult result = controller.result!;
    expect(result.winner, Player.black);
    expect(result.byResignation, isTrue);
    expect(result.isMars, isTrue);
    expect(result.points, 2);
  });
}
