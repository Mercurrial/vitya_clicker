import React from "react";

/* Segmented tabs for the bottom sheet: [ Generators | Upgrades ].
   Active segment is cyan; the pill slides via translate. */
export function SegmentedTabs({ tabs = [], active, onChange, style, ...rest }) {
  const idx = Math.max(0, tabs.indexOf(active));
  return (
    <div
      style={{
        position: "relative",
        display: "grid",
        gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
        padding: 4,
        borderRadius: "var(--radius-pill)",
        background: "rgba(0,0,0,0.28)",
        boxShadow: "inset 0 0 0 1px var(--glass-border)",
        ...style,
      }}
      {...rest}
    >
      <div
        aria-hidden="true"
        style={{
          position: "absolute",
          top: 4,
          left: 4,
          bottom: 4,
          width: `calc((100% - 8px) / ${tabs.length})`,
          transform: `translateX(${idx * 100}%)`,
          borderRadius: "var(--radius-pill)",
          background: "var(--accent)",
          boxShadow: "0 2px 12px var(--accent-glow)",
          transition: "transform 260ms cubic-bezier(0.22,0.61,0.36,1)",
        }}
      />
      {tabs.map((t) => {
        const on = t === active;
        return (
          <button
            key={t}
            type="button"
            onClick={() => onChange && onChange(t)}
            style={{
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
              WebkitTapHighlightColor: "transparent",
            }}
          >
            {t}
          </button>
        );
      })}
    </div>
  );
}
