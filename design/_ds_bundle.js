/* @ds-bundle: {"format":3,"namespace":"KARDASHEVDesignSystem_4d3925","components":[{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Chip","sourcePath":"components/core/Chip.jsx"},{"name":"Glyph","sourcePath":"components/core/Glyph.jsx"},{"name":"GlyphTile","sourcePath":"components/core/GlyphTile.jsx"},{"name":"ProgressBar","sourcePath":"components/core/ProgressBar.jsx"},{"name":"SegmentedTabs","sourcePath":"components/core/SegmentedTabs.jsx"},{"name":"Core","sourcePath":"components/game/Core.jsx"},{"name":"GeneratorRow","sourcePath":"components/game/GeneratorRow.jsx"},{"name":"UpgradeCard","sourcePath":"components/game/UpgradeCard.jsx"}],"sourceHashes":{"components/core/Button.jsx":"35650723c1dc","components/core/Chip.jsx":"eb423fccbf6a","components/core/Glyph.jsx":"b21f7b1a061e","components/core/GlyphTile.jsx":"47be190813b2","components/core/ProgressBar.jsx":"c7d5845ca0d2","components/core/SegmentedTabs.jsx":"bd6446602552","components/game/Core.jsx":"da8de520edd2","components/game/GeneratorRow.jsx":"932c3a72b8db","components/game/UpgradeCard.jsx":"e3c0d77320ef","ui_kits/kardashev/KardashevApp.jsx":"e7a937b9e8f0","ui_kits/kardashev/format.js":"f39ed078de4b"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.KARDASHEVDesignSystem_4d3925 = window.KARDASHEVDesignSystem_4d3925 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* KARDASHEV button.
   Variants:
   - cta:        amber gradient pill — ONLY when an action is affordable/buyable
   - cta-ghost:  dim outline pill — buyable visually, but not affordable (price lo)
   - accent:     cyan — active/identity actions
   - ghost:      transparent, mid text
   Sizes: sm (pill, 36) / md (44). */
function Button({
  variant = "accent",
  size = "md",
  disabled = false,
  children,
  style,
  ...rest
}) {
  const base = {
    fontFamily: "var(--font-ui)",
    fontWeight: 600,
    border: "none",
    cursor: disabled ? "default" : "pointer",
    borderRadius: "var(--radius-pill)",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "6px",
    transition: "transform 140ms ease, box-shadow 220ms ease, background 220ms ease",
    WebkitTapHighlightColor: "transparent",
    whiteSpace: "nowrap"
  };
  const sizes = {
    sm: {
      height: 36,
      padding: "0 14px",
      fontSize: 13
    },
    md: {
      height: 44,
      padding: "0 20px",
      fontSize: 14
    }
  };
  const variants = {
    cta: {
      background: "var(--cta)",
      color: "#1A1206",
      boxShadow: "0 6px 20px var(--cta-glow), inset 0 1px 0 rgba(255,255,255,0.25)"
    },
    "cta-ghost": {
      background: "transparent",
      color: "var(--text-lo)",
      boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.10)"
    },
    accent: {
      background: "var(--accent)",
      color: "#04201E",
      boxShadow: "0 4px 16px var(--accent-glow)"
    },
    ghost: {
      background: "transparent",
      color: "var(--text-mid)",
      boxShadow: "inset 0 0 0 1px var(--glass-border)"
    }
  };
  const v = disabled ? {
    ...variants[variant],
    opacity: 0.42,
    boxShadow: "none"
  } : variants[variant];
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    disabled: disabled,
    style: {
      ...base,
      ...sizes[size],
      ...v,
      ...style
    },
    onPointerDown: e => {
      if (!disabled) e.currentTarget.style.transform = "scale(0.96)";
    },
    onPointerUp: e => {
      e.currentTarget.style.transform = "scale(1)";
    },
    onPointerLeave: e => {
      e.currentTarget.style.transform = "scale(1)";
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Chip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Stat chip — rate readouts under the hero counter (J/s, J/tap).
   tone "accent" = cyan (production), "mid" = muted (per-tap). */
function Chip({
  icon,
  value,
  tone = "mid",
  style,
  ...rest
}) {
  const color = tone === "accent" ? "var(--accent)" : "var(--text-mid)";
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: "var(--type-stat-size)",
      fontWeight: "var(--type-stat-weight)",
      color,
      padding: "5px 11px",
      borderRadius: "var(--radius-pill)",
      background: "rgba(255,255,255,0.03)",
      boxShadow: "inset 0 0 0 1px var(--glass-border)",
      ...style
    }
  }, rest), icon ? /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: 12,
      opacity: 0.9
    }
  }, icon) : null, value);
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Chip.jsx", error: String((e && e.message) || e) }); }

