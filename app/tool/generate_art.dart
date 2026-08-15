// Генератор графики магазина и иконок приложения.
//
// Рисуется тем же способом, что и доска, — программно, без единой чужой
// текстуры и без чужих брендов (§7, §P3). Запуск:
//
//   cd app && flutter test tool/generate_art.dart
//
// Что появляется:
//   android/app/src/main/res/mipmap-*/ic_launcher.png       — иконка
//   android/app/src/main/res/mipmap-*/ic_launcher_fore.png  — слой adaptive
//   store/icon-512.png                                      — иконка листинга
//   store/feature-graphic-1024x500.png                      — feature graphic
//
// Файл лежит в tool/, а не в test/, чтобы `flutter test` не перерисовывал
// ассеты на каждом прогоне.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/theme/board_theme.dart';
import 'package:narda/theme/narda_theme.dart';
import 'package:narda/ui/paint.dart';

/// Плотности Android: mdpi 48 dp → xxxhdpi 192 dp.
const Map<String, double> _densities = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('иконка и графика стора', () async {
    await _loadRoboto();
    const BoardTheme theme = klassikTheme;

    for (final MapEntry<String, double> entry in _densities.entries) {
      final Directory dir = Directory(
        'android/app/src/main/res/mipmap-${entry.key}',
      )..createSync(recursive: true);
      final int legacy = (48 * entry.value).round();
      await _write(
        '${dir.path}/ic_launcher.png',
        legacy,
        legacy,
        (Canvas canvas, Size size) =>
            _paintIcon(canvas, size, theme, rounded: true),
      );
      // Adaptive icon: передний слой прозрачный, фон задаётся цветом.
      final int adaptive = (108 * entry.value).round();
      await _write(
        '${dir.path}/ic_launcher_foreground.png',
        adaptive,
        adaptive,
        (Canvas canvas, Size size) => _paintIconForeground(canvas, size, theme),
      );
    }

    Directory('store').createSync(recursive: true);
    await _write(
      'store/icon-512.png',
      512,
      512,
      (Canvas canvas, Size size) =>
          _paintIcon(canvas, size, theme, rounded: false),
    );
    await _write(
      'store/feature-graphic-1024x500.png',
      1024,
      500,
      (Canvas canvas, Size size) => _paintFeatureGraphic(canvas, size, theme),
    );
  });
}

/// Подгружает Roboto из кэша Flutter (Apache-2.0, поставляется с SDK).
/// Без этого `flutter test` рисует текст заглушечным шрифтом-«кирпичами».
Future<void> _loadRoboto() async {
  final Directory? fonts = _materialFontsDir();
  if (fonts == null) {
    fail('не найден material_fonts в кэше Flutter — feature graphic будет без текста');
  }
  final FontLoader loader = FontLoader(_fontFamily);
  for (final String name in <String>['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final File file = File('${fonts.path}/$name');
    if (!file.existsSync()) continue;
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
}

const String _fontFamily = 'NardaStoreRoboto';

/// Ищет material_fonts, поднимаясь от dart-бинарника к корню Flutter.
Directory? _materialFontsDir() {
  Directory dir = File(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 8; i++) {
    final Directory candidate = Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    );
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Future<void> _write(
  String path,
  int width,
  int height,
  void Function(Canvas canvas, Size size) paint,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Size size = Size(width.toDouble(), height.toDouble());
  paint(canvas, size);
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('$path  $width×$height');
}

/// Иконка: тёплое дерево, орнаментальная рамка, восьмиконечная звезда и кость.
void _paintIcon(
  Canvas canvas,
  Size size,
  BoardTheme theme, {
  required bool rounded,
}) {
  final Rect rect = Offset.zero & size;
  if (rounded) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.22)),
    );
  }
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.1,
        colors: <Color>[theme.frameLight, theme.frameDark],
      ).createShader(rect),
  );
  _ornamentBorder(canvas, size, theme);
  _star(canvas, rect.center, size.width * 0.32, theme);
  _die(
    canvas,
    Rect.fromCenter(
      center: rect.center,
      width: size.width * 0.32,
      height: size.width * 0.32,
    ),
    theme,
  );
}

/// Передний слой adaptive-иконки: то же самое, но без фона и в безопасной зоне.
void _paintIconForeground(Canvas canvas, Size size, BoardTheme theme) {
  final Offset center = Offset(size.width / 2, size.height / 2);
  _star(canvas, center, size.width * 0.21, theme);
  _die(
    canvas,
    Rect.fromCenter(
      center: center,
      width: size.width * 0.21,
      height: size.width * 0.21,
    ),
    theme,
  );
}

/// Цепочка ромбов по краю — тот же мотив, что на рамке доски.
void _ornamentBorder(Canvas canvas, Size size, BoardTheme theme) {
  final double band = size.width * 0.13;
  final Paint line = strokePaint(
    theme.ornament.withValues(alpha: 0.75),
    math.max(1, size.width * 0.012),
  );
  final Paint fill = Paint()
    ..color = theme.ornamentFill.withValues(alpha: 0.6);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(band * 0.62),
      Radius.circular(size.width * 0.13),
    ),
    line,
  );

  const int count = 6;
  final double step = size.width / count;
  for (int i = 0; i < count; i++) {
    final double offset = step * (i + 0.5);
    for (final Offset center in <Offset>[
      Offset(offset, band * 0.3),
      Offset(offset, size.height - band * 0.3),
      Offset(band * 0.3, offset),
      Offset(size.width - band * 0.3, offset),
    ]) {
      canvas.drawPath(diamondPath(center, band * 0.22), line);
      canvas.drawPath(diamondPath(center, band * 0.1), fill);
    }
  }
}

