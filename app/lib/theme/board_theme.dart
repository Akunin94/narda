import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

/// Оформление доски и костей. Всё рисуется программно: ни одной заимствованной
/// текстуры (§7). Классика бесплатна всегда, две остальные открываются за
/// просмотр rewarded-ролика на 24 часа (§P3).
@immutable
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.free,
    required this.frameDark,
    required this.frameLight,
    required this.feltDark,
    required this.feltLight,
    required this.pointLight,
    required this.pointDark,
    required this.checkerWhiteFace,
    required this.checkerWhiteEdge,
    required this.checkerBlackFace,
    required this.checkerBlackEdge,
    required this.ornament,
    required this.ornamentFill,
    required this.highlight,
    required this.dieFace,
    required this.dieEdge,
    required this.diePip,
  });

  /// Ключ темы: он же ключ строки локализации и ключ разблокировки в настройках.
  final String id;

  /// Доступна без просмотра ролика.
  final bool free;

  final Color frameDark;
  final Color frameLight;
  final Color feltDark;
  final Color feltLight;
  final Color pointLight;
  final Color pointDark;

  final Color checkerWhiteFace;
  final Color checkerWhiteEdge;
  final Color checkerBlackFace;
  final Color checkerBlackEdge;

  final Color ornament;
  final Color ornamentFill;

  /// Золотая (или иная) подсветка легальных ходов.
  final Color highlight;

  final Color dieFace;
  final Color dieEdge;
  final Color diePip;

  Color checkerFace(Player player) =>
      player == Player.white ? checkerWhiteFace : checkerBlackFace;

  Color checkerEdge(Player player) =>
      player == Player.white ? checkerWhiteEdge : checkerBlackEdge;

  /// Цифра на верхней шашке высокой стопки: контрастна к её лицевой стороне.
  Color checkerLabel(Player player) =>
      player == Player.white ? checkerBlackEdge : checkerWhiteFace;
}

/// Классика — тёплое дерево, кремовые и тёмно-красные шашки (§7).
const BoardTheme klassikTheme = BoardTheme(
  id: 'klassik',
  free: true,
  frameDark: Color(0xFF4A2B18),
  frameLight: Color(0xFF7A4A28),
  feltDark: Color(0xFF8B5A2B),
  feltLight: Color(0xFFB07A44),
  pointLight: Color(0xFFE6CEA6),
  pointDark: Color(0xFF9B3B2C),
  checkerWhiteFace: Color(0xFFF4E6C8),
  checkerWhiteEdge: Color(0xFFB9975F),
  checkerBlackFace: Color(0xFF7E2B22),
  checkerBlackEdge: Color(0xFF421009),
  ornament: Color(0xFFE8BC57),
  ornamentFill: Color(0xFFA9781F),
  highlight: Color(0xFFE8BC57),
  dieFace: Color(0xFFF4E6C8),
  dieEdge: Color(0xFFB9975F),
  diePip: Color(0xFF421009),
);

/// «Ko'k gumbaz» — синий купол: кобальт и бирюза с белым орнаментом.
const BoardTheme kokGumbazTheme = BoardTheme(
  id: 'kok_gumbaz',
  free: false,
  frameDark: Color(0xFF10314F),
  frameLight: Color(0xFF1D5B85),
  feltDark: Color(0xFF15496B),
  feltLight: Color(0xFF2C7FA8),
  pointLight: Color(0xFFE8F1F4),
  pointDark: Color(0xFF0E7C86),
  checkerWhiteFace: Color(0xFFF2F6F7),
  checkerWhiteEdge: Color(0xFF8FA9B4),
  checkerBlackFace: Color(0xFF123E63),
  checkerBlackEdge: Color(0xFF061C30),
  ornament: Color(0xFFEFE3C2),
  ornamentFill: Color(0xFF9FD5DE),
  highlight: Color(0xFFF3C969),
  dieFace: Color(0xFFF2F6F7),
  dieEdge: Color(0xFF8FA9B4),
  diePip: Color(0xFF0B2B45),
);

/// «Zar» — тёмный орех с золотом и гранатовыми шашками.
const BoardTheme zarTheme = BoardTheme(
  id: 'zar',
  free: false,
  frameDark: Color(0xFF1B1410),
  frameLight: Color(0xFF3A2A1B),
  feltDark: Color(0xFF14352C),
  feltLight: Color(0xFF23584A),
  pointLight: Color(0xFFD9BC7E),
  pointDark: Color(0xFF6E1F22),
  checkerWhiteFace: Color(0xFFEFE1BE),
  checkerWhiteEdge: Color(0xFF9A7B3B),
  checkerBlackFace: Color(0xFF2B2724),
  checkerBlackEdge: Color(0xFF0D0B0A),
  ornament: Color(0xFFF0CE7A),
  ornamentFill: Color(0xFFB98C42),
  highlight: Color(0xFFF0CE7A),
  dieFace: Color(0xFFEFE1BE),
  dieEdge: Color(0xFF9A7B3B),
  diePip: Color(0xFF2B2724),
);

/// Все темы: классика первой (§P3 — «2 темы + классика»).
const List<BoardTheme> boardThemes = <BoardTheme>[
  klassikTheme,
  kokGumbazTheme,
  zarTheme,
];

BoardTheme boardThemeById(String id) => boardThemes.firstWhere(
  (BoardTheme theme) => theme.id == id,
  orElse: () => klassikTheme,
);
