import React from "react";

/* Stat chip — rate readouts under the hero counter (J/s, J/tap).
   tone "accent" = cyan (production), "mid" = muted (per-tap). */
export function Chip({ icon, value, tone = "mid", style, ...rest }) {
  const color = tone === "accent" ? "var(--accent)" : "var(--text-mid)";
  return (
    <span
      style={{
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
        ...style,
      }}
      {...rest}
    >
      {icon ? <span style={{ fontFamily: "var(--font-ui)", fontSize: 12, opacity: 0.9 }}>{icon}</span> : null}
      {value}
    </span>
  );
}
