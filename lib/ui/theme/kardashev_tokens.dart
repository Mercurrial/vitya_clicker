import 'package:flutter/widgets.dart';

/// KARDASHEV design tokens — ported 1:1 from the Claude Design export
/// (design/tokens/*.css). Strict palette, 60-30-10 discipline:
/// dark neutrals ~60%, plasma cyan ~30% (identity/active), amber ~10%
/// (affordable purchases only). Never pure black.
class KColors {
  KColors._();

  // Surfaces
  static const voidBg = Color(0xFF0A0D14);
  static const surface1 = Color(0xFF10141D);
  static const surface2 = Color(0xFF171C28);
  static const surface3 = Color(0xFF202637);

  // Plasma cyan — identity / active
  static const accent = Color(0xFF34E2D6);
  static const accentDim = Color(0xFF1FB6AC);
  static const accentGlow = Color(0x5934E2D6); // rgba(52,226,214,0.35)
  static const accentGlowStrong = Color(0x8C34E2D6); // rgba(...,0.55)

  // Amber CTA — affordable purchases ONLY
  static const ctaSolid = Color(0xFFFFB020);
  static const ctaGradA = Color(0xFFFFC24B);
  static const ctaGradB = Color(0xFFFF8A00);
  static const ctaGlow = Color(0x4DFFB020); // rgba(255,176,32,0.30)

  // Text (on dark)
  static const textHi = Color(0xEBFFFFFF); // white 0.92
  static const textMid = Color(0x99FFFFFF); // white 0.60
  static const textLo = Color(0x61FFFFFF); // white 0.38

  // Glass + hairlines
  static const glassBg = Color(0x8C171C28); // rgba(23,28,40,0.55)
  static const glassBorder = Color(0x14FFFFFF); // white 0.08
  static const glassInset = Color(0x0FFFFFFF); // white 0.06
  static const hairline = Color(0x0FFFFFFF);

  // Foreground used on top of accent / cta fills
  static const onAccent = Color(0xFF04201E);
  static const onCta = Color(0xFF1A1206);

  // Misc rgba helpers used across components
  static const white04 = Color(0x0AFFFFFF);
  static const white03 = Color(0x08FFFFFF);
  static const white07 = Color(0x12FFFFFF);
  static const black28 = Color(0x47000000);
  static const glyphActiveBg = Color(0x1F34E2D6); // rgba(52,226,214,0.12)
  static const glyphActiveBorder = Color(0x5934E2D6); // rgba(...,0.35)
  static const rowHighlightBorder = Color(0x7334E2D6); // rgba(...,0.45)
  static const rowHighlightGlow = Color(0x1A34E2D6); // rgba(...,0.10)
  static const coreRing = Color(0x730A0D14); // rgba(10,13,20,0.45)
}

/// Corner radii.
class KR {
  KR._();
  static const sheet = 28.0;
  static const card = 18.0;
  static const button = 14.0;
  static const pill = 999.0;
}

/// 8pt spacing scale.
class KS {
  KS._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

/// Shadows / glows.
class KShadow {
  KShadow._();
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const sheet = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, -8)),
  ];
  static const coreIdle = <BoxShadow>[
    BoxShadow(color: KColors.accentGlow, blurRadius: 60, spreadRadius: 8),
  ];
  static const corePress = <BoxShadow>[
    BoxShadow(color: KColors.accentGlowStrong, blurRadius: 90, spreadRadius: 16),
  ];
}

/// Decelerate easing used for entrances and the tab thumb.
const Cubic kDecelerate = Cubic(0.22, 0.61, 0.36, 1);

/// Typography. UI = IBM Plex Sans; every number = IBM Plex Mono (monospace ⇒
/// tabular by construction, so widths never jump as values tick).
class KType {
  KType._();

  static const sansFamily = 'IBMPlexSans';
  static const monoFamily = 'IBMPlexMono';

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = KColors.textHi,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        // Sans is a variable font: drive the weight axis explicitly.
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = KColors.textHi,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle tier() => ui(
        size: 11,
        weight: FontWeight.w600,
        color: KColors.textMid,
        letterSpacing: 11 * 0.18,
      );

  static TextStyle tab() => ui(size: 14, weight: FontWeight.w600, letterSpacing: 14 * 0.04);
  static TextStyle name() => ui(size: 15, weight: FontWeight.w600, color: KColors.textHi);
  static TextStyle desc() =>
      ui(size: 12, weight: FontWeight.w400, color: KColors.textMid, height: 1.35);
  static TextStyle cardTitle() =>
      ui(size: 14, weight: FontWeight.w600, color: KColors.textHi, height: 1.2);

  static TextStyle chip(Color color) => mono(size: 13, weight: FontWeight.w500, color: color);
  static TextStyle count() => mono(size: 12, weight: FontWeight.w600, color: KColors.accent);
  static TextStyle rate() => mono(size: 12, weight: FontWeight.w400, color: KColors.textMid);
  static TextStyle price(Color color) => mono(size: 14, weight: FontWeight.w600, color: color);
}
