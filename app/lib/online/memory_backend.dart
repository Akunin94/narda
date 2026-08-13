import 'dart:async';
import 'dart:math';

import 'package:narda_core/narda_core.dart';

import 'online_backend.dart';
import 'protocol.dart';

/// Сервер комнат в памяти процесса.
///
/// К нему подключаются два [MemoryOnlineBackend] с разными uid — так партия
/// двух устройств проверяется тестами без Firebase и без сети. Реальную
/// доставку он не имитирует: запись видна подписчикам сразу.
class MemoryOnlineServer {
  MemoryOnlineServer({this.now = _wallClock, Random? random})
    : _random = random ?? Random(20260813);

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  /// Серверные часы — в тестах подменяются, чтобы проверить дедлайны.
  final int Function() now;

  final Random _random;

  final Map<String, Map<String, Object?>> _rooms = <String, Map<String, Object?>>{};
  final Map<String, StreamController<RoomSnapshot>> _streams =
      <String, StreamController<RoomSnapshot>>{};

  /// Очередь быстрого матча: uid -> `{target, roomId}` (§6).
  final Map<String, Map<String, Object?>> queue = <String, Map<String, Object?>>{};

  /// Кого разбудить, когда его подберут из очереди.
  final Map<String, void Function(String roomId)> waiting =
      <String, void Function(String roomId)>{};

  int _roomCounter = 0;

  String newRoomId() => 'room${++_roomCounter}';

  String newCode() => generateRoomCode(_random);

  Map<String, Object?>? room(String roomId) => _rooms[roomId];

  String? roomIdByCode(String code) {
    for (final MapEntry<String, Map<String, Object?>> entry in _rooms.entries) {
      final Object? meta = entry.value['meta'];
      if (meta is Map && meta['code'] == code) return entry.key;
    }
    return null;
  }

  void createRoom(String roomId, Map<String, Object?> data) {
    _rooms[roomId] = data;
    _publish(roomId);
  }

  Stream<RoomSnapshot> watch(String roomId) => _controller(roomId).stream;

  RoomSnapshot snapshot(String roomId) =>
      RoomSnapshot.fromJson(roomId, _rooms[roomId]);

  /// Многопутевая запись, как `update()` в Realtime Database.
  void update(String roomId, Map<String, Object?> values) {
    final Map<String, Object?>? root = _rooms[roomId];
    if (root == null) return;
    values.forEach((String path, Object? value) {
      _writePath(root, path.split('/'), _resolve(value));
    });
    _publish(roomId);
  }

  Object? _resolve(Object? value) {
    if (value is ServerTimestamp) return now();
    if (value is Map<String, Object?>) {
      return <String, Object?>{
        for (final MapEntry<String, Object?> entry in value.entries)
          entry.key: _resolve(entry.value),
      };
    }
    return value;
  }

  void _writePath(Map<String, Object?> node, List<String> path, Object? value) {
    if (path.length == 1) {
      if (value == null) {
        node.remove(path.first);
      } else {
        node[path.first] = value;
      }
      return;
    }
    final Object? child = node[path.first];
    final Map<String, Object?> next = child is Map<String, Object?>
        ? child
        : <String, Object?>{};
    node[path.first] = next;
    _writePath(next, path.sublist(1), value);
  }

  StreamController<RoomSnapshot> _controller(String roomId) =>
      _streams.putIfAbsent(
        roomId,
        () => StreamController<RoomSnapshot>.broadcast(),
      );

  void _publish(String roomId) {
    final StreamController<RoomSnapshot>? controller = _streams[roomId];
    if (controller == null || controller.isClosed) return;
    controller.add(snapshot(roomId));
  }

  void dispose() {
    for (final StreamController<RoomSnapshot> controller in _streams.values) {
      controller.close();
    }
    _streams.clear();
    queue.clear();
    waiting.clear();
  }
}

/// Один «клиент» сервера в памяти.
class MemoryOnlineBackend implements OnlineBackend {
  MemoryOnlineBackend(this.server, {required this.uid});

  final MemoryOnlineServer server;
  final String uid;

  Completer<RoomHandle?>? _queueWait;

  @override
  Future<String> signIn() async => uid;

