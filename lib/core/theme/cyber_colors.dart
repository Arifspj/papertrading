import 'package:flutter/material.dart';

/// Design-specific accent colors from the "Clean Light Trading" reference.
class TradePalette {
  static const Color primary = Color(0xFF387ED1);
  static const Color activeNav = Color(0xFF2563EB);
  static const Color positiveGreen = Color(0xFF5BA778);
  static const Color greenLight = Color(0xFFF0FDF4);
  static const Color greenBorder = Color(0xFFBBF7D0);
  static const Color negativeRed = Color(0xFFDC2626);
  static const Color nrmlBg = Color(0xFFF3E8FF);
  static const Color nrmlText = Color(0xFF7E22CE);
  static const Color misText = Color(0xFFDC2626);
  static const Color qtyLong = Color(0xFF407FE1);
  static const Color qtyShort = Color(0xFFBE123C);
  static const Color uLogo = Color(0xFFE65C00);
  static const Color weekBadge = Color(0xFF94B7F5);

  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);

  /// MIS tag backdrop from the reference (red-50).
  static const Color red50 = Color(0xFFFEF2F2);
}

/// Themed color surface for the whole app. Mirrors the reference
/// "Clean Light Trading" light palette (with a dark fallback).
@immutable
class CyberColors extends ThemeExtension<CyberColors> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color cardHover;
  final Color border;
  final Color borderActive;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color positive;
  final Color negative;
  final Color positiveSoft;
  final Color negativeSoft;
  final Color cyan;

  final List<Color> glassGradient;
  final List<Color> navGradient;
  final BoxShadow glow;
  final BoxShadow cardShadow;
  final LinearGradient heroAmbient;

  const CyberColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardHover,
    required this.border,
    required this.borderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.negative,
    required this.positiveSoft,
    required this.negativeSoft,
    required this.cyan,
    required this.glassGradient,
    required this.navGradient,
    required this.glow,
    required this.cardShadow,
    required this.heroAmbient,
  });

  static const CyberColors dark = CyberColors(
    bg: Color(0xFF0B1120),
    surface: Color(0xFF111827),
    card: Color(0xFF151F31),
    cardHover: Color(0xFF1B2740),
    border: Color(0xFF223049),
    borderActive: Color(0xFF387ED1),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    positive: Color(0xFF5BA778),
    negative: Color(0xFFDC2626),
    positiveSoft: Color(0x1A5BA778),
    negativeSoft: Color(0x1ADC2626),
    cyan: Color(0xFF407FE1),
    glassGradient: [
      Color(0xE6111826),
      Color(0xF20B1220),
    ],
    navGradient: [
      Color(0xE6101726),
      Color(0xF00B1220),
    ],
    glow: BoxShadow(
      color: Color(0x405BA778),
      blurRadius: 25,
      spreadRadius: -4,
    ),
    cardShadow: BoxShadow(
      color: Color(0x5E000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    heroAmbient: LinearGradient(
      colors: [Color(0x335BA778), Color(0x26407FE1), Color(0x335BA778)],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  static const CyberColors light = CyberColors(
    bg: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    borderActive: Color(0xFF387ED1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    positive: Color(0xFF5BA778),
    negative: Color(0xFFDC2626),
    positiveSoft: Color(0xFFF0FDF4),
    negativeSoft: Color(0xFFFEF2F2),
    cyan: Color(0xFF407FE1),
    glassGradient: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
    navGradient: [
      Color(0xFFFFFFFF),
      Color(0xFFFBFDFF),
    ],
    glow: BoxShadow(
      color: Color(0x265BA778),
      blurRadius: 25,
      spreadRadius: -4,
    ),
    cardShadow: BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    heroAmbient: LinearGradient(
      colors: [Color(0x245BA778), Color(0x1A407FE1), Color(0x245BA778)],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  @override
  CyberColors copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? cardHover,
    Color? border,
    Color? borderActive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? positive,
    Color? negative,
    Color? positiveSoft,
    Color? negativeSoft,
    Color? cyan,
    List<Color>? glassGradient,
    List<Color>? navGradient,
    BoxShadow? glow,
    BoxShadow? cardShadow,
    LinearGradient? heroAmbient,
  }) {
    return CyberColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardHover: cardHover ?? this.cardHover,
      border: border ?? this.border,
      borderActive: borderActive ?? this.borderActive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      positiveSoft: positiveSoft ?? this.positiveSoft,
      negativeSoft: negativeSoft ?? this.negativeSoft,
      cyan: cyan ?? this.cyan,
      glassGradient: glassGradient ?? this.glassGradient,
      navGradient: navGradient ?? this.navGradient,
      glow: glow ?? this.glow,
      cardShadow: cardShadow ?? this.cardShadow,
      heroAmbient: heroAmbient ?? this.heroAmbient,
    );
  }

  @override
  CyberColors lerp(CyberColors? other, double t) {
    if (other is! CyberColors) return this;
    return CyberColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      positiveSoft: Color.lerp(positiveSoft, other.positiveSoft, t)!,
      negativeSoft: Color.lerp(negativeSoft, other.negativeSoft, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      glassGradient: [
        Color.lerp(glassGradient[0], other.glassGradient[0], t)!,
        Color.lerp(glassGradient[1], other.glassGradient[1], t)!,
      ],
      navGradient: [
        Color.lerp(navGradient[0], other.navGradient[0], t)!,
        Color.lerp(navGradient[1], other.navGradient[1], t)!,
      ],
      glow: BoxShadow.lerp(glow, other.glow, t)!,
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
      heroAmbient: LinearGradient.lerp(heroAmbient, other.heroAmbient, t)!,
    );
  }
}

/// Convenience accessor.
extension CyberColorsX on BuildContext {
  CyberColors get cyber => Theme.of(this).extension<CyberColors>()!;
}