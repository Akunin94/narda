import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/board_theme.dart';
import '../paint.dart';

/// Узбекский геометрический орнамент по рамке доски: цепочка ромбов с
/// внутренним ромбом и точками между ними. Рисуется программно, никаких
/// заимствованных текстур (§7).
void paintFrameOrnament(Canvas canvas, Size size, double frame, BoardTheme theme) {
  final Paint line = strokePaint(
    theme.ornament.withValues(alpha: 0.55),
    math.max(1, frame * 0.06),
  );
  final Paint fill = Paint()..color = theme.ornamentFill.withValues(alpha: 0.45);

  final double inset = frame * 0.18;
  final Rect outline = Rect.fromLTWH(
    inset,
    inset,
    size.width - 2 * inset,
    size.height - 2 * inset,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(outline, Radius.circular(frame * 0.35)),
    line,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        frame - inset,
        frame - inset,
        size.width - 2 * (frame - inset),
        size.height - 2 * (frame - inset),
      ),
      Radius.circular(frame * 0.2),
    ),
    line,
  );

  _paintChain(
    canvas,
    Rect.fromLTWH(frame, 0, size.width - 2 * frame, frame),
    horizontal: true,
    line: line,
    fill: fill,
  );
  _paintChain(
    canvas,
    Rect.fromLTWH(frame, size.height - frame, size.width - 2 * frame, frame),
    horizontal: true,
    line: line,
    fill: fill,
  );
  _paintChain(
    canvas,
    Rect.fromLTWH(0, frame, frame, size.height - 2 * frame),
    horizontal: false,
    line: line,
    fill: fill,
  );
  _paintChain(
    canvas,
    Rect.fromLTWH(size.width - frame, frame, frame, size.height - 2 * frame),
    horizontal: false,
    line: line,
    fill: fill,
  );
}

/// Цепочка мотивов вдоль полосы [band]; размер мотива равен её толщине.
void _paintChain(
  Canvas canvas,
  Rect band, {
  required bool horizontal,
  required Paint line,
  required Paint fill,
}) {
  final double step = horizontal ? band.height : band.width;
  final double length = horizontal ? band.width : band.height;
  final int count = (length / step).floor();
  if (count <= 0) return;
  final double pad = (length - count * step) / 2;

  for (int i = 0; i < count; i++) {
    final double offset = pad + step * (i + 0.5);
    final Offset center = horizontal
        ? Offset(band.left + offset, band.center.dy)
        : Offset(band.center.dx, band.top + offset);
    canvas.drawPath(diamondPath(center, step * 0.32), line);
    canvas.drawPath(diamondPath(center, step * 0.14), fill);
    final Offset gap = horizontal
        ? Offset(center.dx + step / 2, center.dy)
        : Offset(center.dx, center.dy + step / 2);
    if (i < count - 1) {
      canvas.drawCircle(gap, step * 0.05, fill);
    }
  }
}
