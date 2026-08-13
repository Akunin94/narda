/// Схема комнаты и её разбор (§6).
///
/// Формат узлов повторяет спеку:
/// ```
/// rooms/{roomId}/
///   meta:     {createdAt, matchTarget, status, code, hostUid}
///   players:  {uid: {name, color}}
///   state:    {points, turnUid, dice, remainingDice, whiteOff, blackOff,
///              moveIndex, gameIndex, deadline}
///   games/{gameIndex}/opening/{attempt}/{uid}: <кубик>
///   games/{gameIndex}/moves/{index}: {uid, dice, seq, ts}
///   outcome:  {winnerUid, reason, gameIndex}
///   presence/{uid}: bool
///   chat/{uid}: {phrase, ts}
///   rematch/{uid}: <номер партии, с которой игрок готов играть новый матч>
/// ```
/// Отличие от §6 одно: журнал ходов лежит внутри `games/{gameIndex}`, потому
/// что комната играет серию до 3 / 5 / 7 очков (§3.4), а не одну партию.
/// Розыгрыш первого хода тоже сетевой: каждый пишет свой кубик сам (§3.2.1).
///
/// Рядом с комнатами лежит таблица лидеров (§P5):
/// ```
/// users/{uid}: {name, avatar, rating, games, wins, updatedAt}
/// ```
library;

import 'dart:math';

import 'package:narda_core/narda_core.dart';

import '../profile/elo.dart';

/// Метка «поставь серверное время»; бэкенд подменяет её при записи.
class ServerTimestamp {
  const ServerTimestamp();
}

const ServerTimestamp serverTimestamp = ServerTimestamp();

/// Состояние комнаты.
enum RoomStatus { waiting, playing, finished }

/// Почему партия закончилась не выбросом шашек.
enum OutcomeReason { resign, timeout, disconnect, desync }

/// Как игрок представляется в комнате и в таблице лидеров: ник, аватар и
/// рейтинг на момент входа (§P5).
class PlayerCard {
  const PlayerCard({
    required this.name,
    this.avatar = 0,
    this.rating = eloStartRating,
  });

  final String name;
  final int avatar;
  final int rating;
}

/// Игрок комнаты.
class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.name,
    required this.color,
    this.avatar = 0,
    this.rating = eloStartRating,
  });

  RoomPlayer.fromCard({
    required this.uid,
    required this.color,
    required PlayerCard card,
  }) : name = card.name,
       avatar = card.avatar,
       rating = card.rating;

  final String uid;
  final String name;
  final Player color;

  /// Номер аватара из набора.
  final int avatar;

  /// Рейтинг на момент входа в комнату: по нему обе стороны считают Elo
  /// после матча и получают одинаковый результат (§P5).
  final int rating;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'color': color.code,
    'avatar': avatar,
    'rating': rating,
  };

  static RoomPlayer? fromJson(String uid, Object? json) {
    if (json is! Map) return null;
    final Object? code = json['color'];
    if (code is! String) return null;
    return RoomPlayer(
      uid: uid,
      name: json['name'] is String ? json['name'] as String : '',
      color: Player.fromCode(code),
      avatar: asInt(json['avatar']) ?? 0,
      rating: asInt(json['rating']) ?? eloStartRating,
    );
  }
}

/// Строка таблицы лидеров — она же публичная запись профиля `users/{uid}`.
class RatingEntry {
  const RatingEntry({
    required this.uid,
    required this.name,
    this.avatar = 0,
    this.rating = eloStartRating,
    this.games = 0,
    this.wins = 0,
  });

  final String uid;
  final String name;
  final int avatar;
  final int rating;
  final int games;
  final int wins;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'avatar': avatar,
    'rating': rating,
    'games': games,
    'wins': wins,
    'updatedAt': serverTimestamp,
  };

  static RatingEntry? fromJson(String uid, Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    return RatingEntry(
      uid: uid,
      name: json['name'] as String,
      avatar: asInt(json['avatar']) ?? 0,
      rating: asInt(json['rating']) ?? eloStartRating,
      games: asInt(json['games']) ?? 0,
      wins: asInt(json['wins']) ?? 0,
    );
  }
}

