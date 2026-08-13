import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/ads/ads_controller.dart';
import 'package:narda/ads/interstitial_policy.dart';
import 'package:narda/app.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/match_controller.dart';
import 'package:narda/game/opponent.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/game/stats.dart';
import 'package:narda/l10n/gen/app_text.dart';
import 'package:narda/theme/board_theme.dart';
import 'package:narda/ui/rules_screen.dart';
import 'package:narda/ui/stats_screen.dart';
import 'package:narda/ui/themes_screen.dart';
import 'package:narda_core/narda_core.dart';

import 'support/match_helpers.dart';
import 'support/positions.dart';

Widget wrap(Widget child, {SettingsController? settings, StatsStore? stats}) =>
    SettingsScope(
      controller: settings ?? SettingsController.inMemory(),
      child: StatsScope(
        store: stats ?? StatsStore.inMemory(),
        child: AdsScope(
          controller: AdsController.disabled(),
          child: MaterialApp(
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            localeListResolutionCallback: resolveNardaLocale,
            home: child,
          ),
        ),
      ),
    );

void main() {
  group('серия до 3 очков', () {
    test('счёт копится между партиями, серия кончается на цели', () async {
      final MatchController controller = MatchController(
        setup: const GameSetup.hotseat(target: MatchTarget.to3),
        settings: SettingsController.inMemory(),
        // Каждая партия серии заново разыгрывает первый ход, поэтому
        // одиночных бросков нужно с запасом.
        dice: scriptedDice(
          singles: const <int>[6, 1, 6, 1, 6, 1, 6, 1],
          roll: const DiceRoll(6, 5),
        ),
        opponent: const HotseatOpponent(Player.black),
        timing: const MatchTiming.instant(),
      );
      controller.start();
      await Future<void>.delayed(Duration.zero);

      // Сдача: сдаётся тот, чей ход, соперник получает марс — 2 очка.
      controller.resign();
      final Player firstWinner = controller.result!.winner;
      expect(controller.score.pointsOf(firstWinner), 2);
      expect(controller.isMatchOver, isFalse, reason: '2 из 3 — серия жива');

      controller.nextGame();
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.score.pointsOf(firstWinner),
        2,
        reason: 'следующая партия серии счёт не сбрасывает',
      );

      controller.resign();
      expect(controller.isMatchOver, isTrue);
      expect(controller.score.winner, isNotNull);

      controller.newMatch();
      await Future<void>.delayed(Duration.zero);
      expect(controller.score.white, 0);
      expect(controller.score.black, 0);
      controller.dispose();
    });

    test('одиночная партия завершает «серию» первой же победой', () async {
      final MatchController controller = MatchController(
        setup: const GameSetup.hotseat(),
        settings: SettingsController.inMemory(),
        dice: scriptedDice(roll: const DiceRoll(6, 5)),
        opponent: const HotseatOpponent(Player.black),
        timing: const MatchTiming.instant(),
      );
      controller.start();
      await Future<void>.delayed(Duration.zero);
      controller.resign();
      expect(controller.isMatchOver, isTrue);
      controller.dispose();
    });
  });

  test('Definition of Done: 20 партий подряд без сбоев и нелегальных ходов', () async {
    final StatsStore stats = StatsStore.inMemory();
    final MatchController controller = MatchController(
      setup: const GameSetup.vsBot(BotLevel.oson, target: MatchTarget.to7),
      settings: SettingsController.inMemory(),
      dice: RandomDiceSource.seeded(2026),
      opponent: StubBot(Player.black, level: BotLevel.oson),
      timing: const MatchTiming.instant(),
      onGameFinished: (GameResult result) =>
          stats.recordGame(result, local: Player.white),
    );
    addTearDown(controller.dispose);
    controller.start();

    for (int game = 1; game <= 20; game++) {
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
      expect(controller.state.isFinished, isTrue, reason: 'партия $game');
      // Серия до 7 очков успевает закончиться раньше 20 партий — тогда
      // начинается следующая, ровно как это делает экран.
      if (controller.isMatchOver) {
        controller.newMatch();
      } else {
        controller.nextGame();
      }
    }

    expect(stats.stats.games, 20);
    expect(stats.stats.wins + stats.stats.losses, 20);
  });

  group('статистика', () {
    test('партии, винрейт и марсы считаются глазами игрока', () {
      final StatsStore store = StatsStore.inMemory();
      store.recordGame(
        const GameResult(winner: Player.white, isMars: true),
        local: Player.white,
      );
      store.recordGame(
        const GameResult(winner: Player.black, isMars: false),
        local: Player.white,
      );
      store.recordGame(
        const GameResult(winner: Player.black, isMars: true),
        local: Player.white,
      );

      final Stats stats = store.stats;
      expect(stats.games, 3);
      expect(stats.wins, 1);
      expect(stats.losses, 2);
      expect(stats.winRate, 33);
      expect(stats.marsWins, 1);
      expect(stats.marsLosses, 1);
    });

    test('серии считаются отдельно, сброс обнуляет всё', () {
      final StatsStore store = StatsStore.inMemory();
      store.recordMatch(won: true);
      store.recordMatch(won: false);
      expect(store.stats.matches, 2);
      expect(store.stats.matchWins, 1);

      store.reset();
      expect(store.stats.games, 0);
      expect(store.stats.matches, 0);
      expect(store.stats.winRate, 0);
    });
  });

  group('темы доски', () {
    test('платная тема закрыта, пока не открыта роликом', () {
      final SettingsController settings = SettingsController.inMemory();
      expect(settings.isUnlocked(klassikTheme), isTrue);
      expect(settings.isUnlocked(zarTheme), isFalse);

      settings.boardTheme = zarTheme;
      expect(
        settings.boardTheme.id,
        klassikTheme.id,
        reason: 'закрытая тема не должна применяться',
      );
    });

    test('ролик открывает тему ровно на 24 часа', () {
      DateTime now = DateTime(2026, 8, 13, 12);
      final SettingsController settings = SettingsController.inMemory(
        now: () => now,
      );

      settings.unlockTheme(kokGumbazTheme);
      settings.boardTheme = kokGumbazTheme;
      expect(settings.boardTheme.id, kokGumbazTheme.id);
      expect(settings.unlockRemaining(kokGumbazTheme), const Duration(hours: 24));

      now = now.add(const Duration(hours: 23, minutes: 59));
      expect(settings.isUnlocked(kokGumbazTheme), isTrue);

      now = now.add(const Duration(minutes: 2));
      expect(settings.isUnlocked(kokGumbazTheme), isFalse);
      expect(
        settings.boardTheme.id,
        klassikTheme.id,
        reason: 'после истечения доска возвращается к классике',
      );
    });
  });

  group('правило показа interstitial', () {
    final DateTime start = DateTime(2026, 8, 13, 12);

    test('первые две партии проходят без рекламы', () {
      final InterstitialPolicy policy = InterstitialPolicy();
      expect(policy.allows(start), isFalse);
      policy.noteGameFinished();
      expect(policy.allows(start), isFalse);
      policy.noteGameFinished();
      expect(policy.allows(start), isFalse, reason: 'вторая партия ещё бесплатна');
      policy.noteGameFinished();
      expect(policy.allows(start), isTrue);
    });

    test('после показа держится пауза в три минуты', () {
      final InterstitialPolicy policy = InterstitialPolicy();
      for (int i = 0; i < 3; i++) {
        policy.noteGameFinished();
      }
      expect(policy.allows(start), isTrue);

      policy.noteShown(start);
      policy.noteGameFinished();
      expect(policy.allows(start.add(const Duration(minutes: 2))), isFalse);
      expect(policy.allows(start.add(const Duration(minutes: 3))), isTrue);
    });

    test('выключенная реклама не показывается никогда', () {
      final AdsController ads = AdsController.disabled();
      for (int i = 0; i < 10; i++) {
        ads.noteGameFinished();
      }
      expect(ads.enabled, isFalse);
      expect(ads.canShowInterstitial, isFalse);
      expect(ads.rewardedReady, isFalse);
    });
  });

  group('экраны P3', () {
    testWidgets('главное меню ведёт в правила, статистику и темы', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(NardaApp(settings: SettingsController.inMemory()));
      await tester.pumpAndSettle();

      expect(find.text('Qoidalar'), findsOneWidget);
      expect(find.text('Statistika'), findsOneWidget);
      expect(find.text('Doska mavzusi'), findsOneWidget);

      await tester.tap(find.text('Qoidalar'));
      await tester.pumpAndSettle();
      expect(find.text('1. Maqsad'), findsOneWidget);
      expect(find.byType(RulesScreen), findsOneWidget);
    });

    testWidgets('лист старта предлагает формат матча и уровень', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(NardaApp(settings: SettingsController.inMemory()));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Bot bilan o'ynash"));
      await tester.pumpAndSettle();

      expect(find.text('Partiya formati'), findsOneWidget);
      expect(find.text('Bitta partiya'), findsOneWidget);
      expect(find.text('Kuchli'), findsOneWidget);
    });

    testWidgets('статистика показывает винрейт', (WidgetTester tester) async {
      final StatsStore store = StatsStore.inMemory();
      store.recordGame(
        const GameResult(winner: Player.white, isMars: false),
        local: Player.white,
      );
      await tester.pumpWidget(wrap(const StatsScreen(), stats: store));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('экран тем показывает три темы и запертость платных', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const ThemesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Klassik'), findsOneWidget);
      expect(find.text("Ko'k gumbaz"), findsOneWidget);
      expect(find.text('Zar'), findsOneWidget);
      expect(find.text('Tanlangan'), findsOneWidget);
      expect(find.text("Video ko'rib oching"), findsNWidgets(2));
    });

    testWidgets('язык переключается настройкой', (WidgetTester tester) async {
      final SettingsController settings = SettingsController.inMemory();
      await tester.pumpWidget(NardaApp(settings: settings));
      await tester.pumpAndSettle();
      expect(find.text("Bot bilan o'ynash"), findsOneWidget);

      settings.localeCode = 'ru';
      await tester.pumpAndSettle();
      expect(find.text("Bot bilan o'ynash"), findsNothing);
      expect(find.text('Правила'), findsOneWidget);
    });
  });
}
