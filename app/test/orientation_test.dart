import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/app.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/match_controller.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/ui/board/board_view.dart';
import 'package:narda/ui/game_screen.dart';
import 'package:narda_core/narda_core.dart';

import 'support/harness.dart';
import 'support/positions.dart';

void main() {
  // Типичный телефон: 393×851 dp в портрете и наоборот в альбоме.
  for (final Size size in const <Size>[Size(393, 851), Size(851, 393)]) {
    final String label = size.width > size.height ? 'альбом' : 'портрет';

    testWidgets('$label: меню и партия без переполнений', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(NardaApp(settings: SettingsController.inMemory()));
      await tester.pumpAndSettle();
      expect(find.text("Bot bilan o'ynash"), findsOneWidget);

      final MatchController controller = MatchController(
        setup: const GameSetup.hotseat(),
        settings: SettingsController.inMemory(autoMove: false),
        dice: scriptedDice(roll: const DiceRoll(6, 5)),
        opponent: const HotseatOpponent(Player.black),
        timing: const MatchTiming.instant(),
      );
      await tester.pumpWidget(
        wrap(
          GameScreen(setup: const GameSetup.hotseat(), controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final Rect board = tester.getRect(find.byType(BoardView));
      // Доска повторяет ориентацию экрана: в альбоме шире, в портрете выше.
      expect(board.width > board.height, size.width > size.height);
      expect(tester.takeException(), isNull);
    });
  }
}
