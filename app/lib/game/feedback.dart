import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import 'settings.dart';

/// Отклик на события партии: звук и вибрация (§P3).
///
/// Отдельный слой нужен ещё и потому, что в тестах плагинов нет: там берётся
/// [SilentFeedback], и ни одного обращения к платформе не происходит.
abstract interface class MatchFeedback {
  /// Бросок костей.
  void dice();

  /// Перемещение шашки.
  void checker();

  /// Конец партии.
  void gameOver({required bool won});

  void dispose();
}

/// Ничего не делает — значение по умолчанию и вариант для тестов.
class SilentFeedback implements MatchFeedback {
  const SilentFeedback();

  @override
  void dice() {}

  @override
  void checker() {}

  @override
  void gameOver({required bool won}) {}

  @override
  void dispose() {}
}

/// Звуки из assets/sounds и вибро-отклик. Каждый вызов проверяет настройки,
/// поэтому выключенный звук не доходит до плагина вовсе.
class DeviceFeedback implements MatchFeedback {
  DeviceFeedback(this.settings);

  final SettingsController settings;

  /// Отдельные проигрыватели: щелчок шашки не должен обрывать стук костей.
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};

  bool _vibrationChecked = false;
  bool _hasVibrator = false;
  bool _disposed = false;

  @override
  void dice() {
    _play('dice.wav');
    _buzz(28);
  }

  @override
  void checker() {
    _play('checker.wav');
    _buzz(12);
  }

  @override
  void gameOver({required bool won}) {
    _play(won ? 'win.wav' : 'lose.wav');
    _buzz(won ? 220 : 90);
  }

  void _play(String asset) {
    if (!settings.sound || _disposed) return;
    unawaited(_playAsset(asset));
  }

  Future<void> _playAsset(String asset) async {
    try {
      final AudioPlayer player = _players.putIfAbsent(asset, () {
        final AudioPlayer created = AudioPlayer(playerId: 'narda_$asset');
        unawaited(created.setReleaseMode(ReleaseMode.stop));
        unawaited(created.setPlayerMode(PlayerMode.lowLatency));
        return created;
      });
      await player.stop();
      await player.play(AssetSource('sounds/$asset'), volume: 0.85);
    } on Object catch (error) {
      // Звук — украшение: на устройстве без аудио партия должна идти дальше.
      debugPrint('narda: не удалось проиграть $asset — $error');
    }
  }

  void _buzz(int milliseconds) {
    if (!settings.vibration || _disposed) return;
    unawaited(_vibrate(milliseconds));
  }

  Future<void> _vibrate(int milliseconds) async {
    try {
      if (!_vibrationChecked) {
        _vibrationChecked = true;
        _hasVibrator = await Vibration.hasVibrator();
      }
      if (!_hasVibrator || _disposed) return;
      await Vibration.vibrate(duration: milliseconds, amplitude: 128);
    } on Object catch (error) {
      debugPrint('narda: вибрация недоступна — $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final AudioPlayer player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
  }
}
