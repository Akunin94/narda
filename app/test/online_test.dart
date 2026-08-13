import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/app.dart';
import 'package:narda/game/game_setup.dart';
import 'package:narda/game/match_controller.dart';
import 'package:narda/game/settings.dart';
import 'package:narda/game/turn_coordinator.dart';
import 'package:narda/online/lobby_controller.dart';
import 'package:narda/online/memory_backend.dart';
import 'package:narda/online/online_backend.dart';
import 'package:narda/online/online_match.dart';
import 'package:narda/online/online_opponent.dart';
import 'package:narda/online/protocol.dart';
import 'package:narda/ui/online/online_screen.dart';
import 'package:narda_core/narda_core.dart';

import 'support/match_helpers.dart';

/// Даёт событиям комнаты и шагам контроллеров дойти до адресатов.
Future<void> pump([int rounds = 6]) async {
  for (int i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Два клиента в одной комнате: сервер в памяти вместо Firebase.
class TestRoom {
  TestRoom._(this.server, this.white, this.black, this.code);

  static Future<TestRoom> open({
    MatchTarget target = MatchTarget.single,
    MemoryOnlineServer? server,
  }) async {
    final MemoryOnlineServer store = server ?? MemoryOnlineServer();
    final MemoryOnlineBackend hostBackend = MemoryOnlineBackend(store, uid: 'a');
    final MemoryOnlineBackend guestBackend = MemoryOnlineBackend(store, uid: 'b');
    final RoomHandle host = await hostBackend.createRoom(
      target: target,
      name: 'A',
    );
    final String code = host.snapshot.meta!.code;
    final RoomHandle guest = (await guestBackend.joinByCode(code, name: 'B'))!;
    return TestRoom._(store, host, guest, code);
  }

  final MemoryOnlineServer server;
  final RoomHandle white;
  final RoomHandle black;
  final String code;
}

/// Пара «сессия + доска» одного из игроков.
class TestClient {
  TestClient(
    RoomHandle room, {
    required Player color,
    required MatchTarget target,
    required DiceSource dice,
    bool autoMove = true,
    Duration turnLimit = const Duration(seconds: 60),
    Duration tickInterval = const Duration(seconds: 1),
  }) : match = OnlineMatch(
         room: room,
         localColor: color,
         dice: dice,
         turnLimit: turnLimit,
         tickInterval: tickInterval,
       ) {
    match.start();
    controller = MatchController(
      setup: GameSetup.online(localPlayer: color, target: target),
      settings: SettingsController.inMemory(autoMove: autoMove),
      opponent: OnlineOpponent(match),
      coordinator: match,
      timing: const MatchTiming.instant(),
    );
  }

  final OnlineMatch match;
  late final MatchController controller;

  void dispose() => controller.dispose();
}

void main() {
  group('протокол комнаты', () {
    test('журнал ходов разбирается и картой, и списком', () {
      final Map<String, Object?> move = <String, Object?>{
        'uid': 'a',
        'dice': <int>[6, 5],
        'seq': <int>[24, 6, 24, 5],
      };
      final RoomSnapshot fromList = RoomSnapshot.fromJson('r', <String, Object?>{
        'games': <Object?>[
          <String, Object?>{
            'moves': <Object?>[move],
          },
        ],
      });
      final RoomSnapshot fromMap = RoomSnapshot.fromJson('r', <String, Object?>{
        'games': <String, Object?>{
          '0': <String, Object?>{
            'moves': <String, Object?>{'0': move},
          },
        },
      });

      expect(fromList.game(0).orderedMoves(), hasLength(1));
      expect(fromMap.game(0).orderedMoves(), hasLength(1));
      expect(fromList.game(0).moves[0]!.seq, <int>[24, 6, 24, 5]);
    });

    test('дырка в журнале обрывает его, а не собирает позицию по кускам', () {
      final RoomGame game = RoomGame(
        moves: <int, RoomMove>{
          0: const RoomMove(uid: 'a', dice: DiceRoll(6, 5), seq: <int>[24, 6]),
          2: const RoomMove(uid: 'a', dice: DiceRoll(3, 2), seq: <int>[18, 3]),
        },
      );

      expect(game.orderedMoves(), hasLength(1));
    });

    test('слепок позиции не зависит от броска', () {
      final GameState state = GameState.initial(
        first: Player.white,
        roll: const DiceRoll(6, 5),
      );

      expect(
        positionDigest(state),
        positionDigest(state.copyWith(roll: const DiceRoll(1, 2))),
      );
      expect(
        positionDigest(state),
        isNot(positionDigest(state.applyMove(
          Move.point(player: Player.white, fromAbs: 24, die: 6),
        ))),
      );
    });

    test('мусор в снимке не роняет разбор', () {
      final RoomSnapshot snapshot = RoomSnapshot.fromJson('r', <String, Object?>{
        'meta': 'not a map',
        'players': <String, Object?>{'a': 42},
        'state': <String, Object?>{'points': 7},
        'games': <String, Object?>{'x': <String, Object?>{'moves': 3}},
      });

      expect(snapshot.meta, isNull);
      expect(snapshot.players, isEmpty);
      expect(snapshot.state, isNull);
      expect(snapshot.game(0).orderedMoves(), isEmpty);
    });

    test('код комнаты — шесть цифр', () {
      expect(generateRoomCode(), matches(RegExp(r'^\d{6}$')));
    });
  });

  group('лобби', () {
    test('вход по коду сводит двоих и раздаёт цвета', () async {
      final MemoryOnlineServer server = MemoryOnlineServer();
      addTearDown(server.dispose);
      final LobbyController host = LobbyController(
        backend: MemoryOnlineBackend(server, uid: 'a'),
      );
      final LobbyController guest = LobbyController(
        backend: MemoryOnlineBackend(server, uid: 'b'),
      );
      addTearDown(host.dispose);
      addTearDown(guest.dispose);

      unawaited(host.createRoom(MatchTarget.to3));
      await pump();
      expect(host.stage, LobbyStage.waitingForOpponent);
      expect(host.code, matches(RegExp(r'^\d{6}$')));

      await guest.joinByCode(host.code!);
      await pump();

      expect(guest.stage, LobbyStage.ready);
      expect(host.stage, LobbyStage.ready);
      expect(host.session!.setup.localPlayer, Player.white);
      expect(guest.session!.setup.localPlayer, Player.black);
      expect(guest.session!.setup.target, MatchTarget.to3);

      host.session!.match.dispose();
      guest.session!.match.dispose();
    });

    test('быстрый матч спаривает первого ожидающего', () async {
      final MemoryOnlineServer server = MemoryOnlineServer();
      addTearDown(server.dispose);
      final LobbyController first = LobbyController(
        backend: MemoryOnlineBackend(server, uid: 'a'),
      );
      final LobbyController second = LobbyController(
        backend: MemoryOnlineBackend(server, uid: 'b'),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      unawaited(first.quickMatch(MatchTarget.single));
      await pump();
      expect(first.stage, LobbyStage.searching);

      await second.quickMatch(MatchTarget.single);
      await pump();

      expect(second.stage, LobbyStage.ready);
      expect(first.stage, LobbyStage.ready);
      expect(
        first.session!.setup.localPlayer,
        isNot(second.session!.setup.localPlayer),
      );

      first.session!.match.dispose();
      second.session!.match.dispose();
    });

    test('очередь пуста дольше срока — честно предлагаем бота', () async {
      final MemoryOnlineServer server = MemoryOnlineServer();
      addTearDown(server.dispose);
      final LobbyController lobby = LobbyController(
        backend: MemoryOnlineBackend(server, uid: 'a'),
        botOfferDelay: const Duration(milliseconds: 20),
      );
      addTearDown(lobby.dispose);

      unawaited(lobby.quickMatch(MatchTarget.single));
      await pump();
      expect(lobby.botOfferVisible, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(lobby.botOfferVisible, isTrue);
      expect(lobby.stage, LobbyStage.searching);

      await lobby.cancel();
      expect(lobby.stage, LobbyStage.idle);
    });

    test('нет настроек Firebase — лобби честно говорит об этом', () async {
      final LobbyController lobby = LobbyController(
        backend: _UnavailableBackend(),
      );
      addTearDown(lobby.dispose);

      await lobby.quickMatch(MatchTarget.single);

      expect(lobby.stage, LobbyStage.failed);
      expect(lobby.failure, OnlineFailure.notConfigured);
    });
  });

  group('партия по сети', () {
    test('двое доигрывают партию, позиции совпадают до конца', () async {
      final TestRoom room = await TestRoom.open();
      addTearDown(room.server.dispose);
      final TestClient white = TestClient(
        room.white,
        color: Player.white,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(11),
      );
      final TestClient black = TestClient(
        room.black,
        color: Player.black,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(12),
      );
      addTearDown(white.dispose);
      addTearDown(black.dispose);

      white.controller.start();
      black.controller.start();

      int guard = 0;
      while (!white.controller.isOver && !black.controller.isOver && guard++ < 3000) {
        await pump(3);
        if (white.controller.canInteract) playLocalTurn(white.controller);
        if (black.controller.canInteract) playLocalTurn(black.controller);
        expect(white.controller.state.validate(), isEmpty, reason: 'шаг $guard');
        expect(black.controller.state.validate(), isEmpty, reason: 'шаг $guard');
      }
      await pump();

      expect(white.controller.phase, TurnPhase.finished);
      expect(black.controller.phase, TurnPhase.finished);
      expect(
        white.controller.result!.winner,
        black.controller.result!.winner,
        reason: 'победитель один на двоих',
      );
      expect(white.controller.result!.isMars, black.controller.result!.isMars);
      expect(
        positionDigest(white.controller.state),
        positionDigest(black.controller.state),
      );
    });

    test('сдача одного заканчивает партию у обоих', () async {
      final TestRoom room = await TestRoom.open();
      addTearDown(room.server.dispose);
      final TestClient white = TestClient(
        room.white,
        color: Player.white,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(3),
      );
      final TestClient black = TestClient(
        room.black,
        color: Player.black,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(4),
      );
      addTearDown(white.dispose);
      addTearDown(black.dispose);

      white.controller.start();
      black.controller.start();
      await pump();

      white.controller.resign();
      await pump();

      expect(white.controller.result!.winner, Player.black);
      expect(black.controller.phase, TurnPhase.finished);
      expect(black.controller.result!.winner, Player.black);
      expect(black.controller.result!.byResignation, isTrue);
      expect(black.controller.result!.isMars, isTrue, reason: 'ни одной шашки');
    });

    test('нелегальный ход соперника аннулирует партию', () async {
      final TestRoom room = await TestRoom.open();
      addTearDown(room.server.dispose);
      final OnlineMatch host = OnlineMatch(
        room: room.white,
        localColor: Player.white,
        dice: ScriptedDiceSource(<int>[6], <DiceRoll>[const DiceRoll(6, 5)]),
      )..start();
      final OnlineMatch guest = OnlineMatch(
        room: room.black,
        localColor: Player.black,
        dice: ScriptedDiceSource(<int>[3], <DiceRoll>[const DiceRoll(1, 1)]),
      )..start();
      addTearDown(host.dispose);
      addTearDown(guest.dispose);

      final List<GameState> opened = await Future.wait(<Future<GameState>>[
        host.opening(),
        guest.opening(),
      ]);
      expect(opened.first.turn, Player.white, reason: '6 против 3');

      final DiceRoll roll = await host.roll(opened.first);
      final GameState guestTurn = opened.last.copyWith(
        roll: roll,
        remainingDice: roll.toRemaining(),
      );
      expect(await guest.roll(opened.last), roll);

      final Future<MatchSignal> signal = guest.signals.first;
      // Шашка «улетает» с пустого пункта: правилами такой ход не порождается.
      await room.white.update(<String, Object?>{
        'games/0/moves/0': const RoomMove(
          uid: 'a',
          dice: DiceRoll(6, 5),
          seq: <int>[7, 6, 7, 5],
        ).toJson(),
      });
      unawaited(guest.awaitOpponentMove(guestTurn));

      expect(await signal, isA<AbortSignal>());
      expect(
        (await signal as AbortSignal).reason,
        MatchAbortReason.desync,
      );
    });

    test('реконнект восстанавливает позицию реплеем журнала', () async {
      final TestRoom room = await TestRoom.open();
      addTearDown(room.server.dispose);
      final TestClient white = TestClient(
        room.white,
        color: Player.white,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(21),
      );
      final TestClient black = TestClient(
        room.black,
        color: Player.black,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(22),
      );
      addTearDown(white.dispose);
      addTearDown(black.dispose);

      white.controller.start();
      black.controller.start();

      for (int step = 0; step < 60; step++) {
        await pump(3);
        if (white.controller.canInteract) playLocalTurn(white.controller);
        if (black.controller.canInteract) playLocalTurn(black.controller);
      }
      await pump();
      final int moves = room.white.snapshot.game(0).orderedMoves().length;
      expect(moves, greaterThan(2), reason: 'партия успела пойти');

      // Новое подключение того же игрока — журнал тот же, состояние тоже.
      final MemoryOnlineBackend again = MemoryOnlineBackend(
        room.server,
        uid: 'b',
      );
      final RoomHandle rejoined = (await again.joinByCode(room.code, name: 'B'))!;
      final OnlineMatch restored = OnlineMatch(
        room: rejoined,
        localColor: Player.black,
        dice: RandomDiceSource.seeded(23),
      )..start();
      addTearDown(restored.dispose);

      final GameState state = await restored.opening();

      expect(
        positionDigest(state),
        positionDigest(black.controller.state),
        reason: 'реплей журнала повторяет позицию доски',
      );
    });

    test('просроченный ход пасуется автоматически', () async {
      final TestRoom room = await TestRoom.open();
      addTearDown(room.server.dispose);
      final TestClient white = TestClient(
        room.white,
        color: Player.white,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(31),
        autoMove: false,
        turnLimit: const Duration(milliseconds: 5),
        tickInterval: const Duration(milliseconds: 20),
      );
      final TestClient black = TestClient(
        room.black,
        color: Player.black,
        target: MatchTarget.single,
        dice: RandomDiceSource.seeded(32),
        autoMove: false,
        turnLimit: const Duration(milliseconds: 5),
        tickInterval: const Duration(milliseconds: 20),
      );
      addTearDown(white.dispose);
      addTearDown(black.dispose);

      white.controller.start();
      black.controller.start();

      // Никто не ходит: каждый ход просрачивается, второй подряд — поражение.
      int guard = 0;
      while (room.white.snapshot.outcome == null && guard++ < 200) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await pump(2);
      }

      final List<RoomMove> log = room.white.snapshot.game(0).orderedMoves();
      expect(log, isNotEmpty, reason: 'автопас попал в журнал');
      expect(log.first.seq, isEmpty, reason: 'просроченный ход — пустой');
      expect(room.white.snapshot.outcome?.reason, OutcomeReason.timeout);
      await pump();
      expect(white.controller.phase, TurnPhase.finished);
      expect(black.controller.phase, TurnPhase.finished);
      expect(
        white.controller.result!.winner,
        black.controller.result!.winner,
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('экраны онлайна', _screens);
}

/// Экраны онлайна на комнатах в памяти.
void _screens() {
  testWidgets('лобби показывает код созданной комнаты', (
    WidgetTester tester,
  ) async {
    final MemoryOnlineServer server = MemoryOnlineServer();
    addTearDown(server.dispose);

    await tester.pumpWidget(
      NardaApp(
        settings: SettingsController.inMemory(),
        home: OnlineScreen(backend: MemoryOnlineBackend(server, uid: 'a')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tez o\'yin'), findsOneWidget);
    expect(find.text('Xona yaratish'), findsOneWidget);

    await tester.tap(find.text('Xona yaratish'));
    // Не pumpAndSettle: экран ожидания крутит бесконечный индикатор.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Raqib kutilmoqda'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SelectableText &&
            RegExp(r'^\d{6}$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
      reason: 'шестизначный код на экране',
    );
  });

  testWidgets('главное меню ведёт в онлайн', (WidgetTester tester) async {
    await tester.pumpWidget(NardaApp(settings: SettingsController.inMemory()));
    await tester.pumpAndSettle();

    expect(find.text('Onlayn o\'ynash'), findsOneWidget);
  });
}

/// Бэкенд без настроек Firebase — как на устройстве до `--dart-define`.
class _UnavailableBackend implements OnlineBackend {
  @override
  Future<String> signIn() async =>
      throw const OnlineUnavailable(OnlineFailure.notConfigured);

  @override
  Future<Duration> serverTimeOffset() async => Duration.zero;

  @override
  Future<RoomHandle> createRoom({
    required MatchTarget target,
    required String name,
  }) => signIn().then((_) => throw StateError('unreachable'));

  @override
  Future<RoomHandle?> joinByCode(String code, {required String name}) =>
      signIn().then((_) => null);

  @override
  Future<RoomHandle?> quickMatch({
    required MatchTarget target,
    required String name,
  }) => signIn().then((_) => null);

  @override
  Future<void> cancelQuickMatch() async {}

  @override
  void dispose() {}
}
