import 'package:flutter/painting.dart';

/// Кисть обводки: стиль, толщина и цвет одной строкой.
///
/// Всё в приложении рисуется программно (§7), поэтому одна и та же тройка
/// `..style ..strokeWidth ..color` повторялась во всех painter'ах — от доски
/// и костей до аватаров и картинок к правилам.
/// Ромб — основной мотив оформления: из него собраны цепочка на рамке доски,
/// розетка аватара и цепочка на иконке приложения (§7).
Path diamondPath(Offset center, double radius) => Path()
  ..moveTo(center.dx, center.dy - radius)
  ..lineTo(center.dx + radius, center.dy)
  ..lineTo(center.dx, center.dy + radius)
  ..lineTo(center.dx - radius, center.dy)
  ..close();

Paint strokePaint(Color color, double width, {StrokeCap? cap}) {
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color;
  if (cap != null) paint.strokeCap = cap;
  return paint;
}
