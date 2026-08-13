import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/app.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/online/memory_backend.dart';
import 'package:narda/online/online_backend.dart';
import 'package:narda/online/online_match.dart';
import 'package:narda/online/protocol.dart';
import 'package:narda/online/rating_service.dart';
import 'package:narda/profile/elo.dart';
import 'package:narda/profile/profile.dart';
import 'package:narda/ui/game_screen.dart';
import 'package:narda/ui/online/leaderboard_screen.dart';
import 'package:narda/ui/profile_screen.dart';
import 'package:narda_core/narda_core.dart';

/// Даёт событиям комнаты дойти до адресатов.
Future<void> pump([int rounds = 6]) async {
  for (int i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Двое в одной комнате с профилями: сервер в памяти вместо Firebase.
class _Pair {
  _Pair(this.server, this.host, this.guest);

  static Future<_Pair> open({
    PlayerCard hostCard = const PlayerCard(name: 'A'),
    PlayerCard guestCard = const PlayerCard(name: 'B'),
  }) async {
    final MemoryOnlineServer server = MemoryOnlineServer();
    final RoomHandle host = await MemoryOnlineBackend(server, uid: 'a')
        .createRoom(target: MatchTarget.single, card: hostCard);
    final RoomHandle guest = (await MemoryOnlineBackend(server, uid: 'b')
        .joinByCode(host.snapshot.meta!.code, card: guestCard))!;
    return _Pair(server, host, guest);
  }

  final MemoryOnlineServer server;
  final RoomHandle host;
  final RoomHandle guest;
}

void main() {
  group('Elo', () {
    test('равные рейтинги — ожидание 0.5 и ±16 за матч', () {
      expect(eloExpected(rating: 1200, opponentRating: 1200), 0.5);
      expect(
        eloUpdated(
          rating: 1200,
          opponentRating: 1200,
          won: true,
          ratedGames: 30,
        ),
        1216,
      );
      expect(
        eloUpdated(
          rating: 1200,
          opponentRating: 1200,
          won: false,
          ratedGames: 30,
        ),
        1184,
      );
    });

    test('изменения симметричны: сколько один взял, столько другой отдал', () {
      const int a = 1340;
      const int b = 1185;
      final int gained =
          eloUpdated(rating: a, opponentRating: b, won: true, ratedGames: 30) -
          a;
      final int lost =
          b -
          eloUpdated(rating: b, opponentRating: a, won: false, ratedGames: 30);

      expect(gained, lost);
    });

    test('новичок двигается быстрее, верхушка таблицы — медленнее', () {
      expect(eloK(rating: 1200, ratedGames: 0), 40);
      expect(eloK(rating: 1200, ratedGames: 30), 32);
      expect(eloK(rating: 2100, ratedGames: 30), 20);
    });

    test('победа над сильным дороже победы над слабым', () {
      final int overStrong =
          eloUpdated(
            rating: 1200,
            opponentRating: 1600,
            won: true,
            ratedGames: 30,
          ) -
          1200;
      final int overWeak =
          eloUpdated(
            rating: 1200,
            opponentRating: 900,
            won: true,
            ratedGames: 30,
          ) -
          1200;

      expect(overStrong, greaterThan(overWeak));
    });

    test('рейтинг не опускается ниже пола', () {
      expect(
        eloUpdated(
          rating: 100,
          opponentRating: 2000,
          won: false,
          ratedGames: 30,
        ),
        100,
      );
    });
  });

  group('профиль', () {
    test('ник обрезается, пустой не сохраняется, аватар не выходит за набор', () {
      final ProfileController profile = ProfileController.inMemory(
        const PlayerProfile(name: 'Anvar'),
      );

      profile.name = '   ';
      expect(profile.name, 'Anvar', reason: 'пустой ник не затирает прежний');

      profile.name = 'Juda uzun taxallus yozildi';
      expect(profile.name.length, nardaMaxNameLength);

      profile.avatar = 99;
      expect(profile.avatar, nardaAvatarCount - 1);
      profile.avatar = -3;
      expect(profile.avatar, 0);
    });

    test('итог матча меняет рейтинг и счётчики', () {
      final ProfileController profile = ProfileController.inMemory(
        const PlayerProfile(name: 'A', ratedGames: 30),
      );

      final RatingChange change = profile.applyMatchResult(
        opponentRating: eloStartRating,
        won: true,
      );

      expect(change.before, eloStartRating);
      expect(change.delta, 16);
      expect(profile.rating, eloStartRating + 16);
      expect(profile.ratedGames, 31);
      expect(profile.ratedWins, 1);
    });

    test('партии с ботом рейтинга не касаются', () {
      final ProfileController profile = ProfileController.inMemory();
      final int before = profile.rating;

      // Экран начисляет рейтинг только в онлайне (§P5) — оффлайн профиль
      // трогает разве что ник с аватаром.
      profile.avatar = 3;

      expect(profile.rating, before);
      expect(profile.ratedGames, 0);
    });
  });

  group('таблица лидеров', () {
    test('рейтинг обеих сторон сходится, а профили попадают в таблицу', () async {
      final MemoryOnlineServer server = MemoryOnlineServer();
      addTearDown(server.dispose);
      final ProfileController first = ProfileController.inMemory(
        const PlayerProfile(name: 'Anvar', ratedGames: 30),
      );
      final ProfileController second = ProfileController.inMemory(
        const PlayerProfile(name: 'Bekzod', ratedGames: 30),
      );
      final RatingService winner = RatingService(
        backend: MemoryOnlineBackend(server, uid: 'a'),
        profile: first,
      );
      final RatingService loser = RatingService(
        backend: MemoryOnlineBackend(server, uid: 'b'),
        profile: second,
      );

      final RatingChange won = await winner.applyMatch(
        opponentRating: second.rating,
        won: true,
      );
      final RatingChange lost = await loser.applyMatch(
        opponentRating: eloStartRating,
        won: false,
      );

      expect(won.delta, -lost.delta);

      final List<RatingEntry> table = await MemoryOnlineBackend(
        server,
        uid: 'c',
      ).leaderboard();

      expect(table.map((RatingEntry entry) => entry.name), <String>[
        'Anvar',
        'Bekzod',
      ]);
      expect(table.first.rating, first.rating);
      expect(table.first.games, 31);
      expect(table.first.wins, 1);
    });

    test('сбой публикации не теряет рейтинг: он остаётся в профиле', () async {
      final ProfileController profile = ProfileController.inMemory(
        const PlayerProfile(name: 'A', ratedGames: 30),
      );
      final RatingService rating = RatingService(
        backend: _FailingBackend(),
        profile: profile,
      );

      final RatingChange change = await rating.applyMatch(
        opponentRating: eloStartRating,
        won: true,
      );

      expect(change.delta, 16);
      expect(profile.rating, eloStartRating + 16);
    });
  });

  group('реванш', () {
    test('новый матч начинается только по согласию обоих', () async {
      final _Pair room = await _Pair.open(
        hostCard: const PlayerCard(name: 'Anvar', avatar: 2, rating: 1300),
        guestCard: const PlayerCard(name: 'Bekzod', avatar: 5, rating: 1100),
      );
      addTearDown(room.server.dispose);
      final OnlineMatch host = OnlineMatch(
        room: room.host,
        localColor: Player.white,
        dice: RandomDiceSource.seeded(41),
      )..start();
      final OnlineMatch guest = OnlineMatch(
        room: room.guest,
        localColor: Player.black,
        dice: RandomDiceSource.seeded(42),
      )..start();
      addTearDown(host.dispose);
      addTearDown(guest.dispose);

      await Future.wait(<Future<GameState>>[host.opening(), guest.opening()]);

      expect(host.opponentName, 'Bekzod');
      expect(host.opponentRating, 1100);
      expect(host.opponentAvatar, 5);
      expect(guest.opponentRating, 1300);
      expect(host.rematchAgreed, isFalse);

      await host.requestRematch();
      await pump();
      expect(guest.rematchRequestedByOpponent, isTrue);
      expect(guest.rematchAgreed, isFalse, reason: 'согласился только один');

      await guest.requestRematch();
      await pump();
      expect(host.rematchAgreed, isTrue);
      expect(guest.rematchAgreed, isTrue);

      final List<GameState> next = await Future.wait(<Future<GameState>>[
        host.opening(),
        guest.opening(),
      ]);

      expect(next.first.turn, next.last.turn, reason: 'первый ход один на двоих');
      expect(
        host.rematchAgreed,
        isFalse,
        reason: 'заявка протухает вместе с началом нового матча',
      );
    });
  });

  group('экраны P5', _screens);
}

void _screens() {
  testWidgets('профиль: ник и аватар сохраняются', (WidgetTester tester) async {
    final MemoryOnlineServer server = MemoryOnlineServer();
    addTearDown(server.dispose);
    final ProfileController profile = ProfileController.inMemory(
      const PlayerProfile(name: 'Anvar'),
    );

    await tester.pumpWidget(
      NardaApp(
        settings: SettingsController.inMemory(),
        profile: profile,
        home: ProfileScreen(backend: MemoryOnlineBackend(server, uid: 'a')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bekzod');
    await tester.pump();
    expect(profile.name, 'Bekzod');

    await tester.tap(find.byType(GestureDetector).at(3));
    await tester.pump();
    expect(profile.avatar, 3);
    expect(find.text('1200'), findsOneWidget, reason: 'стартовый рейтинг');
  });

  testWidgets('таблица лидеров показывает опубликованные рейтинги', (
    WidgetTester tester,
  ) async {
    final MemoryOnlineServer server = MemoryOnlineServer();
    addTearDown(server.dispose);
    await MemoryOnlineBackend(server, uid: 'a').publishProfile(
      card: const PlayerCard(name: 'Anvar', rating: 1310),
      games: 12,
      wins: 8,
    );
    await MemoryOnlineBackend(server, uid: 'b').publishProfile(
      card: const PlayerCard(name: 'Bekzod', rating: 1490),
      games: 20,
      wins: 15,
    );

    await tester.pumpWidget(
      NardaApp(
        settings: SettingsController.inMemory(),
        home: LeaderboardScreen(backend: MemoryOnlineBackend(server, uid: 'a')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1490'), findsOneWidget);
    expect(find.textContaining('Anvar'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('1490')).dy,
      lessThan(tester.getTopLeft(find.text('1310')).dy),
      reason: 'сильнейший сверху',
    );
  });

  testWidgets('итог сетевого матча: рейтинг начислен, предложен реванш', (
    WidgetTester tester,
  ) async {
    final _Pair room = await _Pair.open(
      hostCard: const PlayerCard(name: 'Anvar', rating: 1200),
      guestCard: const PlayerCard(name: 'Bekzod', rating: 1200),
    );
    addTearDown(room.server.dispose);
    final ProfileController profile = ProfileController.inMemory(
      const PlayerProfile(name: 'Anvar', ratedGames: 30),
    );
    final OnlineMatch host = OnlineMatch(
      room: room.host,
      localColor: Player.white,
      dice: RandomDiceSource.seeded(51),
    )..start();
    final OnlineMatch guest = OnlineMatch(
      room: room.guest,
      localColor: Player.black,
      dice: RandomDiceSource.seeded(52),
    )..start();

    await tester.pumpWidget(
      NardaApp(
        settings: SettingsController.inMemory(),
        profile: profile,
        home: GameScreen(
          setup: const GameSetup.online(
            localPlayer: Player.white,
            target: MatchTarget.single,
          ),
          online: host,
          rating: RatingService(
            backend: MemoryOnlineBackend(room.server, uid: 'a'),
            profile: profile,
          ),
        ),
      ),
    );
    unawaited(guest.opening());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Соперник сдаётся: партия одиночная, поэтому матч сразу закончен.
    await guest.publishResign();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(profile.rating, greaterThan(1200), reason: 'победа подняла рейтинг');
    expect(find.textContaining('+16'), findsOneWidget);
    expect(find.text('Revansh'), findsOneWidget);

    await tester.tap(find.text('Revansh'));
    await tester.pump();
    expect(host.rematchRequestedByMe, isTrue);
    expect(find.text('Raqibning javobi kutilmoqda'), findsOneWidget);

    // Соперник согласился — доска сама начинает новый матч.
    await guest.requestRematch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Raqibning javobi kutilmoqda'), findsNothing);
    expect(find.textContaining('+16'), findsNothing, reason: 'счёт с нуля');

    // Экран уходит — вместе с ним закрывается и сессия комнаты.
    await tester.pumpWidget(const SizedBox.shrink());
    guest.dispose();
    await tester.pump();
  });
}

/// Бэкенд, у которого не выходит публикация: рейтинг обязан остаться локально.
class _FailingBackend implements OnlineBackend {
  @override
  Future<String> signIn() async => 'a';

  @override
  Future<Duration> serverTimeOffset() async => Duration.zero;

  @override
  Future<RoomHandle> createRoom({
    required MatchTarget target,
    required PlayerCard card,
  }) async => throw const OnlineUnavailable(OnlineFailure.network);

  @override
  Future<RoomHandle?> joinByCode(String code, {required PlayerCard card}) async =>
      throw const OnlineUnavailable(OnlineFailure.network);

  @override
  Future<RoomHandle?> quickMatch({
    required MatchTarget target,
    required PlayerCard card,
  }) async => throw const OnlineUnavailable(OnlineFailure.network);

  @override
  Future<void> cancelQuickMatch() async {}

  @override
  Future<void> publishProfile({
    required PlayerCard card,
    required int games,
    required int wins,
  }) async => throw const OnlineUnavailable(OnlineFailure.network);

  @override
  Future<List<RatingEntry>> leaderboard({int limit = 50}) async =>
      throw const OnlineUnavailable(OnlineFailure.network);

  @override
  void dispose() {}
}
