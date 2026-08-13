import 'player.dart';

/// Перевод между абсолютной нумерацией пунктов (1..24, белая перспектива)
/// и «собственной» нумерацией игрока (1..24, голова = 24, дом = 1..6,
/// движение по убыванию 24 -> 1 -> выброс).
///
/// Белые: собственный пункт n == абсолютный n.
/// Чёрные: абсолютный == ((n + 11) % 24) + 1. Формула является инволюцией,
/// поэтому обратный перевод считается тем же выражением.
abstract final class Coords {
  /// Количество пунктов на доске.
  static const int pointCount = 24;

  /// Собственный номер головы (голова белых — абс. 24, чёрных — абс. 12).
  static const int headOwn = 24;

  /// Размер дома: собственные пункты 1..6.
  static const int homeSize = 6;

  /// Абсолютный пункт по собственному номеру [own] игрока [player].
  static int toAbsolute(Player player, int own) {
    assert(own >= 1 && own <= pointCount, 'own out of range: $own');
    return player == Player.white ? own : ((own + 11) % pointCount) + 1;
  }

  /// Собственный номер пункта [abs] для игрока [player].
  static int toOwn(Player player, int abs) {
    assert(abs >= 1 && abs <= pointCount, 'abs out of range: $abs');
    return player == Player.white ? abs : ((abs + 11) % pointCount) + 1;
  }

  /// Абсолютный пункт головы игрока: 24 у белых, 12 у чёрных.
  static int headAbs(Player player) => toAbsolute(player, headOwn);

  /// Находится ли собственный пункт в доме.
  static bool isHomeOwn(int own) => own >= 1 && own <= homeSize;

  /// Находится ли абсолютный пункт в доме игрока
  /// (абс. 1..6 у белых, абс. 13..18 у чёрных).
  static bool isHomeAbs(Player player, int abs) => isHomeOwn(toOwn(player, abs));

  /// Индекс бита в маске занятости (0-based) по абсолютному пункту.
  static int absIndex(int abs) => abs - 1;
}
