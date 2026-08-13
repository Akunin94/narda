import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'elo.dart';

/// Сколько аватаров в наборе (§P5: ник + аватар из набора).
/// Сами аватары рисуются кодом — см. `ui/avatar.dart`.
const int nardaAvatarCount = 8;

/// Ник длиннее в комнату всё равно не поедет: правила базы режут на 24.
const int nardaMaxNameLength = 16;

/// Профиль игрока: ник, аватар и рейтинг Elo (§P5).
@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.name,
    this.avatar = 0,
    this.rating = eloStartRating,
    this.ratedGames = 0,
    this.ratedWins = 0,
  });

  final String name;
  final int avatar;

  /// Рейтинг Elo. Меняется только в онлайне: партии с ботом рейтинговыми
  /// не считаются, иначе его можно накрутить тренировкой.
  final int rating;
  final int ratedGames;
  final int ratedWins;

  PlayerProfile copyWith({
    String? name,
    int? avatar,
    int? rating,
    int? ratedGames,
    int? ratedWins,
  }) => PlayerProfile(
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    rating: rating ?? this.rating,
    ratedGames: ratedGames ?? this.ratedGames,
    ratedWins: ratedWins ?? this.ratedWins,
  );
}

/// На сколько изменился рейтинг после матча — это показывает итоговое окно.
@immutable
class RatingChange {
  const RatingChange({required this.before, required this.after});

  final int before;
  final int after;

  int get delta => after - before;
}

/// Хранилище профиля поверх shared_preferences.
class ProfileController extends ChangeNotifier {
  ProfileController._(this._prefs, this._profile);

  /// Без диска — для тестов и превью.
  ProfileController.inMemory([PlayerProfile? profile])
    : this._(null, profile ?? PlayerProfile(name: defaultName()));

  static Future<ProfileController> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_keyName);
    final String name = stored ?? defaultName();
    if (stored == null) await prefs.setString(_keyName, name);
    return ProfileController._(
      prefs,
      PlayerProfile(
        name: name,
        avatar: (prefs.getInt(_keyAvatar) ?? 0).clamp(0, nardaAvatarCount - 1),
        rating: prefs.getInt(_keyRating) ?? eloStartRating,
        ratedGames: prefs.getInt(_keyRatedGames) ?? 0,
        ratedWins: prefs.getInt(_keyRatedWins) ?? 0,
      ),
    );
  }

  static const String _keyName = 'profile_name';
  static const String _keyAvatar = 'profile_avatar';
  static const String _keyRating = 'profile_rating';
  static const String _keyRatedGames = 'profile_rated_games';
  static const String _keyRatedWins = 'profile_rated_wins';

  /// Ник по умолчанию — «O'yinchi 1234»: играть можно сразу, не заходя в
  /// профиль, а сменить ник — в любой момент.
  static String defaultName([Random? random]) =>
      'O\'yinchi ${1000 + (random ?? Random()).nextInt(9000)}';

  final SharedPreferences? _prefs;
  PlayerProfile _profile;

  PlayerProfile get profile => _profile;

  String get name => _profile.name;

  set name(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == _profile.name) return;
    final String next = trimmed.length > nardaMaxNameLength
        ? trimmed.substring(0, nardaMaxNameLength)
        : trimmed;
    _profile = _profile.copyWith(name: next);
    _prefs?.setString(_keyName, next);
    notifyListeners();
  }

  int get avatar => _profile.avatar;

  set avatar(int value) {
    final int next = value.clamp(0, nardaAvatarCount - 1);
    if (next == _profile.avatar) return;
    _profile = _profile.copyWith(avatar: next);
    _prefs?.setInt(_keyAvatar, next);
    notifyListeners();
  }

  int get rating => _profile.rating;

  int get ratedGames => _profile.ratedGames;

  int get ratedWins => _profile.ratedWins;

  /// Записывает итог сетевого матча: новый рейтинг Elo и счётчики.
  RatingChange applyMatchResult({
    required int opponentRating,
    required bool won,
  }) {
    final int before = _profile.rating;
    final int after = eloUpdated(
      rating: before,
      opponentRating: opponentRating,
      won: won,
      ratedGames: _profile.ratedGames,
    );
    _profile = _profile.copyWith(
      rating: after,
      ratedGames: _profile.ratedGames + 1,
      ratedWins: _profile.ratedWins + (won ? 1 : 0),
    );
    _prefs
      ?..setInt(_keyRating, after)
      ..setInt(_keyRatedGames, _profile.ratedGames)
      ..setInt(_keyRatedWins, _profile.ratedWins);
    notifyListeners();
    return RatingChange(before: before, after: after);
  }
}
