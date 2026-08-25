import React from "react";

/* Kardashev-scale progress bar — thin cyan fill on a dark track. */
export function ProgressBar({ value = 0, style, ...rest }) {
  const pct = Math.max(0, Math.min(1, value)) * 100;
  return (
    <div
      style={{
        height: 4,
        borderRadius: "var(--radius-pill)",
        background: "rgba(255,255,255,0.07)",
        overflow: "hidden",
        ...style,
      }}
      {...rest}
    >
      <div
        style={{
          height: "100%",
          width: `${pct}%`,
          borderRadius: "var(--radius-pill)",
          background: "linear-gradient(90deg, var(--accent-dim), var(--accent))",
          boxShadow: "0 0 12px var(--accent-glow)",
          transition: "width 240ms ease",
        }}
      />
    </div>
  );
}