// components/core/Glyph.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Minimalist geometric glyphs for KARDASHEV generators & upgrades.
   Pure stroked geometry — no skeuomorphism. Inherits currentColor. */

const PATHS = {
  // Generators (Kardashev ladder)
  photovoltaic: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("rect", {
    x: "5",
    y: "5",
    width: "6",
    height: "6",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "13",
    y: "5",
    width: "6",
    height: "6",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "5",
    y: "13",
    width: "6",
    height: "6",
    rx: "1"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "13",
    y: "13",
    width: "6",
    height: "6",
    rx: "1"
  })),
  geothermal: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M12 4 L19 18 H5 Z"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M12 11 L15.5 18 H8.5 Z"
  })),
  fusion: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "3.2"
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "12",
    cy: "12",
    rx: "8",
    ry: "3.4"
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "12",
    cy: "12",
    rx: "8",
    ry: "3.4",
    transform: "rotate(60 12 12)"
  })),
  antimatter: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "9",
    cy: "12",
    r: "5"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "15",
    cy: "12",
    r: "5"
  })),
  dyson: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2.4"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M5 12 A7 7 0 0 1 19 12"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M19 12 A7 7 0 0 1 5 12",
    "stroke-dasharray": "2 2.4"
  })),
  neutron: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M12 4 L19 8 V16 L12 20 L5 16 V8 Z"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2"
  })),
  blackhole: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "6.5"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "1.6",
    fill: "currentColor",
    stroke: "none"
  })),
  galactic: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M4 18 C9 14 9 10 12 8 C15 6 18 6 20 6"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M4 18 C6 18 9 18 12 16 C15 14 15 10 20 6",
    "stroke-dasharray": "2 2.4"
  })),
  // Upgrades
  overclock: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M6 14 L12 8 L18 14"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M6 18 L12 12 L18 18"
  })),
  coherence: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "5"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "8",
    "stroke-dasharray": "2 2.6"
  })),
  cascade: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M4 14 Q8 8 12 14 T20 14"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M4 18 Q8 12 12 18 T20 18",
    "stroke-dasharray": "2 2.4"
  })),
  zeropoint: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2.2",
    fill: "currentColor",
    stroke: "none"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20"
  })),
  catalyst: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("path", {
    d: "M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20 M6.5 6.5 L9 9 M15 15 L17.5 17.5 M17.5 6.5 L15 9 M9 15 L6.5 17.5"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2.4"
  })),
  horizon: /*#__PURE__*/React.createElement("g", null, /*#__PURE__*/React.createElement("ellipse", {
    cx: "12",
    cy: "12",
    rx: "8",
    ry: "3"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "2.6",
    fill: "currentColor",
    stroke: "none"
  }))
};
function Glyph({
  name,
  size = 22,
  tint = false,
  style,
  ...rest
}) {
  const color = tint ? "var(--accent)" : "var(--text-mid)";
  return /*#__PURE__*/React.createElement("svg", _extends({
    viewBox: "0 0 24 24",
    width: size,
    height: size,
    fill: "none",
    stroke: color,
    strokeWidth: "1.5",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block",
      ...style
    }
  }, rest), PATHS[name] || PATHS.fusion);
}
Object.assign(__ds_scope, { Glyph });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Glyph.jsx", error: String((e && e.message) || e) }); }

