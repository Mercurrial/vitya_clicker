import 'dart:math' as math;

/// Scientific mantissa/exponent pair: `m × 10^e`.
class SciParts {
  final String mantissa; // "x.xx"
  final int exponent;
  const SciParts(this.mantissa, this.exponent);
}

/// Hero readout: either a plain grouped integer (< 1000) or scientific parts.
class HeroValue {
  final String? plain;
  final SciParts? sci;
  const HeroValue.plain(this.plain) : sci = null;
  const HeroValue.scientific(this.sci) : plain = null;
  bool get isPlain => plain != null;
}

/// KARDASHEV number formatting — ported from the design export
/// (design/ui_kits/kardashev/format.js, `window.KFmt`).
///
/// `< 1000` → grouped integer ("750"); `>= 1000` → scientific. The hero
/// counter renders `m.mm × 10ⁿ`; compact positions (rates, prices, card stats)
/// render `m.mme+n`. Mantissa is always 2 decimals (3 significant figures).
class KFmt {
  KFmt._();

  /// Floor + thousands separators: 12500 → "12,500".
  static String group(num n) {
    final v = n.floor();
    final neg = v < 0;
    final digits = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return neg ? '-${buf.toString()}' : buf.toString();
  }

  /// Mantissa (2 d.p.) + exponent, with rounding-carry handling (9.999→1.00,e+1).
  static SciParts parts(num n) {
    if (n <= 0) return const SciParts('0.00', 0);
    var e = (math.log(n) / math.ln10).floor();
    final m = n / math.pow(10, e);
    var ms = m.toStringAsFixed(2);
    if (ms == '10.00') {
      ms = '1.00';
      e += 1;
    }
    return SciParts(ms, e);
  }

  /// Hero counter value.
  static HeroValue hero(num n) {
    if (n < 1000) return HeroValue.plain(group(n));
    return HeroValue.scientific(parts(n));
  }

  /// Compact one-line value, e.g. "4.20e23".
  static String compact(num n) {
    if (n < 1000) return group(n);
    final p = parts(n);
    return '${p.mantissa}e${p.exponent}';
  }
}
