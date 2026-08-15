import 'package:flutter/painting.dart';

/// Кисть обводки: стиль, толщина и цвет одной строкой.
///
/// Всё в приложении рисуется программно (§7), поэтому одна и та же тройка
/// `..style ..strokeWidth ..color` повторялась во всех painter'ах — от доски
/// и костей до аватаров и картинок к правилам.
/// Плоская шашка: круг с кольцом-фаской, без тени и градиента.
///
/// Такими рисуются шашки на картинках к правилам и в превью тем —
/// объёмная шашка доски живёт в `board/board_painter.dart`.
void paintFlatChecker(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color face,
  required Color edge,
  double ringScale = 0.9,
  double ringWidth = 0.2,
}) {
  canvas
    ..drawCircle(center, radius, Paint()..color = face)
    ..drawCircle(
      center,
      radius * ringScale,
      strokePaint(edge, radius * ringWidth),
    );
}

/// Подпись, центрированная по точке: счёт шашек в стопке, число кубика
/// на картинке к правилам.
void paintCenteredText(
  Canvas canvas,
  String value,
  Offset center,
  TextStyle style,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

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
