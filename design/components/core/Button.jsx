import React from "react";

/* KARDASHEV button.
   Variants:
   - cta:        amber gradient pill — ONLY when an action is affordable/buyable
   - cta-ghost:  dim outline pill — buyable visually, but not affordable (price lo)
   - accent:     cyan — active/identity actions
   - ghost:      transparent, mid text
   Sizes: sm (pill, 36) / md (44). */
export function Button({
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
    whiteSpace: "nowrap",
  };

  const sizes = {
    sm: { height: 36, padding: "0 14px", fontSize: 13 },
    md: { height: 44, padding: "0 20px", fontSize: 14 },
  };

  const variants = {
    cta: {
      background: "var(--cta)",
      color: "#1A1206",
      boxShadow: "0 6px 20px var(--cta-glow), inset 0 1px 0 rgba(255,255,255,0.25)",
    },
    "cta-ghost": {
      background: "transparent",
      color: "var(--text-lo)",
      boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.10)",
    },
    accent: {
      background: "var(--accent)",
      color: "#04201E",
      boxShadow: "0 4px 16px var(--accent-glow)",
    },
    ghost: {
      background: "transparent",
      color: "var(--text-mid)",
      boxShadow: "inset 0 0 0 1px var(--glass-border)",
    },
  };

  const v = disabled ? { ...variants[variant], opacity: 0.42, boxShadow: "none" } : variants[variant];

  return (
    <button
      type="button"
      disabled={disabled}
      style={{ ...base, ...sizes[size], ...v, ...style }}
      onPointerDown={(e) => {
        if (!disabled) e.currentTarget.style.transform = "scale(0.96)";
      }}
      onPointerUp={(e) => {
        e.currentTarget.style.transform = "scale(1)";
      }}
      onPointerLeave={(e) => {
        e.currentTarget.style.transform = "scale(1)";
      }}
      {...rest}
    >
      {children}
    </button>
  );
}
