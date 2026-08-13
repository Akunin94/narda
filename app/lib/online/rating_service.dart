import '../profile/profile.dart';
import 'online_backend.dart';
import 'protocol.dart';

/// Рейтинг Elo после сетевого матча (§P5).
///
/// Считают обе стороны сами и независимо: рейтинги на входе взяты из записей
/// комнаты (`players/{uid}/rating`), поэтому у обоих клиентов получается одно
/// и то же число. Проверить чужую запись правила базы не могут — как и с
/// костями (§6), это честное ограничение MVP; серверный пересчёт живёт в
/// backlog, а точка замены — этот класс.
class RatingService {
  const RatingService({
    required OnlineBackend backend,
    required ProfileController profile,
  }) : _backend = backend,
       _profile = profile;

  final OnlineBackend _backend;
  final ProfileController _profile;

  ProfileController get profile => _profile;

  /// Записывает итог матча в локальный профиль и публикует его в таблицу.
  Future<RatingChange> applyMatch({
    required int opponentRating,
    required bool won,
  }) async {
    final RatingChange change = _profile.applyMatchResult(
      opponentRating: opponentRating,
      won: won,
    );
    await publish();
    return change;
  }

  /// Отправляет профиль в таблицу лидеров. Сбой сети рейтинг не теряет: он
  /// уже сохранён локально и уедет со следующей публикацией.
  Future<void> publish() async {
    try {
      await _backend.publishProfile(
        card: PlayerCard(
          name: _profile.name,
          avatar: _profile.avatar,
          rating: _profile.rating,
        ),
        games: _profile.ratedGames,
        wins: _profile.ratedWins,
      );
    } on Object {
      // Таблица лидеров — не критичный путь: партия важнее.
    }
  }
}