// components/core/GlyphTile.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Rounded tile holding a geometric glyph. Gets a faint cyan tint when active. */
function GlyphTile({
  name,
  active = false,
  size = 44,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      width: size,
      height: size,
      flex: "none",
      borderRadius: "var(--radius-button)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      background: active ? "rgba(52,226,214,0.12)" : "rgba(255,255,255,0.04)",
      boxShadow: active ? "inset 0 0 0 1px rgba(52,226,214,0.35)" : "inset 0 0 0 1px var(--glass-border)",
      transition: "background 220ms ease, box-shadow 220ms ease",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Glyph, {
    name: name,
    size: Math.round(size * 0.5),
    tint: active
  }));
}
Object.assign(__ds_scope, { GlyphTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/GlyphTile.jsx", error: String((e && e.message) || e) }); }

// components/core/ProgressBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Kardashev-scale progress bar — thin cyan fill on a dark track. */
function ProgressBar({
  value = 0,
  style,
  ...rest
}) {
  const pct = Math.max(0, Math.min(1, value)) * 100;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      height: 4,
      borderRadius: "var(--radius-pill)",
      background: "rgba(255,255,255,0.07)",
      overflow: "hidden",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      width: `${pct}%`,
      borderRadius: "var(--radius-pill)",
      background: "linear-gradient(90deg, var(--accent-dim), var(--accent))",
      boxShadow: "0 0 12px var(--accent-glow)",
      transition: "width 240ms ease"
    }
  }));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/core/SegmentedTabs.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Segmented tabs for the bottom sheet: [ Generators | Upgrades ].
   Active segment is cyan; the pill slides via translate. */
function SegmentedTabs({
  tabs = [],
  active,
  onChange,
  style,
  ...rest
}) {
  const idx = Math.max(0, tabs.indexOf(active));
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      position: "relative",
      display: "grid",
      gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
      padding: 4,
      borderRadius: "var(--radius-pill)",
      background: "rgba(0,0,0,0.28)",
      boxShadow: "inset 0 0 0 1px var(--glass-border)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    "aria-hidden": "true",
    style: {
      position: "absolute",
      top: 4,
      left: 4,
      bottom: 4,
      width: `calc((100% - 8px) / ${tabs.length})`,
      transform: `translateX(${idx * 100}%)`,
      borderRadius: "var(--radius-pill)",
      background: "var(--accent)",
      boxShadow: "0 2px 12px var(--accent-glow)",
      transition: "transform 260ms cubic-bezier(0.22,0.61,0.36,1)"
    }
  }), tabs.map(t => {
    const on = t === active;
    return /*#__PURE__*/React.createElement("button", {
      key: t,
      type: "button",
      onClick: () => onChange && onChange(t),
      style: {
        position: "relative",
        zIndex: 1,
        height: 36,
        border: "none",
        background: "transparent",
        cursor: "pointer",
        fontFamily: "var(--font-ui)",
        fontSize: "var(--type-tab-size)",
        fontWeight: "var(--type-tab-weight)",
        letterSpacing: "var(--type-tab-tracking)",
        textTransform: "uppercase",
        color: on ? "#04201E" : "var(--text-mid)",
        transition: "color 200ms ease",
        WebkitTapHighlightColor: "transparent"
      }
    }, t);
  }));
}
Object.assign(__ds_scope, { SegmentedTabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SegmentedTabs.jsx", error: String((e && e.message) || e) }); }

// components/game/Core.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* The star core — central tap button.
   Radial plasma-cyan gradient, dark ring, soft glow halo, idle pulse.
   `pressed` drives the pressed scale + intensified glow.
   Respects prefers-reduced-motion (pulse disabled). */
function Core({
  pressed = false,
  size = 210,
  style,
  children,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": "Feed the core",
    className: `km-core${pressed ? " km-core--pressed" : ""}`,
    style: {
      position: "relative",
      width: size,
      height: size,
      flex: "none",
      borderRadius: "50%",
      border: "none",
      cursor: "pointer",
      padding: 0,
      background: "radial-gradient(circle at 50% 44%, #BFFCF6 0%, #34E2D6 26%, #16847C 58%, #0C2C2E 82%, #0A0D14 100%)",
      boxShadow: pressed ? "var(--core-glow-press), inset 0 0 40px rgba(0,0,0,0.55), inset 0 2px 12px rgba(255,255,255,0.35)" : "var(--core-glow-idle), inset 0 0 40px rgba(0,0,0,0.5), inset 0 2px 12px rgba(255,255,255,0.25)",
      transform: pressed ? "scale(0.96)" : "scale(1)",
      transition: "transform 120ms ease, box-shadow 160ms ease",
      WebkitTapHighlightColor: "transparent",
      outline: "none",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("style", null, `
        @keyframes km-core-pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.03); }
        }
        @media (prefers-reduced-motion: no-preference) {
          .km-core:not(.km-core--pressed) { animation: km-core-pulse 2.4s ease-in-out infinite; }
        }
      `), /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      position: "absolute",
      inset: "12%",
      borderRadius: "50%",
      boxShadow: "inset 0 0 0 2px rgba(10,13,20,0.45)",
      pointerEvents: "none"
    }
  }), children);
}
Object.assign(__ds_scope, { Core });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/game/Core.jsx", error: String((e && e.message) || e) }); }

