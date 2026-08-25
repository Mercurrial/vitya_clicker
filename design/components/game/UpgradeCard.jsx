import React from "react";
import { Glyph } from "../core/Glyph.jsx";
import { Button } from "../core/Button.jsx";

/* Upgrade card (grid, 2-up). One-time multiplier.
   States:
   - available:  amber border + soft amber glow + active Buy
   - locked:     dimmed
   - purchased:  check marker + struck-through price + opacity ~0.4 */
export function UpgradeCard({
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

  return (
    <div
      style={{
        position: "relative",
        display: "flex",
        flexDirection: "column",
        gap: 8,
        padding: "14px 14px 16px",
        borderRadius: "var(--radius-card)",
        background: "var(--surface-2)",
        boxShadow: available
          ? "inset 0 0 0 1px var(--cta-solid), 0 0 18px var(--cta-glow)"
          : "inset 0 0 0 1px var(--glass-border)",
        opacity: purchased ? 0.4 : locked(state) ? 0.5 : 1,
        filter: locked(state) ? "grayscale(0.8)" : "none",
        transition: "opacity 240ms ease, box-shadow 240ms ease, filter 240ms ease",
        ...style,
      }}
      {...rest}
    >
      {purchased && (
        <span
          aria-hidden="true"
          style={{
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
            justifyContent: "center",
          }}
        >
          ✓
        </span>
      )}

      <Glyph name={glyph} size={24} tint={available} />

      <div
        style={{
          fontFamily: "var(--font-ui)",
          fontSize: 14,
          fontWeight: 600,
          color: "var(--text-hi)",
          lineHeight: 1.2,
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontFamily: "var(--font-ui)",
          fontSize: "var(--type-desc-size)",
          color: "var(--text-mid)",
          lineHeight: 1.35,
          flex: 1,
        }}
      >
        {desc}
      </div>

      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 4 }}>
        <span
          style={{
            fontFamily: "var(--font-mono)",
            fontVariantNumeric: "tabular-nums",
            fontSize: "var(--type-price-size)",
            fontWeight: 600,
            color: purchased ? "var(--text-lo)" : available ? "var(--cta-solid)" : "var(--text-lo)",
            textDecoration: purchased ? "line-through" : "none",
          }}
        >
          {price}
        </span>
        {!purchased && (
          <Button
            variant={available ? "cta" : "cta-ghost"}
            size="sm"
            disabled={!available}
            onClick={onBuy}
            style={{ minWidth: 64, height: 32 }}
          >
            Buy
          </Button>
        )}
      </div>
    </div>
  );
}

function locked(state) {
  return state === "locked";
}
