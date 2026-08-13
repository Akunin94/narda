import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки игрока. В P2 их ровно две: автоход при единственном легальном
/// варианте (§P2) и показ pip-счёта обоих игроков (§7).
class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs, {required bool autoMove, required bool showPips})
    : _autoMove = autoMove,
      _showPips = showPips;

  /// Настройки без сохранения на диск — для тестов и превью.
  SettingsController.inMemory({bool autoMove = true, bool showPips = true})
    : this._(null, autoMove: autoMove, showPips: showPips);

  /// Читает сохранённые настройки.
  static Future<SettingsController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SettingsController._(
      prefs,
      autoMove: prefs.getBool(_keyAutoMove) ?? true,
      showPips: prefs.getBool(_keyShowPips) ?? true,
    );
  }

  static const String _keyAutoMove = 'auto_move';
  static const String _keyShowPips = 'show_pips';

  final SharedPreferences? _prefs;

  bool _autoMove;
  bool _showPips;

  /// Выполнять ход автоматически, когда легальный вариант ровно один.
  bool get autoMove => _autoMove;

  set autoMove(bool value) {
    if (value == _autoMove) return;
    _autoMove = value;
    _prefs?.setBool(_keyAutoMove, value);
    notifyListeners();
  }

  /// Показывать pip-счёт обоих игроков.
  bool get showPips => _showPips;

  set showPips(bool value) {
    if (value == _showPips) return;
    _showPips = value;
    _prefs?.setBool(_keyShowPips, value);
    notifyListeners();
  }
}