// components/game/GeneratorRow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* A generator list row.
   left: geometric glyph tile (cyan tint if owned/active)
   center: name + "×N" owned + J/s contribution
   right: Buy pill with price (amber if affordable, dim if not)
   States: locked (greyscale + dim), highlighted (next unlock — cyan edge). */
function GeneratorRow({
  glyph,
  name,
  count = 0,
  rate,
  price,
  affordable = false,
  locked = false,
  highlighted = false,
  onBuy,
  style,
  ...rest
}) {
  const active = count > 0 && !locked;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--space-3)",
      padding: "10px 12px",
      borderRadius: "var(--radius-card)",
      background: highlighted ? "var(--surface-3)" : "var(--surface-2)",
      boxShadow: highlighted ? "inset 0 0 0 1px rgba(52,226,214,0.45), 0 0 18px rgba(52,226,214,0.10)" : "inset 0 0 0 1px var(--glass-border)",
      filter: locked ? "grayscale(1)" : "none",
      opacity: locked ? 0.45 : 1,
      transition: "background 220ms ease, box-shadow 220ms ease, opacity 220ms ease",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.GlyphTile, {
    name: glyph,
    active: active,
    size: 44
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: "var(--type-name-size)",
      fontWeight: "var(--type-name-weight)",
      color: "var(--text-hi)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, name), count > 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: 12,
      fontWeight: 600,
      color: "var(--accent)"
    }
  }, "\xD7", count)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: 12,
      color: "var(--text-mid)",
      marginTop: 2
    }
  }, rate)), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: affordable ? "cta" : "cta-ghost",
    size: "sm",
    disabled: locked,
    onClick: onBuy,
    style: {
      minWidth: 84
    }
  }, price));
}
Object.assign(__ds_scope, { GeneratorRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/game/GeneratorRow.jsx", error: String((e && e.message) || e) }); }

// components/game/UpgradeCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Upgrade card (grid, 2-up). One-time multiplier.
   States:
   - available:  amber border + soft amber glow + active Buy
   - locked:     dimmed
   - purchased:  check marker + struck-through price + opacity ~0.4 */
function UpgradeCard({
  glyph,
  title,
  desc,
  price,
  state = "locked",
  onBuy,
  style,
  ...rest
}) {
  const available = state === "available";
  const purchased = state === "purchased";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      position: "relative",
      display: "flex",
      flexDirection: "column",
      gap: 8,
      padding: "14px 14px 16px",
      borderRadius: "var(--radius-card)",
      background: "var(--surface-2)",
      boxShadow: available ? "inset 0 0 0 1px var(--cta-solid), 0 0 18px var(--cta-glow)" : "inset 0 0 0 1px var(--glass-border)",
      opacity: purchased ? 0.4 : locked(state) ? 0.5 : 1,
      filter: locked(state) ? "grayscale(0.8)" : "none",
      transition: "opacity 240ms ease, box-shadow 240ms ease, filter 240ms ease",
      ...style
    }
  }, rest), purchased && /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      position: "absolute",
      top: 12,
      right: 12,
      width: 20,
      height: 20,
      borderRadius: "50%",
      background: "var(--accent)",
      color: "#04201E",
      fontSize: 12,
      fontWeight: 700,
      display: "flex",
      alignItems: "center",
      justifyContent: "center"
    }
  }, "\u2713"), /*#__PURE__*/React.createElement(__ds_scope.Glyph, {
    name: glyph,
    size: 24,
    tint: available
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: 14,
      fontWeight: 600,
      color: "var(--text-hi)",
      lineHeight: 1.2
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: "var(--type-desc-size)",
      color: "var(--text-mid)",
      lineHeight: 1.35,
      flex: 1
    }
  }, desc), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginTop: 4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: "var(--type-price-size)",
      fontWeight: 600,
      color: purchased ? "var(--text-lo)" : available ? "var(--cta-solid)" : "var(--text-lo)",
      textDecoration: purchased ? "line-through" : "none"
    }
  }, price), !purchased && /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: available ? "cta" : "cta-ghost",
    size: "sm",
    disabled: !available,
    onClick: onBuy,
    style: {
      minWidth: 64,
      height: 32
    }
  }, "Buy")));
}
function locked(state) {
  return state === "locked";
}
Object.assign(__ds_scope, { UpgradeCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/game/UpgradeCard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/kardashev/KardashevApp.jsx
try { (() => {
/* KARDASHEV — interactive game screen, composed from the design-system components. */
const {
  Core,
  GeneratorRow,
  UpgradeCard,
  SegmentedTabs,
  Chip,
  ProgressBar
} = window.KARDASHEVDesignSystem_4d3925;
const REDUCED = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
function initialGenerators() {
  return [{
    id: "g1",
    name: "Photovoltaic Lattice",
    glyph: "photovoltaic",
    count: 64,
    rate: 1.5,
    cost: 940,
    mult: 1.15
  }, {
    id: "g2",
    name: "Geothermal Tap",
    glyph: "geothermal",
    count: 21,
    rate: 12,
    cost: 7200,
    mult: 1.15
  }, {
    id: "g3",
    name: "Fusion Core",
    glyph: "fusion",
    count: 8,
    rate: 180,
    cost: 48000,
    mult: 1.16
  }, {
    id: "g4",
    name: "Antimatter Loop",
    glyph: "antimatter",
    count: 2,
    rate: 2400,
    cost: 310000,
    mult: 1.18
  }, {
    id: "g5",
    name: "Dyson Swarm",
    glyph: "dyson",
    count: 0,
    rate: 32000,
    cost: 6600000,
    mult: 1.2,
    highlight: true
  }, {
    id: "g6",
    name: "Neutron Forge",
    glyph: "neutron",
    count: 0,
    rate: 410000,
    cost: 8.8e8,
    mult: 1.2,
    locked: true
  }, {
    id: "g7",
    name: "Black-Hole Accretor",
    glyph: "blackhole",
    count: 0,
    rate: 5.2e6,
    cost: 1.4e11,
    mult: 1.22,
    locked: true
  }, {
    id: "g8",
    name: "Galactic Filament",
    glyph: "galactic",
    count: 0,
    rate: 6.6e7,
    cost: 2.0e14,
    mult: 1.25,
    locked: true
  }];
}
function initialUpgrades() {
  return [{
    id: "u1",
    glyph: "overclock",
    title: "Fusion Overclock",
    desc: "Fusion Core ×2",
    cost: 340000,
    state: "available"
  }, {
    id: "u2",
    glyph: "coherence",
    title: "Quantum Coherence",
    desc: "J/tap ×3",
    cost: 890000,
    state: "available"
  }, {
    id: "u3",
    glyph: "cascade",
    title: "Resonance Cascade",
    desc: "All generators +50%",
    cost: 2100000,
    state: "purchased"
  }, {
    id: "u4",
    glyph: "zeropoint",
    title: "Zero-Point Tap",
    desc: "J/tap += 1% of J/s",
    cost: 5400000,
    state: "locked"
  }, {
    id: "u5",
    glyph: "catalyst",
    title: "Stellar Catalyst",
    desc: "Dyson Swarm ×2",
    cost: 1.8e7,
    state: "locked"
  }, {
    id: "u6",
    glyph: "horizon",
    title: "Event Horizon",
    desc: "Black-Hole Accretor ×3",
    cost: 9.9e9,
    state: "locked"
  }];
}
function rateOf(gens, cascade) {
  let s = 0;
  for (const g of gens) s += g.count * g.rate;
  return cascade ? s * 1.5 : s;
}

/* Hero counter — owns its own rAF and only commits when the displayed
   value actually changes (~1/sec), so it doesn't thrash the rest of the UI. */
function HeroCounter({
  energyRef,
  jpsRef
}) {
  const [, setTick] = React.useState(0);
  const lastStr = React.useRef("");
  const dispRef = React.useRef(energyRef.current);
  React.useEffect(() => {
    let raf,
      last = performance.now();
    const loop = t => {
      const dt = Math.min(0.05, (t - last) / 1000);
      last = t;
      energyRef.current += jpsRef.current * dt;
      const k = REDUCED ? 1 : Math.min(1, dt * 8);
      dispRef.current += (energyRef.current - dispRef.current) * k;
      const h = window.KFmt.hero(dispRef.current);
      const str = h.plain != null ? h.plain : h.m + "e" + h.e;
      if (str !== lastStr.current) {
        lastStr.current = str;
        setTick(n => n + 1 & 0xffff);
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);
  const h = window.KFmt.hero(dispRef.current);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: "var(--type-hero-size)",
      fontWeight: 700,
      letterSpacing: "var(--type-hero-tracking)",
      color: "var(--text-hi)",
      textShadow: "0 0 26px var(--accent-glow)",
      lineHeight: 1,
      display: "flex",
      alignItems: "baseline",
      justifyContent: "center",
      gap: 8
    }
  }, h.plain != null ? /*#__PURE__*/React.createElement("span", null, h.plain) : /*#__PURE__*/React.createElement("span", null, h.m, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: "0.46em",
      fontWeight: 500,
      margin: "0 1px 0 6px",
      color: "var(--text-mid)"
    }
  }, "\xD710"), /*#__PURE__*/React.createElement("sup", {
    style: {
      fontSize: "0.42em",
      fontWeight: 600,
      top: "-0.7em"
    }
  }, h.e)), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: "0.42em",
      fontWeight: 500,
      color: "var(--text-mid)"
    }
  }, "J"));
}

