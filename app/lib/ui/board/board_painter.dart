import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

import '../../theme/board_theme.dart';
import '../paint.dart';
import 'board_geometry.dart';
import 'ornament.dart';

/// Неподвижная часть доски: дерево, орнамент, пункты, лотки.
/// Живёт под [RepaintBoundary] и перерисовывается только при смене размера
/// или перспективы.
class BoardBackgroundPainter extends CustomPainter {
  const BoardBackgroundPainter({required this.geometry, required this.theme});

  final BoardGeometry geometry;
  final BoardTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (theme.wooden) {
      _paintWooden(canvas, size);
      return;
    }
    final Rect board = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, Radius.circular(geometry.frame * 0.7)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[theme.frameLight, theme.frameDark],
        ).createShader(board),
    );
    paintFrameOrnament(canvas, size, geometry.frame, theme);

    final Rect inner = geometry.inner;
    canvas.drawRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[theme.feltLight, theme.feltDark],
        ).createShader(inner),
    );
    _paintGrain(canvas, inner);

    for (final Player player in Player.values) {
      canvas.drawRRect(
        geometry.trayShape(player),
        Paint()..color = theme.frameDark.withValues(alpha: 0.55),
      );
    }

    canvas.drawRect(
      geometry.bar,
      Paint()..color = theme.frameDark.withValues(alpha: 0.85),
    );

    for (int abs = 1; abs <= Coords.pointCount; abs++) {
      _paintPoint(canvas, abs);
    }

    canvas.drawRect(inner, strokePaint(theme.frameDark, 2));
  }

  void _paintPoint(Canvas canvas, int abs) {
    final Rect rect = geometry.pointRect(abs);
    final bool bottom = geometry.isBottom(abs);
    final bool light = (geometry.columnOf(abs) + (bottom ? 0 : 1)).isEven;
    final Path path = geometry.pointPath(abs);
    final Color color = light ? theme.pointLight : theme.pointDark;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: bottom ? Alignment.bottomCenter : Alignment.topCenter,
          end: bottom ? Alignment.topCenter : Alignment.bottomCenter,
          colors: <Color>[color, Color.lerp(color, Colors.black, 0.22)!],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      strokePaint(theme.frameDark.withValues(alpha: 0.35), 1),
    );
  }

  /// Деревянный кейс: рамка, две створки, латунные петли, пункты-инкрустация с лунками.
  void _paintWooden(Canvas canvas, Size size) {
    final Rect board = Offset.zero & size;
    final double frame = geometry.frame;
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, Radius.circular(frame * 0.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[theme.frameLight, theme.frameDark],
        ).createShader(board),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(1), Radius.circular(frame * 0.5)),
      strokePaint(Colors.white.withValues(alpha: 0.12), 1.5),
    );

    final Rect inner = geometry.inner;
    final Rect bar = geometry.bar;
    final Paint surface = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[theme.feltLight, theme.feltDark],
      ).createShader(inner);
    for (final Rect half in <Rect>[
      Rect.fromLTRB(inner.left, inner.top, bar.left, inner.bottom),
      Rect.fromLTRB(bar.right, inner.top, inner.right, inner.bottom),
    ]) {
      canvas.drawRect(half, surface);
    }
    _paintGrain(canvas, inner);

    for (final Player player in Player.values) {
      canvas.drawRRect(
        geometry.trayShape(player),
        Paint()..color = theme.frameDark.withValues(alpha: 0.4),
      );
    }
    for (int abs = 1; abs <= Coords.pointCount; abs++) {
      _paintInlay(canvas, abs);
    }

    // Створки утоплены в рамку: тень по краю каждой.
    final Paint rim = strokePaint(Colors.black.withValues(alpha: 0.35), 3);
    canvas
      ..drawRect(Rect.fromLTRB(inner.left, inner.top, bar.left, inner.bottom), rim)
      ..drawRect(Rect.fromLTRB(bar.right, inner.top, inner.right, inner.bottom), rim);

    canvas.drawRect(
      bar,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[theme.frameDark, theme.frameLight, theme.frameDark],
        ).createShader(bar),
    );
    for (final double at in <double>[0.14, 0.86]) {
      _paintHinge(canvas, Offset(bar.center.dx, inner.top + inner.height * at));
    }
  }

  /// Пункт-инкрустация: светлый клин с тонкой обводкой и лунка у основания.
  void _paintInlay(Canvas canvas, int abs) {
    final Rect rect = geometry.pointRect(abs);
    final bool bottom = geometry.isBottom(abs);
    final bool light = (geometry.columnOf(abs) + (bottom ? 0 : 1)).isEven;
    final Path path = geometry.pointPath(abs);
    final Color color = light ? theme.pointLight : theme.pointDark;
    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: bottom ? Alignment.bottomCenter : Alignment.topCenter,
            end: bottom ? Alignment.topCenter : Alignment.bottomCenter,
            colors: <Color>[color, Color.lerp(color, theme.feltDark, 0.35)!],
          ).createShader(rect),
      )
      ..drawPath(path, strokePaint(theme.frameDark.withValues(alpha: 0.45), 1.2));

    final double radius = geometry.checkerRadius * 0.62;
    final Offset center = geometry.checkerCenter(abs, 0, 1);
    canvas
      ..drawCircle(center, radius, Paint()..color = theme.feltDark.withValues(alpha: 0.35))
      ..drawCircle(center, radius, strokePaint(theme.frameDark.withValues(alpha: 0.4), 1.2))
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0.2,
        math.pi * 0.8,
        false,
        strokePaint(Colors.white.withValues(alpha: 0.35), 1),
      );
  }

  /// Латунная петля поперёк «корешка» доски.
  void _paintHinge(Canvas canvas, Offset center) {
    final double width = geometry.barWidth * 1.5;
    final double height = geometry.inner.height * 0.08;
    final Rect rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(width * 0.12)),
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[Color(0xFF8A6A25), Color(0xFFE2C26A), Color(0xFF8A6A25)],
          ).createShader(rect),
      )
      ..drawLine(
        rect.topCenter,
        rect.bottomCenter,
        strokePaint(const Color(0xFF5E4515), 1.2),
      );
    final Paint screw = Paint()..color = const Color(0xFF6B4F1A);
    for (final double dx in <double>[-0.25, 0.25]) {
      for (final double dy in <double>[-0.3, 0.3]) {
        canvas.drawCircle(
          center + Offset(width * dx, height * dy),
          width * 0.06,
          screw,
        );
      }
    }
  }

  /// Древесные волокна: детерминированный рисунок, одинаковый на каждом кадре.
  void _paintGrain(Canvas canvas, Rect inner) {
    final math.Random random = math.Random(7);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(inner);
    for (int i = 0; i < 40; i++) {
      final double y = inner.top + inner.height * random.nextDouble();
      final double amplitude = inner.height * 0.01 * random.nextDouble();
      final Path path = Path()..moveTo(inner.left, y);
      for (double x = inner.left; x <= inner.right; x += inner.width / 8) {
        path.lineTo(x, y + math.sin(x / 40 + i) * amplitude);
      }
      paint.color = (i.isEven ? Colors.black : Colors.white).withValues(
        alpha: 0.04,
      );
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoardBackgroundPainter oldDelegate) =>
      oldDelegate.geometry.size != geometry.size ||
      oldDelegate.geometry.perspective != geometry.perspective ||
      oldDelegate.theme.id != theme.id;
}

