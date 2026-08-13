import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/gen/app_text.dart';
import '../theme/board_theme.dart';
import '../theme/narda_theme.dart';
import 'chrome.dart';

/// Обучение «Qoidalar»: восемь разделов правил, у каждого — своя картинка
/// (§P3). Картинки рисуются тем же способом, что и доска: CustomPaint.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppText text = AppText.of(context);
    final BoardTheme theme = SettingsScope.of(context).boardTheme;
    final List<_RuleCard> cards = <_RuleCard>[
      _RuleCard(text.rulesGoalTitle, text.rulesGoalBody, RuleFigure.goal),
      _RuleCard(text.rulesStartTitle, text.rulesStartBody, RuleFigure.start),
      _RuleCard(text.rulesMoveTitle, text.rulesMoveBody, RuleFigure.move),
      _RuleCard(text.rulesHeadTitle, text.rulesHeadBody, RuleFigure.head),
      _RuleCard(text.rulesFullTitle, text.rulesFullBody, RuleFigure.full),
      _RuleCard(text.rulesBlockTitle, text.rulesBlockBody, RuleFigure.block),
      _RuleCard(
        text.rulesBearOffTitle,
        text.rulesBearOffBody,
        RuleFigure.bearOff,
      ),
      _RuleCard(text.rulesResultTitle, text.rulesResultBody, RuleFigure.result),
    ];
    return Scaffold(
      appBar: NardaAppBar(title: text.rulesTitle),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: cards.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 14),
        itemBuilder: (BuildContext context, int index) {
          final _RuleCard card = cards[index];
          return Container(
            decoration: BoxDecoration(
              color: NardaColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 2.6,
                  child: CustomPaint(
                    painter: RuleFigurePainter(
                      figure: card.figure,
                      theme: theme,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${index + 1}. ${card.title}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: NardaColors.gold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.body,
                        style: const TextStyle(
                          color: NardaColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RuleCard {
  const _RuleCard(this.title, this.body, this.figure);

  final String title;
  final String body;
  final RuleFigure figure;
}

/// Какую картинку рисовать к разделу.
enum RuleFigure { goal, start, move, head, full, block, bearOff, result }


/// Картинки к правилам: полоска доски с пунктами, поверх которой добавляется
/// сюжет раздела — стрелки маршрута, забор из шести пунктов, лоток выброса.
class RuleFigurePainter extends CustomPainter {
  const RuleFigurePainter({required this.figure, required this.theme});

  final RuleFigure figure;
  final BoardTheme theme;

  static const int _points = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[theme.feltLight, theme.feltDark],
        ).createShader(rect),
    );

    final double width = size.width / _points;
    final double pointHeight = size.height * 0.52;
    for (int i = 0; i < _points; i++) {
      final Path path = Path()
        ..moveTo(width * i + width * 0.08, 0)
        ..lineTo(width * (i + 1) - width * 0.08, 0)
        ..lineTo(width * (i + 0.5), pointHeight)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = (i.isEven ? theme.pointLight : theme.pointDark)
          .withValues(alpha: 0.9),
      );
    }

    switch (figure) {
      case RuleFigure.goal:
        _bearOffTray(canvas, size, filled: 4);
        _checkers(canvas, size, <int>[1, 2, 2, 3], white: true);
        _arrow(canvas, size, from: 3.5, to: 7.4);
      case RuleFigure.start:
        _stack(canvas, size, column: 0, count: 5, white: true);
        _stack(canvas, size, column: 4, count: 5, white: false);
        _arrow(canvas, size, from: 0.5, to: 3.5);
        _arrow(canvas, size, from: 4.5, to: 7.5);
      case RuleFigure.move:
        _checkers(canvas, size, <int>[0, 0], white: true);
        _checkers(canvas, size, <int>[5], white: false);
        _arrow(canvas, size, from: 0.5, to: 2.5);
        _arrow(canvas, size, from: 2.5, to: 4.5);
        _cross(canvas, size, column: 5);
      case RuleFigure.head:
        _stack(canvas, size, column: 0, count: 5, white: true);
        _arrow(canvas, size, from: 0.5, to: 3.5);
        _cross(canvas, size, column: 2);
      case RuleFigure.full:
        _checkers(canvas, size, <int>[1], white: true);
        _arrow(canvas, size, from: 1.5, to: 4.5, label: '6');
        _arrow(canvas, size, from: 4.5, to: 6.5, label: '4');
      case RuleFigure.block:
        for (int i = 1; i <= 6; i++) {
          _stack(canvas, size, column: i, count: 2, white: true);
        }
        _fence(canvas, size, fromColumn: 1, toColumn: 6);
        _checkers(canvas, size, <int>[0], white: false);
      case RuleFigure.bearOff:
        _checkers(canvas, size, <int>[0, 1, 2, 3], white: true);
        _bearOffTray(canvas, size, filled: 2);
        _arrow(canvas, size, from: 0.5, to: 7.4);
      case RuleFigure.result:
        _bearOffTray(canvas, size, filled: 6);
        _checkers(canvas, size, <int>[1], white: true);
        _arrow(canvas, size, from: 1.5, to: 7.4);
    }
  }

  /// Стопка шашек на пункте [column].
  void _stack(
    Canvas canvas,
    Size size, {
    required int column,
    required int count,
    required bool white,
  }) {
    final double width = size.width / _points;
    final double radius = width * 0.34;
    for (int i = 0; i < count; i++) {
      _checker(
        canvas,
        Offset(width * (column + 0.5), radius * 1.1 + radius * 1.7 * i),
        radius,
        white,
      );
    }
  }

  /// По одной шашке на каждый пункт из [columns] (повтор — вторая в стопке).
  void _checkers(
    Canvas canvas,
    Size size,
    List<int> columns, {
    required bool white,
  }) {
    final Map<int, int> heights = <int, int>{};
    final double width = size.width / _points;
    final double radius = width * 0.34;
    for (final int column in columns) {
      final int level = heights.update(
        column,
        (int value) => value + 1,
        ifAbsent: () => 0,
      );
      _checker(
        canvas,
        Offset(
          width * (column + 0.5),
          size.height - radius * 1.2 - radius * 1.7 * level,
        ),
        radius,
        white,
      );
    }
  }

  void _checker(Canvas canvas, Offset center, double radius, bool white) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = white ? theme.checkerWhiteFace : theme.checkerBlackFace,
    );
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22
        ..color = white ? theme.checkerWhiteEdge : theme.checkerBlackEdge,
    );
  }

  /// Стрелка маршрута с необязательной подписью числа кубика.
  void _arrow(
    Canvas canvas,
    Size size, {
    required double from,
    required double to,
    String? label,
  }) {
    final double width = size.width / _points;
    final double y = size.height * 0.62;
    final Offset start = Offset(width * from, y);
    final Offset end = Offset(width * to, y);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.035
      ..strokeCap = StrokeCap.round
      ..color = theme.highlight;
    final Path path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        y - size.height * 0.26,
        end.dx,
        end.dy,
      );
    canvas.drawPath(path, paint);
    final double head = size.height * 0.09;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - head, end.dy - head * 0.75)
        ..lineTo(end.dx - head, end.dy + head * 0.75)
        ..close(),
      Paint()..color = theme.highlight,
    );
    if (label == null) return;
    _label(
      canvas,
      label,
      Offset((start.dx + end.dx) / 2, y - size.height * 0.22),
      size.height * 0.18,
    );
  }

  /// Запрещающий крест над пунктом.
  void _cross(Canvas canvas, Size size, {required int column}) {
    final double width = size.width / _points;
    final Offset center = Offset(width * (column + 0.5), size.height * 0.34);
    final double arm = width * 0.22;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE05B4B);
    canvas.drawLine(center.translate(-arm, -arm), center.translate(arm, arm), paint);
    canvas.drawLine(center.translate(arm, -arm), center.translate(-arm, arm), paint);
  }

  /// Забор из шести подряд занятых пунктов.
  void _fence(
    Canvas canvas,
    Size size, {
    required int fromColumn,
    required int toColumn,
  }) {
    final double width = size.width / _points;
    final Rect rect = Rect.fromLTRB(
      width * fromColumn + width * 0.05,
      size.height * 0.06,
      width * (toColumn + 1) - width * 0.05,
      size.height * 0.94,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.08)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.035
        ..color = const Color(0xFFE05B4B),
    );
    _label(canvas, '6', Offset(rect.center.dx, rect.top - size.height * 0.02), size.height * 0.16);
  }

  /// Лоток выброса справа с уже снятыми шашками.
  void _bearOffTray(Canvas canvas, Size size, {required int filled}) {
    final double width = size.width / _points;
    final Rect tray = Rect.fromLTRB(
      size.width - width * 0.95,
      size.height * 0.06,
      size.width - width * 0.08,
      size.height * 0.94,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tray, Radius.circular(size.height * 0.06)),
      Paint()..color = theme.frameDark.withValues(alpha: 0.75),
    );
    final double slot = tray.height / 7;
    for (int i = 0; i < filled; i++) {
      final Rect piece = Rect.fromLTWH(
        tray.left + tray.width * 0.12,
        tray.bottom - slot * (i + 1) + slot * 0.15,
        tray.width * 0.76,
        slot * 0.7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(piece, Radius.circular(piece.height / 2)),
        Paint()..color = theme.checkerWhiteFace,
      );
    }
  }

  void _label(Canvas canvas, String value, Offset center, double fontSize) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: theme.highlight,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(RuleFigurePainter oldDelegate) =>
      oldDelegate.figure != figure || oldDelegate.theme.id != theme.id;
}
