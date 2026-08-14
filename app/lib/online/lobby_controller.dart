import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';

import '../game/game_setup.dart';
import '../profile/profile.dart';
import 'online_backend.dart';
import 'online_match.dart';
import 'protocol.dart';
import 'rating_service.dart';

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

/// Готовая сетевая партия: сессия комнаты, настройка доски под неё и
/// пересчёт рейтинга по итогу матча (§P5).
class OnlineSession {
  const OnlineSession({
    required this.match,
    required this.setup,
    required this.rating,
  });

  final OnlineMatch match;
  final GameSetup setup;
  final RatingService rating;
}

/// Вход в онлайн: приватная комната по коду и быстрый матч (§6).
class LobbyController extends ChangeNotifier {
  LobbyController({
    required OnlineBackend backend,
    required ProfileController profile,
    this.botOfferDelay = const Duration(seconds: 15),
  }) : _backend = backend,
       _profile = profile,
       _rating = RatingService(backend: backend, profile: profile);

  /// Через сколько честно предложить сыграть с ботом, пока идёт поиск (§6).
  final Duration botOfferDelay;

  final OnlineBackend _backend;
  final ProfileController _profile;
  final RatingService _rating;

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
    _enter(LobbyStage.connecting);
    await _signIn();
    final RoomHandle room = await _backend.createRoom(
      target: target,
      card: _card,
    );
    _code = room.snapshot.meta?.code;
    _enter(LobbyStage.waitingForOpponent);
    await _openWhenFull(room);
  });

  /// Вход в чужую приватную комнату по 6-значному коду.
  /// Формат матча берётся из комнаты — его выбрал хозяин.
  Future<void> joinByCode(String code) => _run(() async {
    _enter(LobbyStage.connecting);
    await _signIn();
    final RoomHandle? room = await _backend.joinByCode(code, card: _card);
    if (room == null) throw const OnlineUnavailable(OnlineFailure.roomNotFound);
    _code = code;
    await _openWhenFull(room);
  });

  /// Быстрый матч через очередь.
  Future<void> quickMatch(MatchTarget target) => _run(() async {
    _botOffer = false;
    _enter(LobbyStage.searching);
    _botOfferTimer = Timer(botOfferDelay, () {
      if (_stage != LobbyStage.searching) return;
      _botOffer = true;
      _notify();
    });
    await _signIn();
    final RoomHandle? room = await _backend.quickMatch(
      target: target,
      card: _card,
    );
    _botOfferTimer?.cancel();
    if (room == null) {
      _enter(LobbyStage.idle);
      return;
    }
    await _openWhenFull(room);
  });

  /// Отмена ожидания: очередь освобождается, комната покидается.
  Future<void> cancel() async {
    _cancelled = true;
    _botOfferTimer?.cancel();
    await _stopWatching();
    await _backend.cancelQuickMatch();
    await _room?.leave();
    _room = null;
    _code = null;
    _botOffer = false;
    // Готовую сессию отмена не отбирает: партию уже открывает экран.
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
      await _stopWatching();
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
      rating: _rating,
      setup: GameSetup.online(
        localPlayer: color,
        target: snapshot.meta?.matchTarget ?? MatchTarget.single,
        opponentName: snapshot.opponentOf(room.uid)?.name,
      ),
    );
    _room = null;
    _enter(LobbyStage.ready);
  }

  /// Смена состояния лобби — единственное, о чём экран узнаёт от него.
  void _enter(LobbyStage stage) {
    _stage = stage;
    _notify();
  }

  Future<void> _stopWatching() async {
    await _watch?.cancel();
    _watch = null;
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
    _enter(LobbyStage.failed);
  }

  /// Как игрок представится сопернику: ник, аватар и рейтинг из профиля (§P5).
  PlayerCard get _card => PlayerCard(
    name: _profile.name,
    avatar: _profile.avatar,
    rating: _profile.rating,
  );

  /// Вход. Заодно обновляет строку в таблице лидеров — игрок появляется в ней
  /// сразу, не дожидаясь первого матча.
  Future<void> _signIn() async {
    await _backend.signIn();
    unawaited(_rating.publish());
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