  @override
  Future<Duration> serverTimeOffset() async => Duration.zero;

  @override
  Future<RoomHandle> createRoom({
    required MatchTarget target,
    required String name,
  }) async {
    final String roomId = server.newRoomId();
    final String code = server.newCode();
    server.createRoom(roomId, <String, Object?>{
      'meta': RoomMeta(
        code: code,
        matchTarget: target,
        status: RoomStatus.waiting,
        hostUid: uid,
        createdAt: server.now(),
      ).toJson(),
      'players': <String, Object?>{
        uid: RoomPlayer(uid: uid, name: name, color: Player.white).toJson(),
      },
      'presence': <String, Object?>{uid: true},
    });
    return MemoryRoomHandle(server, roomId: roomId, uid: uid);
  }

  @override
  Future<RoomHandle?> joinByCode(String code, {required String name}) async {
    final String? roomId = server.roomIdByCode(code);
    if (roomId == null) throw const OnlineUnavailable(OnlineFailure.roomNotFound);
    final RoomSnapshot snapshot = server.snapshot(roomId);
    if (snapshot.players.containsKey(uid)) {
      return MemoryRoomHandle(server, roomId: roomId, uid: uid);
    }
    if (snapshot.isFull) throw const OnlineUnavailable(OnlineFailure.roomFull);
    server.update(roomId, <String, Object?>{
      'players/$uid': RoomPlayer(
        uid: uid,
        name: name,
        color: Player.black,
      ).toJson(),
      'presence/$uid': true,
      'meta/status': RoomStatus.playing.name,
    });
    return MemoryRoomHandle(server, roomId: roomId, uid: uid);
  }

  @override
  Future<RoomHandle?> quickMatch({
    required MatchTarget target,
    required String name,
  }) async {
    for (final MapEntry<String, Map<String, Object?>> entry
        in server.queue.entries) {
      if (entry.key == uid) continue;
      if (entry.value['target'] != target.points) continue;
      if (entry.value['roomId'] != null) continue;
      final RoomHandle host = await createRoom(target: target, name: name);
      // Ожидающий видит номер комнаты и входит в неё вторым.
      entry.value['roomId'] = host.roomId;
      server.waiting.remove(entry.key)?.call(host.roomId);
      return host;
    }

    server.queue[uid] = <String, Object?>{'target': target.points, 'roomId': null};
    final Completer<RoomHandle?> completer = Completer<RoomHandle?>();
    _queueWait = completer;
    server.waiting[uid] = (String roomId) => _pair(completer, roomId, name);
    return completer.future;
  }

  void _pair(Completer<RoomHandle?> completer, String roomId, String name) {
    if (completer.isCompleted) return;
    _queueWait = null;
    server.queue.remove(uid);
    server.update(roomId, <String, Object?>{
      'players/$uid': RoomPlayer(
        uid: uid,
        name: name,
        color: Player.black,
      ).toJson(),
      'presence/$uid': true,
      'meta/status': RoomStatus.playing.name,
    });
    completer.complete(MemoryRoomHandle(server, roomId: roomId, uid: uid));
  }

  @override
  Future<void> cancelQuickMatch() async {
    server.queue.remove(uid);
    server.waiting.remove(uid);
    final Completer<RoomHandle?>? completer = _queueWait;
    _queueWait = null;
    if (completer != null && !completer.isCompleted) completer.complete(null);
  }

  @override
  void dispose() {
    server.waiting.remove(uid);
    server.queue.remove(uid);
  }
}

class MemoryRoomHandle implements RoomHandle {
  MemoryRoomHandle(this._server, {required this.roomId, required this.uid});

  final MemoryOnlineServer _server;

  @override
  final String roomId;

  @override
  final String uid;

  @override
  RoomSnapshot get snapshot => _server.snapshot(roomId);

  @override
  Stream<RoomSnapshot> get snapshots => _server.watch(roomId);

  @override
  Future<void> update(Map<String, Object?> values) async =>
      _server.update(roomId, values);

  @override
  Future<void> keepPresence() async =>
      _server.update(roomId, <String, Object?>{'presence/$uid': true});

  @override
  Future<void> leave() async =>
      _server.update(roomId, <String, Object?>{'presence/$uid': false});
}
