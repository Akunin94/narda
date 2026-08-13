import 'package:flutter/foundation.dart';

/// Идентификаторы AdMob.
///
/// В debug всегда берутся тестовые юниты Google — по-другому Play-аккаунт
/// быстро получает бан за клики по собственной рекламе. В релизе они приходят
/// из `--dart-define` (§P3):
///
/// ```
/// flutter build appbundle --release \
///   --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-xxx/yyy \
///   --dart-define=ADMOB_REWARDED=ca-app-pub-xxx/zzz
/// ```
///
/// Если в релизной сборке ID не передали, реклама просто выключается: пустой
/// ID лучше, чем чужой.
abstract final class AdIds {
  /// Тестовые юниты Google, публичные и безопасные.
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const String _releaseInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL',
  );
  static const String _releaseRewarded = String.fromEnvironment(
    'ADMOB_REWARDED',
  );

  static String get interstitial =>
      kReleaseMode ? _releaseInterstitial : testInterstitial;

  static String get rewarded => kReleaseMode ? _releaseRewarded : testRewarded;

  /// Есть ли вообще с чем работать: в релизе без `--dart-define` — нет.
  static bool get configured => interstitial.isNotEmpty || rewarded.isNotEmpty;
}
