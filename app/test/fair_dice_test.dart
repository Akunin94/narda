import 'package:flutter_test/flutter_test.dart';
import 'package:narda/online/fair_dice.dart';
import 'package:narda_core/narda_core.dart';

void main() {
  test('раскрытия сходятся с обязательством, чужие — нет', () {
    final FairChain chain = FairChain('секрет');
    expect(verifyReveal(chain.commit, 1, chain.reveal(1)), isTrue);
    expect(verifyReveal(chain.commit, 300, chain.reveal(300)), isTrue);
    expect(verifyReveal(chain.commit, 300, chain.reveal(301)), isFalse);
    expect(
      verifyReveal(chain.reveal(5), 9, chain.reveal(9), anchorSlot: 5),
      isTrue,
    );
    expect(verifyReveal(FairChain('другой').commit, 1, chain.reveal(1)), isFalse);
    expect(FairChain('секрет').commit, chain.commit, reason: 'цепочка воспроизводима');
  });

  test('кости распределены равномерно', () {
    final FairChain white = FairChain('w');
    final FairChain black = FairChain('b');
    final List<int> counts = List<int>.filled(6, 0);
    for (int slot = 1; slot <= fairChainLength; slot++) {
      final DiceRoll roll = fairRoll(white.reveal(slot), black.reveal(slot), slot);
      counts[roll.a - 1]++;
      counts[roll.b - 1]++;
    }
    // 2200 граней: на каждую ~367, разброс шире ±80 — почти наверняка перекос.
    for (final int count in counts) {
      expect(count, inInclusiveRange(287, 447));
    }
  });
}
