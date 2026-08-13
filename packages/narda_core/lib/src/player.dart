/// Одна из двух сторон партии.
///
/// Белые стартуют с абсолютного пункта 24, чёрные — с абсолютного пункта 12.
/// Оба игрока движутся в одном круговом направлении (в собственной нумерации
/// это всегда убывание 24 -> 1), поэтому шашки никогда не идут навстречу.
enum Player {
  white,
  black;

  /// Соперник.
  Player get opponent => this == Player.white ? Player.black : Player.white;

  /// Знак, которым шашки игрока кодируются в [GameState.points]:
  /// белые — положительные значения, чёрные — отрицательные.
  int get sign => this == Player.white ? 1 : -1;

  /// Короткий код для логов и кодирования состояния.
  String get code => this == Player.white ? 'w' : 'b';

  static Player fromCode(String code) => switch (code) {
    'w' => Player.white,
    'b' => Player.black,
    _ => throw ArgumentError.value(code, 'code', 'Unknown player code'),
  };
}
