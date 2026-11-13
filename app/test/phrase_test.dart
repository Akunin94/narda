import 'package:flutter_test/flutter_test.dart';
import 'package:narda/online/memory_backend.dart';
import 'package:narda/online/online_backend.dart';
import 'package:narda/online/online_match.dart';
import 'package:narda/online/protocol.dart';
import 'package:narda_core/narda_core.dart';

Future<void> _pump() async {
  for (int i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('фраза соперника всплывает один раз, а не на каждом снимке комнаты', () async {
    int now = 1000000;
    final MemoryOnlineServer server = MemoryOnlineServer(now: () => now);
    addTearDown(server.dispose);
    final RoomHandle host = await MemoryOnlineBackend(server, uid: 'a').createRoom(
      target: MatchTarget.single,
      card: const PlayerCard(name: 'A'),
    );
    final RoomHandle guest = (await MemoryOnlineBackend(server, uid: 'b').joinByCode(
      host.snapshot.meta!.code,
      card: const PlayerCard(name: 'B'),
    ))!;
    DateTime clock() => DateTime.fromMillisecondsSinceEpoch(now);
    OnlineMatch open(RoomHandle room, Player color) => OnlineMatch(
      room: room,
      localColor: color,
      diceSecret: color.name,
      clock: clock,
      tickInterval: const Duration(milliseconds: 1),
    )..start();
    final OnlineMatch white = open(host, Player.white);
    final OnlineMatch black = open(guest, Player.black);
    addTearDown(white.dispose);
    addTearDown(black.dispose);
    await _pump();

    await black.sendPhrase('salom');
    await _pump();
    expect(white.opponentPhrase, 'salom');

    now += 7000;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(white.opponentPhrase, isNull, reason: 'фраза гаснет');

    await white.sendPhrase('rahmat');
    await _pump();
    expect(white.opponentPhrase, isNull, reason: 'погасшая фраза не всплывает снова');

    await black.sendPhrase('salom');
    await _pump();
    expect(white.opponentPhrase, 'salom', reason: 'та же фраза ещё раз — новая');
  });
}
