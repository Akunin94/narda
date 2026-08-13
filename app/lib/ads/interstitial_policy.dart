/// Когда можно показать interstitial (§P3).
///
/// Правило одно и целиком проверяемое: реклама между партиями, не чаще раза
/// в три минуты и не в первых двух партиях. Логика вынесена из
/// [AdsController], чтобы её можно было проверить тестами без AdMob.
class InterstitialPolicy {
  InterstitialPolicy({
    this.minimumInterval = const Duration(minutes: 3),
    this.freeGames = 2,
  });

  /// Минимальный промежуток между двумя показами.
  final Duration minimumInterval;

  /// Сколько первых партий проходит вообще без interstitial.
  final int freeGames;

  int _finishedGames = 0;
  DateTime? _lastShown;

  int get finishedGames => _finishedGames;

  /// Партия закончилась.
  void noteGameFinished() => _finishedGames++;

  /// Разрешён ли показ в момент [now].
  bool allows(DateTime now) {
    if (_finishedGames <= freeGames) return false;
    final DateTime? last = _lastShown;
    return last == null || now.difference(last) >= minimumInterval;
  }

  /// Реклама показана — с этого момента отсчитывается пауза.
  void noteShown(DateTime now) => _lastShown = now;
}
