import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'online_backend.dart';
import 'protocol.dart';

/// Голос в онлайн-партии: WebRTC напрямую между телефонами, сигналинг идёт
/// через узел комнаты `voice/{uid}`. Звук есть, только пока микрофон включили оба.
class VoiceChat extends ChangeNotifier {
  VoiceChat(this.room) {
    _subscription = room.snapshots.listen((RoomSnapshot _) => _enqueue(_sync));
  }

  final RoomHandle room;

  // shortcut: только публичный STUN — у части мобильных операторов звук не пройдёт; добавить TURN (Cloudflare).
  static const Map<String, Object> _config = <String, Object>{
    'iceServers': <Map<String, String>>[
      <String, String>{'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  StreamSubscription<RoomSnapshot>? _subscription;
  Future<void> _queue = Future<void>.value();
  MediaStream? _mic;
  RTCPeerConnection? _pc;
  bool _remoteSet = false;
  int _gen = 0;
  int? _peerGen;
  int _iceSent = 0;
  int _iceSeen = 0;
  bool _connected = false;
  bool _peerEnabled = false;
  bool _denied = false;
  bool _disposed = false;

  /// Микрофон включён на этом телефоне.
  bool get enabled => _mic != null;

  /// Соединение с соперником установлено — звук идёт.
  bool get connected => _connected;

  /// Соперник включил свой микрофон.
  bool get peerEnabled => _peerEnabled;

  /// Последняя попытка включить упёрлась в запрет доступа к микрофону.
  bool get denied => _denied;

  String get _me => room.uid;

  Future<void> toggle() => _enqueue(() => enabled ? _disable() : _enable());

  /// Все шаги сигналинга идут строго по очереди: WebRTC не любит параллельных
  /// смен описаний.
  Future<void> _enqueue(Future<void> Function() step) => _queue = _queue
      .then((_) => step())
      .catchError((Object error) => debugPrint('narda voice: $error'));

  Future<void> _enable() async {
    final MediaStream mic;
    try {
      mic = await navigator.mediaDevices.getUserMedia(<String, Object>{
        'audio': true,
        'video': false,
      });
    } on Object {
      _denied = true;
      _notify();
      return;
    }
    if (_disposed) return _release(mic);
    _mic = mic;
    _denied = false;
    _gen = Random().nextInt(1 << 30) + 1;
    _peerGen = null;
    _iceSent = 0;
    _notify();
    await Helper.setSpeakerphoneOn(true);
    await room.update(<String, Object?>{
      'voice/$_me': <String, Object?>{'gen': _gen},
    });
    await _sync();
  }

  Future<void> _disable() async {
    await _closePeer();
    final MediaStream? mic = _mic;
    _mic = null;
    _peerGen = null;
    _notify();
    if (mic != null) await _release(mic);
    await room.update(<String, Object?>{'voice/$_me': null});
  }

  /// Сверяет своё соединение со снимком комнаты: кто предлагает (меньший uid),
  /// кто отвечает, какие ICE-кандидаты соперника ещё не добавлены.
  Future<void> _sync() async {
    final RoomSnapshot snapshot = room.snapshot;
    final String? peer = snapshot.opponentOf(_me)?.uid;
    final VoiceSignal? theirs = peer == null ? null : snapshot.voice[peer];
    if ((theirs != null) != _peerEnabled) {
      _peerEnabled = theirs != null;
      _notify();
    }
    if (!enabled || _disposed) return;

    if (theirs?.gen != _peerGen) {
      // Соперник выключил или заново включил голос — сеанс с нуля.
      final bool stale = _pc != null || _iceSent > 0;
      await _closePeer();
      _peerGen = theirs?.gen;
      _iceSent = 0;
      if (stale) {
        await room.update(<String, Object?>{
          'voice/$_me/desc': null,
          'voice/$_me/ice': null,
        });
      }
    }
    if (theirs == null || peer == null) return;

    final bool offerer = _me.compareTo(peer) < 0;
    RTCPeerConnection? pc = _pc;
    if (pc == null && offerer) {
      pc = await _openPeer();
      final RTCSessionDescription offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _sendDesc(offer);
    } else if (pc == null && theirs.descType == 'offer' && theirs.descFor == _gen) {
      pc = await _openPeer();
      await pc.setRemoteDescription(RTCSessionDescription(theirs.sdp, 'offer'));
      _remoteSet = true;
      final RTCSessionDescription answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _sendDesc(answer);
    } else if (pc != null &&
        !_remoteSet &&
        theirs.descType == 'answer' &&
        theirs.descFor == _gen) {
      await pc.setRemoteDescription(RTCSessionDescription(theirs.sdp, 'answer'));
      _remoteSet = true;
    }
    if (pc == null || !_remoteSet) return;
    while (_iceSeen < theirs.ice.length) {
      final Object? candidate = jsonDecode(theirs.ice[_iceSeen++]);
      if (candidate is! Map) continue;
      await pc.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          asInt(candidate['sdpMLineIndex']),
        ),
      );
    }
  }

  Future<RTCPeerConnection> _openPeer() async {
    final RTCPeerConnection pc = await createPeerConnection(_config);
    final MediaStream mic = _mic!;
    for (final MediaStreamTrack track in mic.getAudioTracks()) {
      await pc.addTrack(track, mic);
    }
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null || _pc != pc) return;
      unawaited(
        room.update(<String, Object?>{
          'voice/$_me/ice/${_iceSent++}': jsonEncode(candidate.toMap()),
        }),
      );
    };
    pc.onConnectionState = (RTCPeerConnectionState state) {
      if (_pc != pc) return;
      _connected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _notify();
    };
    _pc = pc;
    _remoteSet = false;
    _iceSeen = 0;
    return pc;
  }

  Future<void> _sendDesc(RTCSessionDescription desc) =>
      room.update(<String, Object?>{
        'voice/$_me/desc': <String, Object?>{
          'type': desc.type,
          'sdp': desc.sdp,
          'peerGen': _peerGen,
        },
      });

  Future<void> _closePeer() async {
    final RTCPeerConnection? pc = _pc;
    _pc = null;
    _remoteSet = false;
    _iceSeen = 0;
    if (_connected) {
      _connected = false;
      _notify();
    }
    await pc?.close();
  }

  Future<void> _release(MediaStream mic) async {
    for (final MediaStreamTrack track in mic.getTracks()) {
      await track.stop();
    }
    await mic.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    // Выход с экрана партии выключает микрофон и стирает свой узел.
    if (enabled) unawaited(_enqueue(_disable));
    super.dispose();
  }
}
