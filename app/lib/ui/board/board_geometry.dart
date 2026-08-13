import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:narda_core/narda_core.dart';

/// Раскладка доски в портретной ориентации.
///
/// Доска показана глазами игрока [perspective]: его собственные пункты 1–6 —
/// нижняя правая четверть (дом), 7–12 — нижняя левая, 13–18 — верхняя левая,
/// 19–24 — верхняя правая. Голова (собств. 24) оказывается в правом верхнем
/// углу, голова соперника — в левом нижнем; оба идут по кругу против часовой.
class BoardGeometry {
  BoardGeometry({required this.size, required this.perspective});

  /// Пунктов в ряду.
  static const int columns = 12;

  final Size size;
  final Player perspective;

  /// Толщина рамки с орнаментом.
  late final double frame = math.min(size.width, size.height) * 0.042;

  /// Игровое поле внутри рамки.
  late final Rect inner = Rect.fromLTWH(
    frame,
    frame,
    size.width - 2 * frame,
    size.height - 2 * frame,
  );

  /// Ширина лотка для выброшенных шашек.
  late final double trayWidth = inner.width * 0.085;

  /// Ширина «петли» посередине доски.
  late final double barWidth = inner.width * 0.04;

  late final double pointWidth =
      (inner.width - 2 * trayWidth - barWidth) / columns;

  late final double pointHeight = inner.height * 0.42;

  late final double checkerRadius = math.min(
    pointWidth * 0.46,
    inner.height * 0.05,
  );

  late final Rect bar = Rect.fromLTWH(
    inner.left + trayWidth + 6 * pointWidth,
    inner.top,
    barWidth,
    inner.height,
  );

  /// Левая граница столбца [column] (0 — слева).
  double columnLeft(int column) =>
      inner.left +
      trayWidth +
      column * pointWidth +
      (column >= columns ~/ 2 ? barWidth : 0);

  /// Собственный номер пункта [abs] с точки зрения нижнего игрока.
  int ownOf(int abs) => Coords.toOwn(perspective, abs);

  /// Лежит ли пункт в нижнем ряду.
  bool isBottom(int abs) => ownOf(abs) <= columns;

  /// Столбец пункта: собств. 1 — крайний справа, собств. 13 — крайний слева.
  int columnOf(int abs) {
    final int own = ownOf(abs);
    return own <= columns ? columns - own : own - columns - 1;
  }

  /// Треугольник пункта.
  Rect pointRect(int abs) => Rect.fromLTWH(
    columnLeft(columnOf(abs)),
    isBottom(abs) ? inner.bottom - pointHeight : inner.top,
    pointWidth,
    pointHeight,
  );

  /// Область попадания пальцем — вся половина столбца.
  Rect hitRect(int abs) => Rect.fromLTWH(
    columnLeft(columnOf(abs)),
    isBottom(abs) ? inner.center.dy : inner.top,
    pointWidth,
    inner.height / 2,
  );

  /// Центр [index]-й шашки в стопке из [stackSize] на пункте [abs].
  /// Стопка растёт от края доски к центру и сжимается, когда шашек много.
  Offset checkerCenter(int abs, int index, int stackSize) {
    final bool bottom = isBottom(abs);
    final double x = columnLeft(columnOf(abs)) + pointWidth / 2;
    final double first = bottom
        ? inner.bottom - checkerRadius - 2
        : inner.top + checkerRadius + 2;
    final double y = bottom
        ? first - index * _stackStep(stackSize)
        : first + index * _stackStep(stackSize);
    return Offset(x, y);
  }

  double _stackStep(int stackSize) {
    if (stackSize <= 1) return 0;
    final double available = inner.height / 2 - 2 * checkerRadius - 2;
    return math.min(2 * checkerRadius + 1, available / (stackSize - 1));
  }

  /// Лоток выброса: у нижнего игрока — справа внизу, у верхнего — слева
  /// вверху, то есть у каждого рядом со своим домом.
  Rect trayRect(Player player) => player == perspective
      ? Rect.fromLTRB(
          inner.right - trayWidth,
          inner.center.dy,
          inner.right,
          inner.bottom,
        )
      : Rect.fromLTRB(
          inner.left,
          inner.top,
          inner.left + trayWidth,
          inner.center.dy,
        );

  /// Прямоугольник [index]-й выброшенной шашки в лотке.
  Rect trayCheckerRect(Player player, int index) {
    final Rect tray = trayRect(player);
    final bool bottom = player == perspective;
    final double height = checkerRadius * 0.7;
    final double step = math.min(
      height + 2,
      (tray.height - height - 8) / (GameState.checkersPerPlayer - 1),
    );
    final double top = bottom
        ? tray.bottom - 4 - height - index * step
        : tray.top + 4 + index * step;
    return Rect.fromLTWH(tray.left + 3, top, tray.width - 6, height);
  }

  /// Пункт под точкой [position] или `null`.
  int? pointAt(Offset position) {
    for (int abs = 1; abs <= Coords.pointCount; abs++) {
      if (hitRect(abs).contains(position)) return abs;
    }
    return null;
  }

  /// Попал ли тап в лоток выброса игрока [player].
  bool trayHit(Offset position, Player player) =>
      trayRect(player).inflate(6).contains(position);
}