/// Восьмиконечная звезда — узнаваемый узбекский мотив.
void _star(Canvas canvas, Offset center, double radius, BoardTheme theme) {
  final Path path = Path();
  const int points = 8;
  for (int i = 0; i < points * 2; i++) {
    final double angle = math.pi * i / points - math.pi / 2;
    final double r = i.isEven ? radius : radius * 0.45;
    final Offset point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()..color = theme.ornamentFill.withValues(alpha: 0.85),
  );
  canvas.drawPath(path, strokePaint(theme.ornament, radius * 0.07));
}

/// Игральная кость с пятёркой — сразу читается как нарды.
void _die(Canvas canvas, Rect rect, BoardTheme theme) {
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  canvas.rotate(-0.18);
  canvas.translate(-rect.center.dx, -rect.center.dy);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.08),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(theme.dieFace, Colors.white, 0.4)!,
          theme.dieFace,
        ],
      ).createShader(rect),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2)),
    strokePaint(theme.dieEdge, rect.width * 0.06),
  );
  const List<Offset> pips = <Offset>[
    Offset(0.28, 0.28),
    Offset(0.72, 0.28),
    Offset(0.5, 0.5),
    Offset(0.28, 0.72),
    Offset(0.72, 0.72),
  ];
  for (final Offset pip in pips) {
    canvas.drawCircle(
      Offset(rect.left + pip.dx * rect.width, rect.top + pip.dy * rect.height),
      rect.width * 0.085,
      Paint()..color = theme.diePip,
    );
  }
  canvas.restore();
}

/// Feature graphic 1024×500: название слева, фрагмент доски справа.
void _paintFeatureGraphic(Canvas canvas, Size size, BoardTheme theme) {
  final Rect rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[theme.frameLight, NardaColors.background],
      ).createShader(rect),
  );

  // Полосы орнамента сверху и снизу.
  for (final double y in <double>[size.height * 0.055, size.height * 0.945]) {
    final Paint line = strokePaint(
      theme.ornament.withValues(alpha: 0.5),
      2,
    );
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    for (double x = size.width * 0.02; x < size.width; x += size.width * 0.035) {
      canvas.drawPath(diamondPath(Offset(x, y), size.height * 0.022), line);
    }
  }

  // Доска: половина с пунктами и шашками.
  final Rect board = Rect.fromLTWH(
    size.width * 0.56,
    size.height * 0.16,
    size.width * 0.40,
    size.height * 0.68,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(board.inflate(10), const Radius.circular(14)),
    Paint()..color = theme.frameDark,
  );
  canvas.drawRect(
    board,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[theme.feltLight, theme.feltDark],
      ).createShader(board),
  );
  const int columns = 6;
  final double column = board.width / columns;
  for (int i = 0; i < columns; i++) {
    final Color color = i.isEven ? theme.pointLight : theme.pointDark;
    canvas.drawPath(
      Path()
        ..moveTo(board.left + column * i, board.top)
        ..lineTo(board.left + column * (i + 1), board.top)
        ..lineTo(board.left + column * (i + 0.5), board.top + board.height * 0.44)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(board.left + column * i, board.bottom)
        ..lineTo(board.left + column * (i + 1), board.bottom)
        ..lineTo(board.left + column * (i + 0.5), board.bottom - board.height * 0.44)
        ..close(),
      Paint()..color = i.isEven ? theme.pointDark : theme.pointLight,
    );
  }
  final double radius = column * 0.34;
  for (int i = 0; i < 3; i++) {
    canvas.drawCircle(
      Offset(board.left + column * 0.5, board.top + radius * (1.2 + 1.8 * i)),
      radius,
      Paint()..color = theme.checkerWhiteFace,
    );
    canvas.drawCircle(
      Offset(board.right - column * 0.5, board.bottom - radius * (1.2 + 1.8 * i)),
      radius,
      Paint()..color = theme.checkerBlackFace,
    );
  }

  _die(
    canvas,
    Rect.fromLTWH(size.width * 0.50, size.height * 0.56, 84, 84),
    theme,
  );

  _text(
    canvas,
    'Uzun narda',
    Offset(size.width * 0.06, size.height * 0.30),
    fontSize: 84,
    color: NardaColors.gold,
    weight: FontWeight.w800,
  );
  _text(
    canvas,
    "O'zbek nardasi",
    Offset(size.width * 0.06, size.height * 0.47),
    fontSize: 38,
    color: NardaColors.textPrimary,
    weight: FontWeight.w500,
  );
  _text(
    canvas,
    'Bot · Bitta qurilmada · Oflayn',
    Offset(size.width * 0.06, size.height * 0.60),
    fontSize: 26,
    color: NardaColors.textMuted,
    weight: FontWeight.w400,
  );
}

void _text(
  Canvas canvas,
  String value,
  Offset topLeft, {
  required double fontSize,
  required Color color,
  required FontWeight weight,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontFamily: _fontFamily,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: fontSize * 0.02,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, topLeft);
}
