import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'interstitial_policy.dart';

/// Реклама по правилам §P3.
///
/// Interstitial показывается **только между партиями** — не чаще одного раза
/// в три минуты и не раньше, чем игрок закончит две партии. Rewarded открывает
/// тему оформления на 24 часа. Согласие пользователя собирается через UMP до
/// первой загрузки объявлений.
///
/// В тестах и на платформах без AdMob берётся [AdsController.disabled].
class AdsController extends ChangeNotifier {
  AdsController({InterstitialPolicy? policy, DateTime Function() now = DateTime.now})
    : _enabled = true,
      _policy = policy ?? InterstitialPolicy(),
      _now = now;

  /// Реклама выключена целиком: тесты, превью и релиз без `--dart-define`.
  AdsController.disabled()
    : _enabled = false,
      _policy = InterstitialPolicy(),
      _now = DateTime.now;

  final bool _enabled;
  final InterstitialPolicy _policy;
  final DateTime Function() _now;

  bool _initialized = false;
  bool _canRequestAds = false;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  /// Готов ли rewarded к показу — по этому флагу экран тем включает кнопку.
  bool get rewardedReady => _rewarded != null;

  /// Работает ли реклама в этой сборке.
  bool get enabled => _enabled && AdIds.configured;

  /// Согласие получено и объявления можно запрашивать.
  bool get canRequestAds => _canRequestAds;

  /// Сбор согласия (UMP) и инициализация SDK. Ошибки не роняют приложение:
  /// без рекламы игра работает полностью.
  Future<void> initialize() async {
    if (!enabled || _initialized) return;
    _initialized = true;
    try {
      await _requestConsent();
      await MobileAds.instance.initialize();
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!_canRequestAds) return;
      notifyListeners();
      unawaited(_loadInterstitial());
      unawaited(loadRewarded());
    } on Object catch (error) {
      debugPrint('narda: реклама недоступна — $error');
    }
  }

  /// Показывает форму согласия, если она требуется в этой стране.
  Future<void> _requestConsent() async {
    final Completer<void> updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () => updated.complete(),
      (FormError error) {
        debugPrint('narda: UMP не ответил — ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;

    final Completer<void> dismissed = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint('narda: форма согласия не показана — ${error.message}');
      }
      if (!dismissed.isCompleted) dismissed.complete();
    });
    await dismissed.future;
  }

  /// Экран настроек: повторно открыть окно приватности, если оно доступно.
  Future<void> showPrivacyOptions() async {
    if (!enabled) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) {
          debugPrint('narda: окно приватности — ${error.message}');
        }
      });
    } on Object catch (error) {
      debugPrint('narda: окно приватности недоступно — $error');
    }
  }

  /// Доступно ли повторное окно приватности (обязательный пункт UMP там,
  /// где действует GDPR).
  Future<bool> privacyOptionsRequired() async {
    if (!enabled) return false;
    try {
      final PrivacyOptionsRequirementStatus status = await ConsentInformation
          .instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } on Object catch (error) {
      debugPrint('narda: статус приватности неизвестен — $error');
      return false;
    }
  }

  /// Партия закончилась: счётчик нужен правилу «не в первых двух партиях».
  void noteGameFinished() => _policy.noteGameFinished();

  /// Можно ли показать interstitial прямо сейчас (§P3).
  bool get canShowInterstitial {
    if (!enabled || !_canRequestAds || _interstitial == null) return false;
    return _policy.allows(_now());
  }

  /// Показывает interstitial между партиями и ждёт его закрытия.
  /// Во время партии этот метод не вызывается — он вызывается только из
  /// перехода к следующей партии.
  Future<void> maybeShowInterstitial() async {
    if (!canShowInterstitial) {
      if (enabled && _canRequestAds) unawaited(_loadInterstitial());
      return;
    }
    final InterstitialAd ad = _interstitial!;
    _interstitial = null;
    _policy.noteShown(_now());
    final Completer<void> closed = Completer<void>();
    ad.fullScreenContentCallback = _dismissOn<InterstitialAd>(
      closed,
      'interstitial',
    );
    await _show(ad.show, closed, 'interstitial');
    unawaited(_loadInterstitial());
  }

  /// Обвязка полноэкранного объявления: и закрытие, и сбой показа одинаково
  /// освобождают объявление и снимают ожидание.
  FullScreenContentCallback<T> _dismissOn<T extends Ad>(
    Completer<void> closed,
    String label,
  ) => FullScreenContentCallback<T>(
    onAdDismissedFullScreenContent: (T ad) => _release(ad, closed),
    onAdFailedToShowFullScreenContent: (T ad, AdError error) {
      debugPrint('narda: $label не показан — ${error.message}');
      _release(ad, closed);
    },
  );

  void _release(Ad ad, Completer<void> closed) {
    ad.dispose();
    if (!closed.isCompleted) closed.complete();
  }

  /// Ждёт показа и закрытия. Упавший ролик игру не роняет: без рекламы всё
  /// работает полностью.
  Future<void> _show(
    Future<void> Function() show,
    Completer<void> closed,
    String label,
  ) async {
    try {
      await show();
      await closed.future;
    } on Object catch (error) {
      debugPrint('narda: $label упал — $error');
    }
  }

  /// Загружать нечего: реклама выключена, согласия нет, объявление уже
  /// готово или уже грузится, либо для него не задан ad unit.
  bool _skipLoad({
    required bool ready,
    required bool loading,
    required String unitId,
  }) => !enabled || !_canRequestAds || ready || loading || unitId.isEmpty;

  Future<void> _loadInterstitial() async {
    if (_skipLoad(
      ready: _interstitial != null,
      loading: _loadingInterstitial,
      unitId: AdIds.interstitial,
    )) {
      return;
    }
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _loadingInterstitial = false;
            _interstitial = ad;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _loadingInterstitial = false;
            debugPrint('narda: interstitial не загрузился — ${error.message}');
          },
        ),
      );
    } on Object catch (error) {
      _loadingInterstitial = false;
      debugPrint('narda: загрузка interstitial упала — $error');
    }
  }

  /// Заранее готовит rewarded, чтобы кнопка в экране тем была активна.
  Future<void> loadRewarded() async {
    if (_skipLoad(
      ready: _rewarded != null,
      loading: _loadingRewarded,
      unitId: AdIds.rewarded,
    )) {
      return;
    }
    _loadingRewarded = true;
    try {
      await RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _loadingRewarded = false;
            _rewarded = ad;
            notifyListeners();
          },
          onAdFailedToLoad: (LoadAdError error) {
            _loadingRewarded = false;
            debugPrint('narda: rewarded не загрузился — ${error.message}');
            notifyListeners();
          },
        ),
      );
    } on Object catch (error) {
      _loadingRewarded = false;
      debugPrint('narda: загрузка rewarded упала — $error');
    }
  }

  /// Показывает rewarded. `true` — ролик досмотрен и награда заслужена.
  Future<bool> showRewarded() async {
    final RewardedAd? ad = _rewarded;
    if (!enabled || ad == null) return false;
    _rewarded = null;
    notifyListeners();
    bool earned = false;
    final Completer<void> closed = Completer<void>();
    ad.fullScreenContentCallback = _dismissOn<RewardedAd>(closed, 'rewarded');
    await _show(
      () => ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          earned = true;
        },
      ),
      closed,
      'rewarded',
    );
    unawaited(loadRewarded());
    return earned;
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
    super.dispose();
  }
}
