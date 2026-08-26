/// Тема «тёплый мультгараж».
///
/// Намеренный контраст с холодным сине-циановым KARDASHEV: здесь медь, латунь,
/// дерево и свет лампочки. Фон — тёплый почти-чёрный (#14100C), а не чистый
/// чёрный: тёплые тёмные поверхности читаются мягче и лучше держат тени.
///
/// Дисциплина акцента: тёмные тёплые нейтрали ~60 %, медь/дерево ~30 %,
/// янтарный CTA ~10 % — янтарь только там, где можно нажать и купить.
library;

import 'package:flutter/widgets.dart';

class GColors {
  GColors._();

  // Поверхности (тёплые тёмные, не чёрные)
  static const bg = Color(0xFF14100C);
  static const surface1 = Color(0xFF1E1811);
  static const surface2 = Color(0xFF2A2118);
  static const surface3 = Color(0xFF372B1F);

  // Медь и латунь — характер гаража
  static const copper = Color(0xFFC87941);
  static const copperDim = Color(0xFF8C5430);

  // Янтарь — главный акцент и CTA
  static const amber = Color(0xFFE8A33D);
  static const amberDim = Color(0xFFB87C24);
  static const amberGlow = Color(0x4DE8A33D);

  /// Свет лампочки под потолком гаража.
  static const lamp = Color(0xFFFFD089);
  static const lampGlow = Color(0x2EFFD089);

  /// Сам продукт — мутноватый тёплый самогон.
  static const brew = Color(0xFFF2E2B8);

  // Шкала ГРАДУСА
  static const cold = Color(0xFF6A8CAF);
  static const green = Color(0xFF8FBF4D);
  static const hot = Color(0xFFE0523A);

  // Текст (тёплые белые)
  static const textHi = Color(0xFFF5EDE0);
  static const textMid = Color(0xFFA89681);
  static const textLo = Color(0xFF6E6155);

  // На заливке
  static const onAmber = Color(0xFF2B1A06);

  // Линии и стекло
  static const hairline = Color(0x1AFFFFFF);
  static const border = Color(0x24FFFFFF);
  static const wellBg = Color(0x33000000);
}

/// Радиусы — крупнее и мягче, чем в sci-fi: гараж «пухлый», а не острый.
class GR {
  GR._();
  static const sheet = 30.0;
  static const card = 20.0;
  static const button = 16.0;
  static const pill = 999.0;
}

/// Сетка 8pt.
class GS {
  GS._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

class GShadow {
  GShadow._();
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const sheet = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 28, offset: Offset(0, -6)),
  ];
  static const lamp = <BoxShadow>[
    BoxShadow(color: GColors.lampGlow, blurRadius: 48, spreadRadius: 6),
  ];
}

/// Мягкое замедление — для появлений и пружинок.
const Cubic gEase = Cubic(0.22, 0.61, 0.36, 1);

/// Типографика: Rubik для интерфейса (тёплый, отличная кириллица),
/// IBM Plex Mono для чисел — табличные цифры не дают счётчику дёргаться.
class GType {
  GType._();

  static const uiFamily = 'Rubik';
  static const numFamily = 'IBMPlexMono';

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = GColors.textHi,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: uiFamily,
        // Rubik — вариативный: ось веса задаём явно.
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle num({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = GColors.textHi,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) =>
      TextStyle(
        fontFamily: numFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        shadows: shadows,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Крупный счётчик литров.
  static TextStyle counter() => num(
        size: 40,
        weight: FontWeight.w700,
        color: GColors.textHi,
        letterSpacing: -0.5,
        shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 20)],
      );

  static TextStyle label() =>
      ui(size: 11, weight: FontWeight.w600, color: GColors.textMid, letterSpacing: 1.6);
  static TextStyle title() => ui(size: 15, weight: FontWeight.w600);
  static TextStyle body() =>
      ui(size: 13, weight: FontWeight.w400, color: GColors.textMid, height: 1.35);
  static TextStyle tab() => ui(size: 13, weight: FontWeight.w600, letterSpacing: 0.4);

  /// Реплики Вити — чуть курсивный характер за счёт веса и цвета.
  static TextStyle quote() =>
      ui(size: 13, weight: FontWeight.w500, color: GColors.lamp, height: 1.3);
}