/// Разбирает узел `users` и раскладывает по убыванию рейтинга.
List<RatingEntry> ratingTable(Object? json, {int limit = 50}) {
  final List<RatingEntry> entries = <RatingEntry>[];
  childrenOf(json).forEach((String uid, Object? value) {
    final RatingEntry? entry = RatingEntry.fromJson(uid, value);
    if (entry != null) entries.add(entry);
  });
  entries.sort((RatingEntry a, RatingEntry b) {
    final int byRating = b.rating.compareTo(a.rating);
    return byRating != 0 ? byRating : a.name.compareTo(b.name);
  });
  return entries.length > limit ? entries.sublist(0, limit) : entries;
}

/// Шапка комнаты.
class RoomMeta {
  const RoomMeta({
    required this.code,
    required this.matchTarget,
    required this.status,
    required this.hostUid,
    this.createdAt = 0,
  });

  final String code;
  final MatchTarget matchTarget;
  final RoomStatus status;
  final String hostUid;
  final int createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'matchTarget': matchTarget.points,
    'status': status.name,
    'hostUid': hostUid,
    'createdAt': createdAt,
  };

  static RoomMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    return RoomMeta(
      code: json['code'] is String ? json['code'] as String : '',
      matchTarget: matchTargetFromPoints(asInt(json['matchTarget']) ?? 1),
      status: RoomStatus.values.firstWhere(
        (RoomStatus value) => value.name == json['status'],
        orElse: () => RoomStatus.waiting,
      ),
      hostUid: json['hostUid'] is String ? json['hostUid'] as String : '',
      createdAt: asInt(json['createdAt']) ?? 0,
    );
  }
}

/// Слепок позиции: по нему клиенты сверяются, а UI узнаёт очередь и дедлайн.
class RoomState {
  const RoomState({
    required this.points,
    required this.turnUid,
    required this.moveIndex,
    required this.gameIndex,
    this.dice,
    this.deadline = 0,
  });

  /// [GameState.encode] после последнего сыгранного хода — «хеш состояния».
  final String points;

  /// Кто ходит: только этот uid имеет право писать ходы (§6).
  final String turnUid;

  /// Опубликованный бросок текущего хода; `null` — активный игрок ещё не бросил.
  final DiceRoll? dice;

  /// Номер очередного хода в журнале партии.
  final int moveIndex;

  /// Номер партии в серии.
  final int gameIndex;

  /// Дедлайн хода по серверному времени (§6: 60 секунд).
  final int deadline;

  Map<String, Object?> toJson() {
    final GameState? decoded = tryDecodeState(points);
    return <String, Object?>{
      'points': points,
      'turnUid': turnUid,
      'dice': dice == null ? null : <int>[dice!.a, dice!.b],
      'remainingDice': dice?.toRemaining(),
      'whiteOff': decoded?.whiteBorneOff ?? 0,
      'blackOff': decoded?.blackBorneOff ?? 0,
      'moveIndex': moveIndex,
      'gameIndex': gameIndex,
      'deadline': deadline,
    };
  }

  static RoomState? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? points = json['points'];
    final Object? turnUid = json['turnUid'];
    if (points is! String || turnUid is! String) return null;
    return RoomState(
      points: points,
      turnUid: turnUid,
      dice: diceFromJson(json['dice']),
      moveIndex: asInt(json['moveIndex']) ?? 0,
      gameIndex: asInt(json['gameIndex']) ?? 0,
      deadline: asInt(json['deadline']) ?? 0,
    );
  }
}

/// Запись хода в журнале.
class RoomMove {
  const RoomMove({required this.uid, required this.dice, required this.seq});

  final String uid;
  final DiceRoll dice;

  /// Плоский список пар `fromAbs, die`; пустой — пропуск хода.
  final List<int> seq;

  LoggedTurn toLoggedTurn() => LoggedTurn(roll: dice, moves: seq);

  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'dice': <int>[dice.a, dice.b],
    'seq': seq,
    'ts': serverTimestamp,
  };

  static RoomMove? fromJson(Object? json) {
    if (json is! Map) return null;
    final DiceRoll? dice = diceFromJson(json['dice']);
    if (dice == null || json['uid'] is! String) return null;
    return RoomMove(
      uid: json['uid'] as String,
      dice: dice,
      seq: intList(json['seq']),
    );
  }
}

/// Досрочный итог партии: сдача, тайм-аут, разрыв связи, расхождение состояний.
class RoomOutcome {
  const RoomOutcome({
    required this.winnerUid,
    required this.reason,
    required this.gameIndex,
  });

  final String winnerUid;
  final OutcomeReason reason;
  final int gameIndex;

