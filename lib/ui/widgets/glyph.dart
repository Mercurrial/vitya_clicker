import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/kardashev_tokens.dart';

/// Minimalist geometric glyphs — ported 1:1 from the design export
/// (design/components/core/Glyph.jsx). Pure stroked geometry on a 24px grid,
/// stroke-width 1.5, round caps/joins. Monochrome: recolored at render via a
/// srcIn color filter (cyan when active/unlocked, mid grey otherwise).
const Map<String, String> _glyphInner = {
  // Generators (Kardashev ladder)
  'photovoltaic':
      '<rect x="5" y="5" width="6" height="6" rx="1"/><rect x="13" y="5" width="6" height="6" rx="1"/>'
          '<rect x="5" y="13" width="6" height="6" rx="1"/><rect x="13" y="13" width="6" height="6" rx="1"/>',
  'geothermal': '<path d="M12 4 L19 18 H5 Z"/><path d="M12 11 L15.5 18 H8.5 Z"/>',
  'fusion':
      '<circle cx="12" cy="12" r="3.2"/><ellipse cx="12" cy="12" rx="8" ry="3.4"/>'
          '<ellipse cx="12" cy="12" rx="8" ry="3.4" transform="rotate(60 12 12)"/>',
  'antimatter': '<circle cx="9" cy="12" r="5"/><circle cx="15" cy="12" r="5"/>',
  'dyson':
      '<circle cx="12" cy="12" r="2.4"/><path d="M5 12 A7 7 0 0 1 19 12"/>'
          '<path d="M19 12 A7 7 0 0 1 5 12" stroke-dasharray="2 2.4"/>',
  'neutron': '<path d="M12 4 L19 8 V16 L12 20 L5 16 V8 Z"/><circle cx="12" cy="12" r="2"/>',
  'blackhole':
      '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
  'galactic':
      '<path d="M4 18 C9 14 9 10 12 8 C15 6 18 6 20 6"/>'
          '<path d="M4 18 C6 18 9 18 12 16 C15 14 15 10 20 6" stroke-dasharray="2 2.4"/>',
  // Upgrades
  'overclock': '<path d="M6 14 L12 8 L18 14"/><path d="M6 18 L12 12 L18 18"/>',
  'coherence':
      '<circle cx="12" cy="12" r="2"/><circle cx="12" cy="12" r="5"/>'
          '<circle cx="12" cy="12" r="8" stroke-dasharray="2 2.6"/>',
  'cascade':
      '<path d="M4 14 Q8 8 12 14 T20 14"/><path d="M4 18 Q8 12 12 18 T20 18" stroke-dasharray="2 2.4"/>',
  'zeropoint':
      '<circle cx="12" cy="12" r="2.2" fill="currentColor" stroke="none"/>'
          '<path d="M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20"/>',
  'catalyst':
      '<path d="M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20 M6.5 6.5 L9 9 M15 15 L17.5 17.5 '
          'M17.5 6.5 L15 9 M9 15 L6.5 17.5"/><circle cx="12" cy="12" r="2.4"/>',
  'horizon':
      '<ellipse cx="12" cy="12" rx="8" ry="3"/><circle cx="12" cy="12" r="2.6" fill="currentColor" stroke="none"/>',
};

String _svgFor(String name) {
  final inner = _glyphInner[name] ?? _glyphInner['fusion']!;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
      '$inner</svg>';
}

class Glyph extends StatelessWidget {
  final String name;
  final double size;
  final bool tint;
  const Glyph({super.key, required this.name, this.size = 22, this.tint = false});

  @override
  Widget build(BuildContext context) {
    final color = tint ? KColors.accent : KColors.textMid;
    return SvgPicture.string(
      _svgFor(name),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Rounded tile holding a glyph; faint cyan tint when active.
class GlyphTile extends StatelessWidget {
  final String name;
  final bool active;
  final double size;
  const GlyphTile({super.key, required this.name, this.active = false, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KR.button),
        color: active ? KColors.glyphActiveBg : KColors.white04,
        border: Border.all(
          color: active ? KColors.glyphActiveBorder : KColors.glassBorder,
          width: 1,
        ),
      ),
      child: Center(child: Glyph(name: name, size: (size * 0.5).roundToDouble(), tint: active)),
    );
  }
}

/// Generator id → glyph name (Kardashev ladder).
const Map<String, String> kGeneratorGlyphs = {
  'photovoltaic': 'photovoltaic',
  'geothermal': 'geothermal',
  'fusion': 'fusion',
  'antimatter': 'antimatter',
  'dyson': 'dyson',
  'neutron': 'neutron',
  'blackhole': 'blackhole',
  'filament': 'galactic',
};

/// Upgrade id → glyph name.
const Map<String, String> kUpgradeGlyphs = {
  'core_x3': 'catalyst',
  'core_x5': 'catalyst',
  'photo_x2': 'overclock',
  'geo_x2': 'overclock',
  'fusion_x2': 'overclock',
  'cascade': 'cascade',
  'coupling': 'coherence',
  'resonance': 'cascade',
  'dyson_x2': 'catalyst',
  'blackhole_x3': 'horizon',
};
