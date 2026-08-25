import React from "react";

/* The star core — central tap button.
   Radial plasma-cyan gradient, dark ring, soft glow halo, idle pulse.
   `pressed` drives the pressed scale + intensified glow.
   Respects prefers-reduced-motion (pulse disabled). */
export function Core({ pressed = false, size = 210, style, children, ...rest }) {
  return (
    <button
      type="button"
      aria-label="Feed the core"
      className={`km-core${pressed ? " km-core--pressed" : ""}`}
      style={{
        position: "relative",
        width: size,
        height: size,
        flex: "none",
        borderRadius: "50%",
        border: "none",
        cursor: "pointer",
        padding: 0,
        background:
          "radial-gradient(circle at 50% 44%, #BFFCF6 0%, #34E2D6 26%, #16847C 58%, #0C2C2E 82%, #0A0D14 100%)",
        boxShadow: pressed
          ? "var(--core-glow-press), inset 0 0 40px rgba(0,0,0,0.55), inset 0 2px 12px rgba(255,255,255,0.35)"
          : "var(--core-glow-idle), inset 0 0 40px rgba(0,0,0,0.5), inset 0 2px 12px rgba(255,255,255,0.25)",
        transform: pressed ? "scale(0.96)" : "scale(1)",
        transition: "transform 120ms ease, box-shadow 160ms ease",
        WebkitTapHighlightColor: "transparent",
        outline: "none",
        ...style,
      }}
      {...rest}
    >
      <style>{`
        @keyframes km-core-pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.03); }
        }
        @media (prefers-reduced-motion: no-preference) {
          .km-core:not(.km-core--pressed) { animation: km-core-pulse 2.4s ease-in-out infinite; }
        }
      `}</style>
      {/* dark inner ring */}
      <span
        aria-hidden="true"
        style={{
          position: "absolute",
          inset: "12%",
          borderRadius: "50%",
          boxShadow: "inset 0 0 0 2px rgba(10,13,20,0.45)",
          pointerEvents: "none",
        }}
      />
      {children}
    </button>
  );
}