  Map<String, Object?> toJson() => <String, Object?>{
    'winnerUid': winnerUid,
    'reason': reason.name,
    'gameIndex': gameIndex,
  };

  static RoomOutcome? fromJson(Object? json) {
    if (json is! Map || json['winnerUid'] is! String) return null;
    return RoomOutcome(
      winnerUid: json['winnerUid'] as String,
      reason: OutcomeReason.values.firstWhere(
        (OutcomeReason value) => value.name == json['reason'],
        orElse: () => OutcomeReason.resign,
      ),
      gameIndex: asInt(json['gameIndex']) ?? 0,
    );
  }
}

/// Одна партия серии: розыгрыш первого хода и журнал ходов.
class RoomGame {
  const RoomGame({
    this.opening = const <int, Map<String, int>>{},
    this.moves = const <int, RoomMove>{},
  });

  /// Розыгрыш первого хода: попытка -> uid -> кубик (§3.2.1).
  final Map<int, Map<String, int>> opening;

  /// Журнал ходов: индекс -> ход.
  final Map<int, RoomMove> moves;

  /// Журнал по порядку. Дырка в индексах обрывает список: хвост после неё
  /// ещё не доехал, а собирать позицию по кускам нельзя.
  List<RoomMove> orderedMoves() {
    final List<RoomMove> result = <RoomMove>[];
    for (int index = 0; moves.containsKey(index); index++) {
      result.add(moves[index]!);
    }
    return result;
  }

  /// Кто выиграл розыгрыш первого хода; `null` — розыгрыш не закончен.
  String? firstMoverUid() {
    for (int attempt = 0; opening.containsKey(attempt); attempt++) {
      final Map<String, int> dice = opening[attempt]!;
      if (dice.length < 2) return null;
      final List<MapEntry<String, int>> rolled = dice.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value));
      if (rolled[0].value != rolled[1].value) return rolled[0].key;
    }
    return null;
  }
}

/// Комната целиком — то, что приходит клиенту одним снимком.
class RoomSnapshot {
  const RoomSnapshot({
    required this.roomId,
    this.meta,
    this.players = const <String, RoomPlayer>{},
    this.state,
    this.games = const <int, RoomGame>{},
    this.outcome,
    this.presence = const <String, bool>{},
    this.chat = const <String, String>{},
    this.rematch = const <String, int>{},
  });

  final String roomId;
  final RoomMeta? meta;
  final Map<String, RoomPlayer> players;
  final RoomState? state;

  /// Партии серии: номер -> журнал.
  final Map<int, RoomGame> games;

  final RoomOutcome? outcome;
  final Map<String, bool> presence;

  /// Последняя фраза каждого игрока.
  final Map<String, String> chat;

  /// Заявки на реванш: uid -> номер партии, с которой игрок готов начать
  /// новый матч в этой же комнате (§P5).
  final Map<String, int> rematch;

  bool get isFull => players.length >= 2;

  RoomGame game(int index) => games[index] ?? const RoomGame();

  RoomPlayer? opponentOf(String uid) {
    for (final RoomPlayer player in players.values) {
      if (player.uid != uid) return player;
    }
    return null;
  }

  /// Разбор снимка комнаты. Всё, что не разобралось, просто отсутствует —
  /// чужие данные не должны ронять клиент.
  static RoomSnapshot fromJson(String roomId, Object? json) {
    if (json is! Map) return RoomSnapshot(roomId: roomId);
    return RoomSnapshot(
      roomId: roomId,
      meta: RoomMeta.fromJson(json['meta']),
      players: _players(json['players']),
      state: RoomState.fromJson(json['state']),
      games: _games(json['games']),
      outcome: RoomOutcome.fromJson(json['outcome']),
      presence: _presence(json['presence']),
      chat: _chat(json['chat']),
      rematch: _rematch(json['rematch']),
    );
  }

  static Map<String, int> _rematch(Object? json) {
    final Map<String, int> result = <String, int>{};
    childrenOf(json).forEach((String uid, Object? value) {
      final int? index = asInt(value);
      if (index != null) result[uid] = index;
    });
    return result;
  }

  static Map<int, RoomGame> _games(Object? json) {
    final Map<int, RoomGame> result = <int, RoomGame>{};
    childrenOf(json).forEach((String index, Object? value) {
      final int? key = asInt(index);
      if (key == null) return;
      result[key] = RoomGame(
        opening: _opening(childOf(value, 'opening')),
        moves: _moves(childOf(value, 'moves')),
      );
    });
    return result;
  }

