import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/app.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/match_controller.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/ui/board/board_geometry.dart';
import 'package:narda/ui/board/board_view.dart';
import 'package:narda/ui/game_screen.dart';
import 'package:narda_core/narda_core.dart';

import 'support/harness.dart';
import 'support/positions.dart';

void main() {
  testWidgets('главный экран предлагает оба режима', (WidgetTester tester) async {
    await tester.pumpWidget(NardaApp(settings: SettingsController.inMemory()));
    await tester.pumpAndSettle();

    expect(find.text('Uzun narda'), findsOneWidget);
    expect(find.text("Bot bilan o'ynash"), findsOneWidget);
    expect(find.text('Bitta qurilmada'), findsOneWidget);
  });

  testWidgets('тап по шашке подсвечивает назначения, второй тап ходит', (
    WidgetTester tester,
  ) async {
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
    final BoardGeometry geometry = BoardGeometry(
      size: board.size,
      perspective: Player.white,
    );

    await tester.tapAt(board.topLeft + geometry.hitRect(24).center);
    await tester.pumpAndSettle();
    expect(controller.selected, 24);
    expect(controller.destinations, containsAll(<int?>[18, 19]));

    await tester.tapAt(board.topLeft + geometry.hitRect(18).center);
    await tester.pumpAndSettle();
    expect(controller.selected, isNull);
    expect(controller.state.checkersAt(Player.white, 18), 1);
  });

  testWidgets('кнопка подтверждения включается собранным ходом', (
    WidgetTester tester,
  ) async {
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

    final Finder confirm = find.widgetWithText(FilledButton, 'Tasdiqlash');
    expect(confirm, findsNothing, reason: 'пока показан счётчик перемещений');

    controller
      ..tapPoint(24)
      ..tapPoint(18)
      ..tapPoint(18)
      ..tapPoint(13);
    await tester.pumpAndSettle();

    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(controller.state.turn, Player.black);
  });
}
