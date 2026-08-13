import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:narda_core/narda_core.dart';

import 'firebase_config.dart';
import 'online_backend.dart';
import 'protocol.dart';

/// Онлайн на Firebase: анонимная авторизация и Realtime Database (§6).
///
/// Дополнительный узел `codes/{code}` — указатель «код -> комната»: без него
/// вход по коду требовал бы права читать список всех комнат.
class FirebaseOnlineBackend implements OnlineBackend {
  FirebaseOnlineBackend();

  FirebaseDatabase? _database;
  String? _uid;
  Completer<RoomHandle?>? _queue;
  StreamSubscription<DatabaseEvent>? _queueWatch;

  FirebaseDatabase get _db {
    final FirebaseDatabase? database = _database;
    if (database == null) {
      throw const OnlineUnavailable(OnlineFailure.notConfigured);
    }
    return database;
  }

  String get _me {
    final String? uid = _uid;
    if (uid == null) throw const OnlineUnavailable(OnlineFailure.notConfigured);
    return uid;
  }

  @override
  Future<String> signIn() async {
    if (!OnlineConfig.isConfigured) {
      throw const OnlineUnavailable(OnlineFailure.notConfigured);
    }
    final String? existing = _uid;
    if (existing != null) return existing;
    try {
      final FirebaseApp app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: OnlineConfig.options)
          : Firebase.app();
      final FirebaseAuth auth = FirebaseAuth.instanceFor(app: app);
      final User user =
          auth.currentUser ?? (await auth.signInAnonymously()).user!;
      _database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: OnlineConfig.databaseUrl,
      );
      _uid = user.uid;
      return user.uid;
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
  }

  @override
  Future<Duration> serverTimeOffset() async {
    try {
      final DataSnapshot snapshot = await _db.ref('.info/serverTimeOffset').get();
      return Duration(milliseconds: asInt(snapshot.value) ?? 0);
    } on FirebaseException {
      return Duration.zero;
    }
  }

  @override
  Future<RoomHandle> createRoom({
    required MatchTarget target,
    required PlayerCard card,
  }) async {
    await signIn();
    final DatabaseReference rooms = _db.ref('rooms');
    final String roomId = rooms.push().key!;
    final String code = generateRoomCode();
    try {
      await rooms.child(roomId).set(<String, Object?>{
        'meta': RoomMeta(
          code: code,
          matchTarget: target,
          status: RoomStatus.waiting,
          hostUid: _me,
        ).toJson()..['createdAt'] = ServerValue.timestamp,
        'players': <String, Object?>{
          _me: RoomPlayer.fromCard(
            uid: _me,
            color: Player.white,
            card: card,
          ).toJson(),
        },
        'presence': <String, Object?>{_me: true},
      });
      await _db.ref('codes/$code').set(roomId);
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
    return _FirebaseRoom(_db, roomId: roomId, uid: _me);
  }

  @override
  Future<RoomHandle?> joinByCode(String code, {required PlayerCard card}) async {
    await signIn();
    try {
      final DataSnapshot pointer = await _db.ref('codes/$code').get();
      final Object? roomId = pointer.value;
      if (roomId is! String) {
        throw const OnlineUnavailable(OnlineFailure.roomNotFound);
      }
      final DataSnapshot room = await _db.ref('rooms/$roomId').get();
      final RoomSnapshot snapshot = RoomSnapshot.fromJson(roomId, room.value);
      if (snapshot.meta == null) {
        throw const OnlineUnavailable(OnlineFailure.roomNotFound);
      }
      if (!snapshot.players.containsKey(_me)) {
        if (snapshot.isFull) {
          throw const OnlineUnavailable(OnlineFailure.roomFull);
        }
        await _db.ref('rooms/$roomId').update(<String, Object?>{
          'players/$_me': RoomPlayer.fromCard(
            uid: _me,
            color: Player.black,
            card: card,
          ).toJson(),
          'meta/status': RoomStatus.playing.name,
        });
      }
      return _FirebaseRoom(_db, roomId: roomId, uid: _me);
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
  }

  @override
  Future<RoomHandle?> quickMatch({
    required MatchTarget target,
    required PlayerCard card,
  }) async {
    await signIn();
    final Completer<RoomHandle?> completer = Completer<RoomHandle?>();
    _queue = completer;

    try {
      final RoomHandle? paired = await _claimWaiting(target: target, card: card);
      if (paired != null) {
        _queue = null;
        return paired;
      }

      // Никого не нашли — встаём в очередь сами и ждём, пока подберут нас.
      final DatabaseReference mine = _db.ref('matchmaking/$_me');
      await mine.onDisconnect().remove();
      await mine.set(<String, Object?>{'target': target.points});
      _queueWatch = _db.ref('matchmaking/$_me/roomId').onValue.listen((
        DatabaseEvent event,
      ) async {
        final Object? roomId = event.snapshot.value;
        if (roomId is! String || completer.isCompleted) return;
        await _leaveQueue();
        // Комнату собрал тот, кто подобрал: свои ник, аватар и рейтинг
        // (§P5) вписываем в готовую запись сами — цвет в ней не трогаем.
        await _db.ref('rooms/$roomId/players/$_me').update(<String, Object?>{
          'name': card.name,
          'avatar': card.avatar,
          'rating': card.rating,
        });
        await _db.ref('rooms/$roomId/presence/$_me').set(true);
        if (!completer.isCompleted) {
          completer.complete(_FirebaseRoom(_db, roomId: roomId, uid: _me));
        }
      });
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
    return completer.future;
  }

  /// Забирает первого подходящего из очереди транзакцией на его записи:
  /// двое одновременно подобрать одного и того же не смогут (§6).
  Future<RoomHandle?> _claimWaiting({
    required MatchTarget target,
    required PlayerCard card,
  }) async {
    final DataSnapshot queue = await _db.ref('matchmaking').get();
    for (final MapEntry<String, Object?> entry
        in childrenOf(queue.value).entries) {
      if (entry.key == _me) continue;
      final Map<String, Object?> waiting = childrenOf(entry.value);
      if (asInt(waiting['target']) != target.points) continue;
      if (waiting['roomId'] != null) continue;

      final String roomId = _db.ref('rooms').push().key!;
      final TransactionResult claimed = await _db
          .ref('matchmaking/${entry.key}')
          .runTransaction((Object? current) {
            final Map<String, Object?> value = childrenOf(current);
            if (value.isEmpty || value['roomId'] != null) {
              return Transaction.abort();
            }
            return Transaction.success(<String, Object?>{
              ...value,
              'roomId': roomId,
              'guestUid': _me,
            });
          });
      if (!claimed.committed) continue;

      // Комнату собирает тот, кто подобрал: он точно на связи.
      await _createPairedRoom(
        roomId: roomId,
        target: target,
        card: card,
        guestUid: entry.key,
      );
      return _FirebaseRoom(_db, roomId: roomId, uid: _me);
    }
    return null;
  }

  Future<void> _createPairedRoom({
    required String roomId,
    required MatchTarget target,
    required PlayerCard card,
    required String guestUid,
  }) async {
    final String code = generateRoomCode();
    await _db.ref('rooms/$roomId').set(<String, Object?>{
      'meta': RoomMeta(
        code: code,
        matchTarget: target,
        status: RoomStatus.playing,
        hostUid: _me,
      ).toJson()..['createdAt'] = ServerValue.timestamp,
      'players': <String, Object?>{
        _me: RoomPlayer.fromCard(
          uid: _me,
          color: Player.white,
          card: card,
        ).toJson(),
        // Ник, аватар и рейтинг гостя впишет он сам, когда увидит комнату.
        guestUid: RoomPlayer(
          uid: guestUid,
          name: '',
          color: Player.black,
        ).toJson(),
      },
      'presence': <String, Object?>{_me: true},
    });
  }

  @override
  Future<void> publishProfile({
    required PlayerCard card,
    required int games,
    required int wins,
  }) async {
    await signIn();
    try {
      await _db.ref('users/$_me').set(
        RatingEntry(
          uid: _me,
          name: card.name,
          avatar: card.avatar,
          rating: card.rating,
          games: games,
          wins: wins,
        ).toJson()..['updatedAt'] = ServerValue.timestamp,
      );
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
  }

  @override
  Future<List<RatingEntry>> leaderboard({int limit = 50}) async {
    await signIn();
    try {
      final DataSnapshot top = await _db
          .ref('users')
          .orderByChild('rating')
          .limitToLast(limit)
          .get();
      return ratingTable(top.value, limit: limit);
    } on FirebaseException {
      throw const OnlineUnavailable(OnlineFailure.network);
    }
  }

  @override
  Future<void> cancelQuickMatch() async {
    await _leaveQueue();
    final Completer<RoomHandle?>? completer = _queue;
    _queue = null;
    if (completer != null && !completer.isCompleted) completer.complete(null);
  }

  Future<void> _leaveQueue() async {
    await _queueWatch?.cancel();
    _queueWatch = null;
    if (_uid == null) return;
    try {
      await _db.ref('matchmaking/$_me').remove();
    } on FirebaseException {
      // Очередь чистится и сама по onDisconnect — падать тут незачем.
    }
  }

  @override
  void dispose() {
    unawaited(_leaveQueue());
  }
}

class _FirebaseRoom implements RoomHandle {
  _FirebaseRoom(this._db, {required this.roomId, required this.uid}) {
    _snapshot = RoomSnapshot(roomId: roomId);
    _stream = _db
        .ref('rooms/$roomId')
        .onValue
        .map((DatabaseEvent event) {
          _snapshot = RoomSnapshot.fromJson(roomId, event.snapshot.value);
          return _snapshot;
        })
        .asBroadcastStream();
  }

  final FirebaseDatabase _db;

  @override
  final String roomId;

  @override
  final String uid;

  late RoomSnapshot _snapshot;
  late final Stream<RoomSnapshot> _stream;

  @override
  RoomSnapshot get snapshot => _snapshot;

  @override
  Stream<RoomSnapshot> get snapshots => _stream;

  @override
  Future<void> update(Map<String, Object?> values) => _db
      .ref('rooms/$roomId')
      .update(<String, Object?>{
        for (final MapEntry<String, Object?> entry in values.entries)
          entry.key: _resolve(entry.value),
      });

  /// Метки серверного времени подменяются прямо перед отправкой.
  Object? _resolve(Object? value) {
    if (value is ServerTimestamp) return ServerValue.timestamp;
    if (value is Map<String, Object?>) {
      return <String, Object?>{
        for (final MapEntry<String, Object?> entry in value.entries)
          entry.key: _resolve(entry.value),
      };
    }
    return value;
  }

  @override
  Future<void> keepPresence() async {
    final DatabaseReference presence = _db.ref('rooms/$roomId/presence/$uid');
    await presence.onDisconnect().set(false);
    await presence.set(true);
  }

  @override
  Future<void> leave() async {
    final DatabaseReference presence = _db.ref('rooms/$roomId/presence/$uid');
    await presence.onDisconnect().cancel();
    await presence.set(false);
  }
}
