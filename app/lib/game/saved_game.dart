import 'package:narda_core/narda_core.dart';

/// Прерванная партия с ботом: уровень, счёт серии и позиция с уже выпавшими костями.
class SavedBotGame {
  const SavedBotGame(this.level, this.score, this.state);

  final BotLevel level;
  final MatchScore score;
  final GameState state;

  String encode() =>
      '${level.index},${score.target.index},${score.white},${score.black},'
      '${score.gamesPlayed};${state.encode()}';

  /// `null` — сохранения нет или оно испорчено.
  static SavedBotGame? decode(String? raw) {
    if (raw == null) return null;
    try {
      final int split = raw.indexOf(';');
      final List<int> head = raw.substring(0, split).split(',').map(int.parse).toList();
      return SavedBotGame(
        BotLevel.values[head[0]],
        MatchScore(
          target: MatchTarget.values[head[1]],
          white: head[2],
          black: head[3],
          gamesPlayed: head[4],
        ),
        GameState.decode(raw.substring(split + 1)),
      );
    } on Object {
      return null;
    }
  }
}
