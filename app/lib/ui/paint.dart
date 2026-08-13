import 'package:flutter/painting.dart';

/// Кисть обводки: стиль, толщина и цвет одной строкой.
///
/// Всё в приложении рисуется программно (§7), поэтому одна и та же тройка
/// `..style ..strokeWidth ..color` повторялась во всех painter'ах — от доски
/// и костей до аватаров и картинок к правилам.
Paint strokePaint(Color color, double width, {StrokeCap? cap}) {
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color;
  if (cap != null) paint.strokeCap = cap;
  return paint;
}