/// Подвижная часть доски: шашки, подсветки, летящая шашка.
class BoardPiecesPainter extends CustomPainter {
  const BoardPiecesPainter({
    required this.geometry,
    required this.theme,
    required this.state,
    required this.selected,
    required this.destinations,
    this.pips = const <int?, int>{},
    required this.movable,
    required this.lastMoves,
    required this.flying,
    required this.progress,
    required this.dragFrom,
    required this.dragPosition,
  });

  final BoardGeometry geometry;
  final BoardTheme theme;
  final GameState state;

  /// Выбранный пункт отправления.
  final int? selected;

  /// Куда может пойти выбранная шашка; `null` — выброс.
  final List<int?> destinations;

  /// Цели, куда шашка дойдёт несколькими перемещениями — рисуются двойным кольцом.
  /// Очки костей на ход к каждой цели из [destinations].
  final Map<int?, int> pips;

  /// Пункты, с которых сейчас можно ходить.
  final Set<int> movable;

  /// Перемещения последнего завершённого хода.
  final List<Move> lastMoves;

  /// Летящая шашка и прогресс её анимации.
  final Move? flying;
  final double progress;

  /// Пункт, с которого тянут шашку, и текущая точка пальца.
  final int? dragFrom;
  final Offset? dragPosition;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLastMove(canvas);
    _paintDestinationGlow(canvas);
    _paintCheckers(canvas);
    // Поверх шашек: на высокой стопке маркер иначе прячется под ними.
    _paintDestinations(canvas);
    _paintTrays(canvas);
    _paintMoving(canvas);
  }

  void _paintLastMove(Canvas canvas) {
    if (lastMoves.isEmpty) return;
    final Paint paint = strokePaint(
      theme.highlight.withValues(alpha: 0.35),
      2,
    );
    for (final Move move in lastMoves) {
      canvas.drawPath(geometry.pointPath(move.fromAbs), paint);
      final int? toAbs = move.toAbs;
      if (toAbs != null) canvas.drawPath(geometry.pointPath(toAbs), paint);
    }
  }

  void _paintDestinationGlow(Canvas canvas) {
    final Paint glow = Paint()..color = theme.highlight.withValues(alpha: 0.3);
    for (final int? abs in destinations) {
      if (abs != null) canvas.drawPath(geometry.pointPath(abs), glow);
    }
  }

  void _paintDestinations(Canvas canvas) {
    if (destinations.isEmpty) return;
    final Player mover = state.turn;
    final double width = geometry.checkerRadius * 0.2;
    final Paint glow = Paint()..color = theme.highlight.withValues(alpha: 0.3);
    final Paint fill = Paint()..color = theme.highlight.withValues(alpha: 0.9);
    // Тёмная обводка под маркером: виден и на светлых, и на тёмных пунктах.
    final Paint halo = strokePaint(_halo, width * 2);
    final Paint marker = strokePaint(theme.highlight, width);
    for (final int? abs in destinations) {
      if (abs == null) {
        final RRect tray = geometry.trayShape(mover);
        canvas
          ..drawRRect(tray, glow)
          ..drawRRect(tray, halo)
          ..drawRRect(tray, marker);
        _paintPips(canvas, abs, tray.center);
        continue;
      }
      final int count = state.checkersAt(mover, abs);
      final Offset center = geometry.checkerCenter(abs, count, count + 1);
      final double radius = geometry.checkerRadius * 0.85;
      canvas
        ..drawCircle(center, radius, fill)
        ..drawCircle(center, radius, halo)
        ..drawCircle(center, radius, marker);
      _paintPips(canvas, abs, center);
    }
  }

  /// Сколько очков костей уйдёт на ход в эту цель: 3, 4 или 7 при 3-4.
  void _paintPips(Canvas canvas, int? abs, Offset center) {
    final int? value = pips[abs];
    if (value == null) return;
    paintCenteredText(
      canvas,
      '$value',
      center,
      TextStyle(
        color: const Color(0xE6000000),
        fontSize: geometry.checkerRadius * 0.95,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _paintCheckers(Canvas canvas) {
    for (int abs = 1; abs <= Coords.pointCount; abs++) {
      final int value = state.countAt(abs);
      if (value == 0) continue;
      final Player player = value > 0 ? Player.white : Player.black;
      final int count = value.abs();
      int visible = count;
      if (flying != null && !flying!.isBearOff && flying!.toAbs == abs) {
        visible--;
      }
      if (dragFrom == abs) visible--;
      for (int i = 0; i < visible; i++) {
        final bool top = i == visible - 1;
        paintChecker(
          canvas,
          theme: theme,
          center: geometry.checkerCenter(abs, i, count),
          radius: geometry.checkerRadius,
          player: player,
          label: top && visible > 5 ? '$visible' : null,
          ring: _ringFor(abs, top),
        );
      }
    }
  }

  Color? _ringFor(int abs, bool isTop) {
    if (!isTop) return null;
    if (abs == selected) return theme.highlight;
    if (movable.contains(abs)) return theme.highlight.withValues(alpha: 0.45);
    return null;
  }

  void _paintTrays(Canvas canvas) {
    for (final Player player in Player.values) {
      int count = state.borneOff(player);
      if (flying != null && flying!.isBearOff && flying!.player == player) {
        count--;
      }
      for (int i = 0; i < count; i++) {
        final Rect rect = geometry.trayCheckerRect(player, i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
          Paint()..color = theme.checkerFace(player),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
          strokePaint(theme.checkerEdge(player), 1),
        );
      }
    }
  }

  void _paintMoving(Canvas canvas) {
    final Move? move = flying;
    if (move != null && progress < 1) {
      final Offset from = _flyingSource(move);
      final Offset to = _flyingTarget(move);
      final Offset position =
          Offset.lerp(from, to, progress)! -
          Offset(0, math.sin(math.pi * progress) * geometry.checkerRadius);
      paintChecker(
        canvas,
        theme: theme,
        center: position,
        radius: geometry.checkerRadius * 1.05,
        player: move.player,
        elevated: true,
      );
    }
    final Offset? drag = dragPosition;
    if (dragFrom != null && drag != null) {
      paintChecker(
        canvas,
        theme: theme,
        center: drag,
        radius: geometry.checkerRadius * 1.15,
        player: state.turn,
        elevated: true,
      );
    }
  }

  /// Откуда вылетела шашка: её место в стопке до перемещения.
  Offset _flyingSource(Move move) {
    final int count = state.checkersAt(move.player, move.fromAbs);
    return geometry.checkerCenter(move.fromAbs, count, count + 1);
  }

  /// Куда она садится: верхнее место в стопке назначения или лоток.
  Offset _flyingTarget(Move move) {
    final int? toAbs = move.toAbs;
    if (toAbs == null) {
      return geometry
          .trayCheckerRect(move.player, state.borneOff(move.player) - 1)
          .center;
    }
    final int count = state.checkersAt(move.player, toAbs);
    return geometry.checkerCenter(toAbs, count - 1, count);
  }

  @override
  bool shouldRepaint(BoardPiecesPainter oldDelegate) => true;
}

/// Одна шашка: кремовая или тёмно-красная, с фаской и тенью (§7).
void paintChecker(
  Canvas canvas, {
  required BoardTheme theme,
  required Offset center,
  required double radius,
  required Player player,
  String? label,
  Color? ring,
  bool elevated = false,
}) {
  final Color face = theme.checkerFace(player);
  final Color edge = theme.checkerEdge(player);

  canvas.drawCircle(
    center.translate(0, elevated ? radius * 0.35 : radius * 0.12),
    radius * (elevated ? 1.0 : 0.95),
    Paint()
      ..color = Colors.black.withValues(alpha: elevated ? 0.35 : 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader =
          RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: <Color>[Color.lerp(face, Colors.white, 0.35)!, face],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius),
          ),
  );
  canvas.drawCircle(
    center,
    radius * 0.92,
    strokePaint(edge.withValues(alpha: 0.75), radius * 0.16),
  );
  canvas.drawCircle(
    center,
    radius * 0.5,
    strokePaint(edge.withValues(alpha: 0.35), radius * 0.08),
  );
  // Контрастный ободок: шашка отделяется от пункта любого цвета.
  canvas.drawCircle(
    center,
    radius * 0.97,
    strokePaint(
      face.computeLuminance() > 0.4
          ? const Color(0x8C000000)
          : const Color(0x73FFFFFF),
      radius * 0.07,
    ),
  );
  if (ring != null) {
    canvas
      ..drawCircle(
        center,
        radius * 1.08,
        strokePaint(_halo.withValues(alpha: _halo.a * ring.a), radius * 0.4),
      )
      ..drawCircle(center, radius * 1.08, strokePaint(ring, radius * 0.2));
  }
  if (label != null) {
    paintCenteredText(
      canvas,
      label,
      center,
      TextStyle(
        color: theme.checkerLabel(player),
        fontSize: radius * 0.95,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Подложка маркеров подсветки — контраст к любому цвету доски.
const Color _halo = Color(0x99000000);