  static Map<String, RoomPlayer> _players(Object? json) {
    final Map<String, RoomPlayer> result = <String, RoomPlayer>{};
    childrenOf(json).forEach((String uid, Object? value) {
      final RoomPlayer? player = RoomPlayer.fromJson(uid, value);
      if (player != null) result[uid] = player;
    });
    return result;
  }

  static Map<int, Map<String, int>> _opening(Object? json) {
    final Map<int, Map<String, int>> result = <int, Map<String, int>>{};
    childrenOf(json).forEach((String attempt, Object? value) {
      final int? index = asInt(attempt);
      if (index == null) return;
      final Map<String, int> dice = <String, int>{};
      childrenOf(value).forEach((String uid, Object? die) {
        final int? face = asInt(die);
        if (face != null && face >= 1 && face <= 6) dice[uid] = face;
      });
      result[index] = dice;
    });
    return result;
  }

  static Map<int, RoomMove> _moves(Object? json) {
    final Map<int, RoomMove> result = <int, RoomMove>{};
    childrenOf(json).forEach((String index, Object? value) {
      final int? key = asInt(index);
      final RoomMove? move = RoomMove.fromJson(value);
      if (key != null && move != null) result[key] = move;
    });
    return result;
  }

  static Map<String, bool> _presence(Object? json) {
    final Map<String, bool> result = <String, bool>{};
    childrenOf(json).forEach((String uid, Object? value) {
      if (value is bool) result[uid] = value;
    });
    return result;
  }

  static Map<String, String> _chat(Object? json) {
    final Map<String, String> result = <String, String>{};
    childrenOf(json).forEach((String uid, Object? value) {
      final Object? phrase = childOf(value, 'phrase');
      if (phrase is String) result[uid] = phrase;
    });
    return result;
  }
}

/// Realtime Database отдаёт узел со сплошными числовыми ключами списком,
/// а не картой — журнал ходов как раз такой. Приводим к общему виду.
Map<String, Object?> childrenOf(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in node.entries)
        '${entry.key}': entry.value,
    };
  }
  if (node is List) {
    final Map<String, Object?> result = <String, Object?>{};
    for (int index = 0; index < node.length; index++) {
      if (node[index] != null) result['$index'] = node[index];
    }
    return result;
  }
  return const <String, Object?>{};
}

Object? childOf(Object? node, String key) => childrenOf(node)[key];

/// Realtime Database отдаёт числа то `int`, то `double`, а ключи — строками.
int? asInt(Object? value) => switch (value) {
  final int value => value,
  final double value => value.round(),
  final String value => int.tryParse(value),
  _ => null,
};

List<int> intList(Object? value) => value is List
    ? <int>[
        for (final Object? item in value)
          if (asInt(item) case final int number) number,
      ]
    : const <int>[];

DiceRoll? diceFromJson(Object? value) {
  final List<int> faces = intList(value);
  if (faces.length != 2) return null;
  if (faces.any((int face) => face < 1 || face > 6)) return null;
  return DiceRoll(faces[0], faces[1]);
}

/// «Хеш состояния» из §6: то, что обязано совпадать у обоих клиентов.
///
/// Бросок и остаток костей в слепок не входят — они принадлежат ходу, а не
/// позиции, и у публикующего остаются от его собственного хода.
String positionDigest(GameState state) =>
    '${state.points.join(',')}|${state.whiteBorneOff}|${state.blackBorneOff}'
    '|${state.turn.code}|${state.turnIndex}';

GameState? tryDecodeState(String encoded) {
  try {
    return GameState.decode(encoded);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

MatchTarget matchTargetFromPoints(int points) => MatchTarget.values.firstWhere(
  (MatchTarget target) => target.points == points,
  orElse: () => MatchTarget.single,
);

/// Приватная комната открывается 6-значным кодом (§6).
String generateRoomCode([Random? random]) {
  final Random source = random ?? Random.secure();
  return List<int>.generate(6, (_) => source.nextInt(10)).join();
}

/// Общение без свободного чата: только эти фразы и эмодзи (§6).
const List<String> quickPhraseIds = <String>[
  'salom',
  'yaxshiYurish',
  'omad',
  'rahmat',
];

const List<String> quickEmoji = <String>['👍', '😄', '😮', '🎲'];
