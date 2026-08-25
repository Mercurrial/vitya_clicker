import React from "react";
import { GlyphTile } from "../core/GlyphTile.jsx";
import { Button } from "../core/Button.jsx";

/* A generator list row.
   left: geometric glyph tile (cyan tint if owned/active)
   center: name + "×N" owned + J/s contribution
   right: Buy pill with price (amber if affordable, dim if not)
   States: locked (greyscale + dim), highlighted (next unlock — cyan edge). */
export function GeneratorRow({
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
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: "var(--space-3)",
        padding: "10px 12px",
        borderRadius: "var(--radius-card)",
        background: highlighted ? "var(--surface-3)" : "var(--surface-2)",
        boxShadow: highlighted
          ? "inset 0 0 0 1px rgba(52,226,214,0.45), 0 0 18px rgba(52,226,214,0.10)"
          : "inset 0 0 0 1px var(--glass-border)",
        filter: locked ? "grayscale(1)" : "none",
        opacity: locked ? 0.45 : 1,
        transition: "background 220ms ease, box-shadow 220ms ease, opacity 220ms ease",
        ...style,
      }}
      {...rest}
    >
      <GlyphTile name={glyph} active={active} size={44} />

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
          <span
            style={{
              fontFamily: "var(--font-ui)",
              fontSize: "var(--type-name-size)",
              fontWeight: "var(--type-name-weight)",
              color: "var(--text-hi)",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {name}
          </span>
          {count > 0 && (
            <span
              style={{
                fontFamily: "var(--font-mono)",
                fontVariantNumeric: "tabular-nums",
                fontSize: 12,
                fontWeight: 600,
                color: "var(--accent)",
              }}
            >
              ×{count}
            </span>
          )}
        </div>
        <div
          style={{
            fontFamily: "var(--font-mono)",
            fontVariantNumeric: "tabular-nums",
            fontSize: 12,
            color: "var(--text-mid)",
            marginTop: 2,
          }}
        >
          {rate}
        </div>
      </div>

      <Button
        variant={affordable ? "cta" : "cta-ghost"}
        size="sm"
        disabled={locked}
        onClick={onBuy}
        style={{ minWidth: 84 }}
      >
        {price}
      </Button>
    </div>
  );
}
