import 'package:flutter/foundation.dart';
import 'package:narda_core/narda_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/board_theme.dart';

/// Настройки игрока: язык, звук, вибрация, автоход, pip-счёт и оформление
/// доски (§P3). Здесь же лежат последние выборы стартового экрана — благодаря
/// им партия с ботом начинается в два тапа.
class SettingsController extends ChangeNotifier {
  SettingsController._(
    this._prefs, {
    required bool autoMove,
    required bool showPips,
    required bool sound,
    required bool vibration,
    required String? localeCode,
    required String boardThemeId,
    required BotLevel botLevel,
    required MatchTarget matchTarget,
    required this.now,
  }) : _autoMove = autoMove,
       _showPips = showPips,
       _sound = sound,
       _vibration = vibration,
       _localeCode = localeCode,
       _boardThemeId = boardThemeId,
       _botLevel = botLevel,
       _matchTarget = matchTarget;

  /// Настройки без сохранения на диск — для тестов и превью.
  SettingsController.inMemory({
    bool autoMove = true,
    bool showPips = true,
    bool sound = true,
    bool vibration = true,
    String? localeCode,
    String boardThemeId = 'klassik',
    BotLevel botLevel = BotLevel.orta,
    MatchTarget matchTarget = MatchTarget.single,
    DateTime Function() now = DateTime.now,
  }) : this._(
         null,
         autoMove: autoMove,
         showPips: showPips,
         sound: sound,
         vibration: vibration,
         localeCode: localeCode,
         boardThemeId: boardThemeId,
         botLevel: botLevel,
         matchTarget: matchTarget,
         now: now,
       );

  /// Читает сохранённые настройки.
  static Future<SettingsController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SettingsController._(
      prefs,
      autoMove: prefs.getBool(_keyAutoMove) ?? true,
      showPips: prefs.getBool(_keyShowPips) ?? true,
      sound: prefs.getBool(_keySound) ?? true,
      vibration: prefs.getBool(_keyVibration) ?? true,
      localeCode: prefs.getString(_keyLocale),
      boardThemeId: prefs.getString(_keyBoardTheme) ?? klassikTheme.id,
      botLevel: _enumAt(
        BotLevel.values,
        prefs.getInt(_keyBotLevel),
        BotLevel.orta.index,
      ),
      matchTarget: _enumAt(MatchTarget.values, prefs.getInt(_keyMatchTarget), 0),
      now: DateTime.now,
    );
  }

  /// Значение перечисления по сохранённому индексу: чужой или испорченный
  /// индекс прижимается к границам набора.
  static T _enumAt<T>(List<T> values, int? stored, int fallback) =>
      values[(stored ?? fallback).clamp(0, values.length - 1)];

  static const String _keyAutoMove = 'auto_move';
  static const String _keyShowPips = 'show_pips';
  static const String _keySound = 'sound';
  static const String _keyVibration = 'vibration';
  static const String _keyLocale = 'locale';
  static const String _keyBoardTheme = 'board_theme';
  static const String _keyBotLevel = 'bot_level';
  static const String _keyMatchTarget = 'match_target';
  static const String _unlockPrefix = 'theme_until_';

  /// Часы: подменяются в тестах, чтобы проверить истечение разблокировки.
  final DateTime Function() now;

  final SharedPreferences? _prefs;

  bool _autoMove;
  bool _showPips;
  bool _sound;
  bool _vibration;
  String? _localeCode;
  String _boardThemeId;
  BotLevel _botLevel;
  MatchTarget _matchTarget;

  /// Сроки разблокировки тем для варианта без диска.
  final Map<String, int> _memoryUnlocks = <String, int>{};

  /// Выполнять ход автоматически, когда легальный вариант ровно один.
  bool get autoMove => _autoMove;

  set autoMove(bool value) => _set(value, _autoMove, () {
    _autoMove = value;
    _prefs?.setBool(_keyAutoMove, value);
  });

  /// Показывать pip-счёт обоих игроков.
  bool get showPips => _showPips;

  set showPips(bool value) => _set(value, _showPips, () {
    _showPips = value;
    _prefs?.setBool(_keyShowPips, value);
  });

  /// Звуки костей, шашек и победы.
  bool get sound => _sound;

  set sound(bool value) => _set(value, _sound, () {
    _sound = value;
    _prefs?.setBool(_keySound, value);
  });

  /// Вибро-отклик на бросок, перемещение и конец партии.
  bool get vibration => _vibration;

  set vibration(bool value) => _set(value, _vibration, () {
    _vibration = value;
    _prefs?.setBool(_keyVibration, value);
  });

  /// Язык интерфейса: `null` — как на устройстве (по умолчанию узбекский).
  String? get localeCode => _localeCode;

  set localeCode(String? value) => _set(value, _localeCode, () {
    _localeCode = value;
    // «Как на устройстве» — это отсутствие записи, а не пустая строка.
    if (value == null) {
      _prefs?.remove(_keyLocale);
    } else {
      _prefs?.setString(_keyLocale, value);
    }
  });

  /// Последний выбранный уровень бота — подставляется на старте.
  BotLevel get botLevel => _botLevel;

  set botLevel(BotLevel value) => _set(value, _botLevel, () {
    _botLevel = value;
    _prefs?.setInt(_keyBotLevel, value.index);
  });

  /// Последний выбранный формат матча.
  MatchTarget get matchTarget => _matchTarget;

  set matchTarget(MatchTarget value) => _set(value, _matchTarget, () {
    _matchTarget = value;
    _prefs?.setInt(_keyMatchTarget, value.index);
  });

  /// Выбранная тема доски. Если срок платной темы истёк — классика.
  BoardTheme get boardTheme {
    final BoardTheme theme = boardThemeById(_boardThemeId);
    return isUnlocked(theme) ? theme : klassikTheme;
  }

  set boardTheme(BoardTheme value) => _set(value.id, _boardThemeId, () {
    _boardThemeId = value.id;
    _prefs?.setString(_keyBoardTheme, value.id);
  });

  /// Доступна ли тема прямо сейчас.
  bool isUnlocked(BoardTheme theme) =>
      theme.free || unlockRemaining(theme) != null;

  /// Сколько осталось до конца разблокировки; `null` — тема заперта.
  Duration? unlockRemaining(BoardTheme theme) {
    if (theme.free) return null;
    final int? until = _prefs?.getInt(_unlockPrefix + theme.id) ??
        _memoryUnlocks[theme.id];
    if (until == null) return null;
    final Duration left =
        DateTime.fromMillisecondsSinceEpoch(until).difference(now());
    return left > Duration.zero ? left : null;
  }

  /// Открывает тему на [duration] — вызывается после досмотренного ролика.
  void unlockTheme(BoardTheme theme, {Duration duration = const Duration(hours: 24)}) {
    final int until = now().add(duration).millisecondsSinceEpoch;
    _memoryUnlocks[theme.id] = until;
    _prefs?.setInt(_unlockPrefix + theme.id, until);
    notifyListeners();
  }

  /// Запись настройки: то же самое значение ничего не делает, иначе —
  /// присвоить, сохранить (если диск есть) и разбудить экраны.
  void _set<T>(T value, T current, void Function() apply) {
    if (value == current) return;
    apply();
    notifyListeners();
  }
}
