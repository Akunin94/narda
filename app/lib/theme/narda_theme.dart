import 'package:flutter/material.dart';
import 'package:narda_core/narda_core.dart';

/// Палитра: тёплое дерево, кремовые и тёмно-красные шашки, золотая подсветка
/// (§7). Всё рисуется программно, ни одной заимствованной текстуры.
abstract final class NardaColors {
  static const Color background = Color(0xFF231710);
  static const Color surface = Color(0xFF322115);

  static const Color frameDark = Color(0xFF4A2B18);
  static const Color frameLight = Color(0xFF7A4A28);

  static const Color feltDark = Color(0xFF8B5A2B);
  static const Color feltLight = Color(0xFFB07A44);

  static const Color pointLight = Color(0xFFE6CEA6);
  static const Color pointDark = Color(0xFF9B3B2C);

  static const Color checkerLight = Color(0xFFF4E6C8);
  static const Color checkerLightEdge = Color(0xFFB9975F);
  static const Color checkerDark = Color(0xFF7E2B22);
  static const Color checkerDarkEdge = Color(0xFF421009);

  static const Color gold = Color(0xFFE8BC57);
  static const Color goldDeep = Color(0xFFA9781F);

  static const Color textPrimary = Color(0xFFF3E4CB);
  static const Color textMuted = Color(0xFFB79C7B);

  /// Цвет шашек игрока: белые — кремовые, чёрные — тёмно-красные.
  static Color checkerFace(Player player) =>
      player == Player.white ? checkerLight : checkerDark;

  static Color checkerEdge(Player player) =>
      player == Player.white ? checkerLightEdge : checkerDarkEdge;

  static Color checkerLabel(Player player) =>
      player == Player.white ? checkerDarkEdge : checkerLight;
}

ThemeData buildNardaTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: NardaColors.gold,
    brightness: Brightness.dark,
    surface: NardaColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NardaColors.background,
    textTheme: Typography.material2021().white.apply(
      bodyColor: NardaColors.textPrimary,
      displayColor: NardaColors.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NardaColors.gold,
        foregroundColor: NardaColors.frameDark,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NardaColors.textPrimary,
        side: const BorderSide(color: NardaColors.goldDeep),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? NardaColors.gold
            : NardaColors.textMuted,
      ),
    ),
  );
}
