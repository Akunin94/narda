import 'package:narda_core/narda_core.dart';

import 'protocol.dart';

/// Транспорт онлайна (§6): вход, комнаты, очередь быстрого матча и запись
/// узлов. Правил игры этот слой не знает — их проверяет `OnlineMatch`
/// через `narda_core`.
abstract interface class OnlineBackend {
  /// Анонимная авторизация; возвращает uid.
  Future<String> signIn();

  /// Поправка часов устройства к серверным (`.info/serverTimeOffset`).
  /// По ней считаются дедлайны ходов и клейм победы (§6).
  Future<Duration> serverTimeOffset();

  /// Создаёт приватную комнату и входит в неё хозяином.
  Future<RoomHandle> createRoom({
    required MatchTarget target,
    required PlayerCard card,
  });

  /// Вход по 6-значному коду; `null` — комнаты нет или она уже занята.
  Future<RoomHandle?> joinByCode(String code, {required PlayerCard card});

  /// Быстрый матч: спаривание транзакцией с первым ожидающим.
  /// `null` — поиск отменён через [cancelQuickMatch].
  Future<RoomHandle?> quickMatch({
    required MatchTarget target,
    required PlayerCard card,
  });

  /// Снимает игрока с очереди быстрого матча.
  Future<void> cancelQuickMatch();

  /// Публикует профиль и рейтинг в общий список `users/{uid}` (§P5).
  /// uid записи задаёт сам бэкенд — чужую строку переписать нельзя.
  Future<void> publishProfile({
    required PlayerCard card,
    required int games,
    required int wins,
  });

  /// Верхушка таблицы лидеров, от большего рейтинга к меньшему (§P5).
  Future<List<RatingEntry>> leaderboard({int limit});

  void dispose();
}

/// Открытая комната: поток снимков и запись узлов.
abstract interface class RoomHandle {
  String get roomId;

  /// uid этого устройства.
  String get uid;

  /// Последний известный снимок комнаты.
  RoomSnapshot get snapshot;

  Stream<RoomSnapshot> get snapshots;

  /// Многопутевая запись: ключи — пути внутри комнаты через `/`,
  /// значение `null` удаляет узел, [serverTimestamp] — серверное время.
  Future<void> update(Map<String, Object?> values);

  /// Отмечает присутствие. При обрыве связи сервер сам ставит `false` (§6).
  Future<void> keepPresence();

  /// Выход из комнаты: соперник увидит отсутствие.
  Future<void> leave();
}

/// Онлайн недоступен: нет конфигурации, сети или прав.
class OnlineUnavailable implements Exception {
  const OnlineUnavailable(this.reason);

  /// Ключ строки в ARB — сообщение показывается на языке интерфейса.
  final OnlineFailure reason;

  @override
  String toString() => 'OnlineUnavailable(${reason.name})';
}

enum OnlineFailure {
  /// Firebase не настроен: не переданы `--dart-define` (см. README).
  notConfigured,

  /// Сеть или бэкенд отказали.
  network,

  /// Комнаты с таким кодом нет.
  roomNotFound,

  /// В комнате уже двое.
  roomFull,
}