/* Core + tap feedback — isolated so taps/bursts don't re-render the lists. */
function CoreZone({
  energyRef,
  jPerTap,
  showcase
}) {
  const [pressed, setPressed] = React.useState(showcase && REDUCED);
  const [bursts, setBursts] = React.useState(showcase && REDUCED ? [{
    id: 0,
    parts: [],
    text: "+" + window.KFmt.compact(jPerTap) + " J",
    stat: true
  }] : []);
  const burstId = React.useRef(1);
  const relRef = React.useRef(0);
  const doTap = React.useCallback(() => {
    energyRef.current += jPerTap;
    setPressed(true);
    window.clearTimeout(relRef.current);
    relRef.current = window.setTimeout(() => setPressed(false), 140);
    if (REDUCED) return;
    const id = burstId.current++;
    const parts = Array.from({
      length: 6
    }, (_, i) => {
      const a = Math.PI * 2 / 6 * i + (Math.random() - 0.5) * 0.9;
      const d = 40 + Math.random() * 40;
      return {
        tx: Math.cos(a) * d,
        ty: Math.sin(a) * d
      };
    });
    setBursts(b => [...b, {
      id,
      parts,
      text: "+" + window.KFmt.compact(jPerTap) + " J"
    }]);
    window.setTimeout(() => setBursts(b => b.filter(x => x.id !== id)), 760);
  }, [jPerTap, energyRef]);
  React.useEffect(() => {
    if (!showcase || REDUCED) return;
    const iv = window.setInterval(doTap, 1500);
    const t0 = window.setTimeout(doTap, 350);
    return () => {
      window.clearInterval(iv);
      window.clearTimeout(t0);
    };
  }, [showcase, doTap]);
  return /*#__PURE__*/React.createElement("section", {
    className: "km-core-zone"
  }, /*#__PURE__*/React.createElement("div", {
    className: "km-core-wrap"
  }, /*#__PURE__*/React.createElement(Core, {
    size: 210,
    pressed: pressed,
    onPointerDown: e => {
      e.preventDefault();
      doTap();
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "km-burst-layer"
  }, bursts.map(b => /*#__PURE__*/React.createElement(React.Fragment, {
    key: b.id
  }, !b.stat && /*#__PURE__*/React.createElement("span", {
    className: "km-ripple"
  }), /*#__PURE__*/React.createElement("span", {
    className: "km-float" + (b.stat ? " km-static" : "")
  }, b.text), b.parts.map((p, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    className: "km-particle",
    style: {
      "--tx": p.tx + "px",
      "--ty": p.ty + "px"
    }
  })))))));
}

