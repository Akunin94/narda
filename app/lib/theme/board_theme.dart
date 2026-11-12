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
    this.wooden = false,
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

  /// Подсветка легальных ходов: яркий цвет, контрастный к пунктам темы.
  final Color highlight;

  final Color dieFace;
  final Color dieEdge;
  final Color diePip;

  /// Живая деревянная доска: инкрустированные пункты, лунки и петли вместо орнамента.
  final bool wooden;

  Color checkerFace(Player player) =>
      player == Player.white ? checkerWhiteFace : checkerBlackFace;

  Color checkerEdge(Player player) =>
      player == Player.white ? checkerWhiteEdge : checkerBlackEdge;

  /// Цифра на верхней шашке высокой стопки: контрастна к её лицевой стороне.
  Color checkerLabel(Player player) =>
      player == Player.white ? checkerBlackEdge : checkerWhiteFace;
}

/// «Yog'och» — как настоящий деревянный кейс: светлое дерево, пункты-инкрустация.
const BoardTheme yogochTheme = BoardTheme(
  id: 'yogoch',
  free: true,
  wooden: true,
  frameDark: Color(0xFF4A2814),
  frameLight: Color(0xFF7E4B26),
  feltDark: Color(0xFFB27A3E),
  feltLight: Color(0xFFCF9A5A),
  pointLight: Color(0xFFE2BC82),
  pointDark: Color(0xFFD6AD70),
  checkerWhiteFace: Color(0xFFF3E7CB),
  checkerWhiteEdge: Color(0xFFB8975E),
  checkerBlackFace: Color(0xFF9C2A22),
  checkerBlackEdge: Color(0xFF55130D),
  ornament: Color(0xFFD9B26A),
  ornamentFill: Color(0xFFB08A3E),
  highlight: Color(0xFF4FD8FF),
  dieFace: Color(0xFFF6EEDB),
  dieEdge: Color(0xFFB8975E),
  diePip: Color(0xFF3A1A0E),
);

/// Классика — тёплое дерево, кремовые и тёмно-красные шашки (§7).
const BoardTheme klassikTheme = BoardTheme(
  id: 'klassik',
  free: true,
  frameDark: Color(0xFF4A2B18),
  frameLight: Color(0xFF7A4A28),
  feltDark: Color(0xFF8B5A2B),
  feltLight: Color(0xFFB07A44),
  // Пункты другого тона, чем шашки: медовый и тёмно-зелёный.
  pointLight: Color(0xFFD8B06A),
  pointDark: Color(0xFF2F4F3A),
  checkerWhiteFace: Color(0xFFF4E6C8),
  checkerWhiteEdge: Color(0xFFB9975F),
  checkerBlackFace: Color(0xFF7E2B22),
  checkerBlackEdge: Color(0xFF421009),
  ornament: Color(0xFFE8BC57),
  ornamentFill: Color(0xFFA9781F),
  highlight: Color(0xFF4FD8FF),
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
  // Шафран и терракота — не сливаются ни с белыми, ни с синими шашками.
  pointLight: Color(0xFFE8C36A),
  pointDark: Color(0xFFA8432E),
  checkerWhiteFace: Color(0xFFF2F6F7),
  checkerWhiteEdge: Color(0xFF8FA9B4),
  checkerBlackFace: Color(0xFF123E63),
  checkerBlackEdge: Color(0xFF061C30),
  ornament: Color(0xFFEFE3C2),
  ornamentFill: Color(0xFF9FD5DE),
  highlight: Color(0xFF5CFFB0),
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
  // Бронза и яркий гранат: темнее светлых шашек и светлее тёмных.
  pointLight: Color(0xFFB5904A),
  pointDark: Color(0xFFB23A3F),
  checkerWhiteFace: Color(0xFFEFE1BE),
  checkerWhiteEdge: Color(0xFF9A7B3B),
  checkerBlackFace: Color(0xFF2B2724),
  checkerBlackEdge: Color(0xFF0D0B0A),
  ornament: Color(0xFFF0CE7A),
  ornamentFill: Color(0xFFB98C42),
  highlight: Color(0xFF4FE3FF),
  dieFace: Color(0xFFEFE1BE),
  dieEdge: Color(0xFF9A7B3B),
  diePip: Color(0xFF2B2724),
);

/// Все темы: классика первой (§P3 — «2 темы + классика»).
const List<BoardTheme> boardThemes = <BoardTheme>[
  yogochTheme,
  klassikTheme,
  kokGumbazTheme,
  zarTheme,
];

BoardTheme boardThemeById(String id) => boardThemes.firstWhere(
  (BoardTheme theme) => theme.id == id,
  orElse: () => klassikTheme,
);
