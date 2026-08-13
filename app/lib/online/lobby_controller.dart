import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import '../game/game_setup.dart';
import 'online_backend.dart';
import 'online_match.dart';
import 'protocol.dart';

/// Что сейчас делает лобби.
enum LobbyStage {
  /// Ничего: выбран режим входа.
  idle,

  /// Анонимный вход и создание комнаты.
  connecting,

  /// Комната создана, код показан — ждём второго игрока.
  waitingForOpponent,

  /// Ищем соперника в очереди быстрого матча.
  searching,

  /// Соперник найден — партию можно открывать.
  ready,

  /// Не вышло: нет настроек, нет сети, нет комнаты.
  failed,
}

/// Готовая сетевая партия: сессия комнаты и настройка доски под неё.
class OnlineSession {
  const OnlineSession({required this.match, required this.setup});

  final OnlineMatch match;
  final GameSetup setup;
}

/// Вход в онлайн: приватная комната по коду и быстрый матч (§6).
class LobbyController extends ChangeNotifier {
  LobbyController({
    required OnlineBackend backend,
    this.botOfferDelay = const Duration(seconds: 15),
  }) : _backend = backend;

  /// Через сколько честно предложить сыграть с ботом, пока идёт поиск (§6).
  final Duration botOfferDelay;

  final OnlineBackend _backend;

  LobbyStage _stage = LobbyStage.idle;
  OnlineFailure? _failure;
  OnlineSession? _session;
  RoomHandle? _room;
  String? _code;
  bool _botOffer = false;
  bool _cancelled = false;
  bool _disposed = false;
  Timer? _botOfferTimer;
  StreamSubscription<RoomSnapshot>? _watch;

  LobbyStage get stage => _stage;

  OnlineFailure? get failure => _failure;

  OnlineSession? get session => _session;

  /// Код созданной приватной комнаты — его диктуют сопернику.
  String? get code => _code;

  /// Очередь пуста дольше [botOfferDelay]: предлагаем бота, не подсовывая
  /// его за живого игрока (§6).
  bool get botOfferVisible => _botOffer;

  bool get isBusy =>
      _stage == LobbyStage.connecting ||
      _stage == LobbyStage.waitingForOpponent ||
      _stage == LobbyStage.searching;

  /// Создаёт приватную комнату и ждёт соперника по коду.
  Future<void> createRoom(MatchTarget target) => _run(() async {
    _stage = LobbyStage.connecting;
    _notify();
    final String uid = await _backend.signIn();
    final RoomHandle room = await _backend.createRoom(
      target: target,
      name: _nameFor(uid),
    );
    _code = room.snapshot.meta?.code;
    _stage = LobbyStage.waitingForOpponent;
    _notify();
    await _openWhenFull(room);
  });

  /// Вход в чужую приватную комнату по 6-значному коду.
  /// Формат матча берётся из комнаты — его выбрал хозяин.
  Future<void> joinByCode(String code) => _run(() async {
    _stage = LobbyStage.connecting;
    _notify();
    final String uid = await _backend.signIn();
    final RoomHandle? room = await _backend.joinByCode(code, name: _nameFor(uid));
    if (room == null) throw const OnlineUnavailable(OnlineFailure.roomNotFound);
    _code = code;
    await _openWhenFull(room);
  });

  /// Быстрый матч через очередь.
  Future<void> quickMatch(MatchTarget target) => _run(() async {
    _stage = LobbyStage.searching;
    _botOffer = false;
    _notify();
    _botOfferTimer = Timer(botOfferDelay, () {
      if (_stage != LobbyStage.searching) return;
      _botOffer = true;
      _notify();
    });
    final String uid = await _backend.signIn();
    final RoomHandle? room = await _backend.quickMatch(
      target: target,
      name: _nameFor(uid),
    );
    _botOfferTimer?.cancel();
    if (room == null) {
      _stage = LobbyStage.idle;
      _notify();
      return;
    }
    await _openWhenFull(room);
  });

  /// Отмена ожидания: очередь освобождается, комната покидается.
  Future<void> cancel() async {
    _cancelled = true;
    _botOfferTimer?.cancel();
    await _watch?.cancel();
    _watch = null;
    await _backend.cancelQuickMatch();
    await _room?.leave();
    _room = null;
    _code = null;
    _botOffer = false;
    if (_stage != LobbyStage.ready) _stage = LobbyStage.idle;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _botOfferTimer?.cancel();
    unawaited(_watch?.cancel());
    _backend.dispose();
    super.dispose();
  }

  /// Ждёт второго игрока и собирает сессию.
  Future<void> _openWhenFull(RoomHandle room) async {
    _room = room;
    if (!room.snapshot.isFull) {
      final Completer<void> full = Completer<void>();
      _watch = room.snapshots.listen((RoomSnapshot snapshot) {
        if (snapshot.isFull && !full.isCompleted) full.complete();
      });
      await full.future;
      await _watch?.cancel();
      _watch = null;
    }
    if (_cancelled || _disposed) return;

    final RoomSnapshot snapshot = room.snapshot;
    final Player color = snapshot.players[room.uid]?.color ?? Player.white;
    final OnlineMatch match = OnlineMatch(
      room: room,
      localColor: color,
      serverOffset: await _backend.serverTimeOffset(),
    )..start();

    _session = OnlineSession(
      match: match,
      setup: GameSetup.online(
        localPlayer: color,
        target: snapshot.meta?.matchTarget ?? MatchTarget.single,
        opponentName: snapshot.opponentOf(room.uid)?.name,
      ),
    );
    _room = null;
    _stage = LobbyStage.ready;
    _notify();
  }

  Future<void> _run(Future<void> Function() body) async {
    _cancelled = false;
    _failure = null;
    try {
      await body();
    } on OnlineUnavailable catch (error) {
      _fail(error.reason);
    } on Object {
      _fail(OnlineFailure.network);
    }
  }

  void _fail(OnlineFailure reason) {
    _botOfferTimer?.cancel();
    _failure = reason;
    _stage = LobbyStage.failed;
    _notify();
  }

  /// Профилей в P4 ещё нет (они в P5) — имя собирается из хвоста uid.
  String _nameFor(String uid) =>
      'O\'yinchi ${uid.length <= 4 ? uid : uid.substring(uid.length - 4)}';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
