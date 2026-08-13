import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../profile/profile.dart';
import 'paint.dart';

/// Аватар из набора (§P5). Ни одного ассета: розетка из ромбов рисуется
/// программно в той же национальной эстетике, что и орнамент доски (§7).
class NardaAvatarStyle {
  const NardaAvatarStyle({
    required this.background,
    required this.ink,
    required this.rays,
    this.ringed = false,
  });

  final Color background;
  final Color ink;

  /// Сколько лучей у розетки.
  final int rays;

  /// Дополнительное кольцо между розеткой и центром.
  final bool ringed;
}

/// Набор аватаров; длина совпадает с [nardaAvatarCount].
const List<NardaAvatarStyle> nardaAvatars = <NardaAvatarStyle>[
  NardaAvatarStyle(background: Color(0xFF3A2716), ink: Color(0xFFE8BC57), rays: 8),
  NardaAvatarStyle(background: Color(0xFF17384C), ink: Color(0xFF7FD0E8), rays: 6, ringed: true),
  NardaAvatarStyle(background: Color(0xFF4A2118), ink: Color(0xFFF0C9A0), rays: 4),
  NardaAvatarStyle(background: Color(0xFF1E3A2A), ink: Color(0xFF9BD6A4), rays: 6),
  NardaAvatarStyle(background: Color(0xFF3D1C33), ink: Color(0xFFE7A8D2), rays: 8, ringed: true),
  NardaAvatarStyle(background: Color(0xFF4C3A12), ink: Color(0xFFF3E4CB), rays: 4, ringed: true),
  NardaAvatarStyle(background: Color(0xFF1B2A46), ink: Color(0xFFA9BEEA), rays: 8),
  NardaAvatarStyle(background: Color(0xFF23170F), ink: Color(0xFFB79C7B), rays: 6, ringed: true),
];

/// Кружок с аватаром.
class NardaAvatar extends StatelessWidget {
  const NardaAvatar({super.key, required this.index, this.size = 40});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _AvatarPainter(
        nardaAvatars[index.clamp(0, nardaAvatars.length - 1)],
      ),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.style);

  final NardaAvatarStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = style.background);
    canvas.drawCircle(
      center,
      radius - radius * 0.06,
      strokePaint(style.ink.withValues(alpha: 0.7), radius * 0.08),
    );

    final Paint fill = Paint()..color = style.ink;
    for (int i = 0; i < style.rays; i++) {
      final double angle = 2 * math.pi * i / style.rays - math.pi / 2;
      final Offset petal = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 0.55);
      canvas.drawPath(_diamond(petal, radius * 0.2), fill);
    }

    if (style.ringed) {
      canvas.drawCircle(
        center,
        radius * 0.34,
        strokePaint(style.ink.withValues(alpha: 0.6), radius * 0.06),
      );
    }
    canvas.drawPath(_diamond(center, radius * 0.22), fill);
  }

  Path _diamond(Offset center, double radius) => Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius, center.dy)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - radius, center.dy)
    ..close();

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.style != style;
}
