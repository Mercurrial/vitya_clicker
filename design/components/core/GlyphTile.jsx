import React from "react";
import { Glyph } from "./Glyph.jsx";

/* Rounded tile holding a geometric glyph. Gets a faint cyan tint when active. */
export function GlyphTile({ name, active = false, size = 44, style, ...rest }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        flex: "none",
        borderRadius: "var(--radius-button)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: active ? "rgba(52,226,214,0.12)" : "rgba(255,255,255,0.04)",
        boxShadow: active
          ? "inset 0 0 0 1px rgba(52,226,214,0.35)"
          : "inset 0 0 0 1px var(--glass-border)",
        transition: "background 220ms ease, box-shadow 220ms ease",
        ...style,
      }}
      {...rest}
    >
      <Glyph name={name} size={Math.round(size * 0.5)} tint={active} />
    </div>
  );
}