/* Entrance wrapper — the resting state (opacity 1, no offset) is committed by
   React via state, so content is always correct even if the transition can't
   visually play; the slide-in is pure decoration. Off under reduced motion. */
function EnterItem({
  index = 0,
  flashed,
  children
}) {
  const [shown, setShown] = React.useState(REDUCED);
  React.useEffect(() => {
    if (REDUCED) return;
    const t = window.setTimeout(() => setShown(true), 30);
    return () => window.clearTimeout(t);
  }, []);
  return /*#__PURE__*/React.createElement("div", {
    className: flashed ? "km-pop" : undefined,
    style: {
      opacity: shown ? 1 : 0,
      transform: shown ? "none" : "translateY(12px)",
      transition: REDUCED ? "none" : "opacity 320ms ease, transform 360ms cubic-bezier(0.22,0.61,0.36,1)",
      transitionDelay: REDUCED ? "0ms" : index * 50 + "ms"
    }
  }, children);
}
function KardashevApp({
  startTab = "Generators",
  showcase = false
}) {
  const [tab, setTab] = React.useState(startTab);
  const [gens, setGens] = React.useState(initialGenerators);
  const [ups, setUps] = React.useState(initialUpgrades);
  const [flash, setFlash] = React.useState({});
  const energyRef = React.useRef(1240000);
  const cascade = ups.find(u => u.id === "u3").state === "purchased";
  const coherence = ups.find(u => u.id === "u2").state === "purchased";
  const jPerSec = rateOf(gens, cascade);
  const jPerTap = 4200 * (coherence ? 3 : 1);
  const jpsRef = React.useRef(jPerSec);
  jpsRef.current = jPerSec;
  const doFlash = id => setFlash(f => ({
    ...f,
    [id]: (f[id] || 0) + 1
  }));
  const buyGen = g => {
    if (g.locked || energyRef.current < g.cost) return;
    energyRef.current -= g.cost;
    setGens(arr => arr.map(x => x.id === g.id ? {
      ...x,
      count: x.count + 1,
      cost: Math.ceil(x.cost * x.mult)
    } : x));
    doFlash(g.id);
  };
  const buyUp = u => {
    if (u.state !== "available" || energyRef.current < u.cost) return;
    energyRef.current -= u.cost;
    setUps(arr => arr.map(x => x.id === u.id ? {
      ...x,
      state: "purchased"
    } : x));
    doFlash(u.id);
  };
  return /*#__PURE__*/React.createElement("div", {
    className: "km-app" + (REDUCED ? " km-reduced" : "")
  }, /*#__PURE__*/React.createElement("header", {
    className: "km-header"
  }, /*#__PURE__*/React.createElement("div", {
    className: "km-tier"
  }, "KARDASHEV \xB7 TYPE I"), /*#__PURE__*/React.createElement(HeroCounter, {
    energyRef: energyRef,
    jpsRef: jpsRef
  }), /*#__PURE__*/React.createElement("div", {
    className: "km-chips"
  }, /*#__PURE__*/React.createElement(Chip, {
    icon: "\u25B2",
    value: window.KFmt.compact(jPerSec) + " J/s",
    tone: "accent"
  }), /*#__PURE__*/React.createElement(Chip, {
    icon: "\u2299",
    value: window.KFmt.compact(jPerTap) + " J/tap",
    tone: "mid"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 28px"
    }
  }, /*#__PURE__*/React.createElement(ProgressBar, {
    value: 0.42
  }))), /*#__PURE__*/React.createElement(CoreZone, {
    energyRef: energyRef,
    jPerTap: jPerTap,
    showcase: showcase
  }), /*#__PURE__*/React.createElement("section", {
    className: "km-sheet"
  }, /*#__PURE__*/React.createElement("div", {
    className: "km-sheet-tabs"
  }, /*#__PURE__*/React.createElement(SegmentedTabs, {
    tabs: ["Generators", "Upgrades"],
    active: tab,
    onChange: setTab
  })), /*#__PURE__*/React.createElement("div", {
    className: "km-sheet-body"
  }, /*#__PURE__*/React.createElement("div", {
    className: "km-fade"
  }), /*#__PURE__*/React.createElement("div", {
    className: "km-scroll"
  }, tab === "Generators" ? /*#__PURE__*/React.createElement("div", {
    key: "gen",
    className: "km-list"
  }, gens.map((g, i) => {
    const affordable = !g.locked && energyRef.current >= g.cost;
    const contribution = g.locked ? "Locked" : g.count > 0 ? "+" + window.KFmt.compact(g.count * g.rate) + " J/s" : "+" + window.KFmt.compact(g.rate) + " J/s ea";
    return /*#__PURE__*/React.createElement(EnterItem, {
      key: g.id,
      index: i,
      flashed: !!flash[g.id]
    }, /*#__PURE__*/React.createElement(GeneratorRow, {
      glyph: g.glyph,
      name: g.name,
      count: g.count,
      rate: contribution,
      price: g.locked ? "—" : window.KFmt.compact(g.cost) + " J",
      affordable: affordable,
      locked: g.locked,
      highlighted: g.highlight && !affordable,
      onBuy: () => buyGen(g)
    }));
  })) : /*#__PURE__*/React.createElement("div", {
    key: "up",
    className: "km-grid"
  }, ups.map((u, i) => /*#__PURE__*/React.createElement(EnterItem, {
    key: u.id,
    index: i,
    flashed: !!flash[u.id]
  }, /*#__PURE__*/React.createElement(UpgradeCard, {
    glyph: u.glyph,
    title: u.title,
    desc: u.desc,
    price: window.KFmt.compact(u.cost) + " J",
    state: u.state,
    onBuy: () => buyUp(u)
  }))))))));
}
window.KardashevApp = KardashevApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/kardashev/KardashevApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/kardashev/format.js
try { (() => {
/* KARDASHEV number formatting — scientific notation, tabular discipline. */
(function () {
  function group(n) {
    return Math.floor(n).toLocaleString("en-US");
  }
  function parts(n) {
    if (n <= 0) return {
      m: "0.00",
      e: 0
    };
    const e = Math.floor(Math.log10(n));
    let m = n / Math.pow(10, e);
    let ms = m.toFixed(2);
    if (ms === "10.00") return {
      m: "1.00",
      e: e + 1
    }; // rounding carry
    return {
      m: ms,
      e: e
    };
  }
  // Hero: "<1000" -> grouped int; else { m, e } for "m.mm × 10ⁿ"
  function hero(n) {
    if (n < 1000) return {
      plain: group(n)
    };
    return parts(n);
  }
  // Compact: "<1000" -> grouped int; else "m.mme+n"
  function compact(n) {
    if (n < 1000) return group(n);
    const p = parts(n);
    return p.m + "e" + p.e;
  }
  window.KFmt = {
    group: group,
    parts: parts,
    hero: hero,
    compact: compact
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/kardashev/format.js", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.Glyph = __ds_scope.Glyph;

__ds_ns.GlyphTile = __ds_scope.GlyphTile;

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.SegmentedTabs = __ds_scope.SegmentedTabs;

__ds_ns.Core = __ds_scope.Core;

__ds_ns.GeneratorRow = __ds_scope.GeneratorRow;

__ds_ns.UpgradeCard = __ds_scope.UpgradeCard;

})();
