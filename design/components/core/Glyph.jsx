import React from "react";

/* Minimalist geometric glyphs for KARDASHEV generators & upgrades.
   Pure stroked geometry — no skeuomorphism. Inherits currentColor. */

const PATHS = {
  // Generators (Kardashev ladder)
  photovoltaic: (
    <g>
      <rect x="5" y="5" width="6" height="6" rx="1" />
      <rect x="13" y="5" width="6" height="6" rx="1" />
      <rect x="5" y="13" width="6" height="6" rx="1" />
      <rect x="13" y="13" width="6" height="6" rx="1" />
    </g>
  ),
  geothermal: (
    <g>
      <path d="M12 4 L19 18 H5 Z" />
      <path d="M12 11 L15.5 18 H8.5 Z" />
    </g>
  ),
  fusion: (
    <g>
      <circle cx="12" cy="12" r="3.2" />
      <ellipse cx="12" cy="12" rx="8" ry="3.4" />
      <ellipse cx="12" cy="12" rx="8" ry="3.4" transform="rotate(60 12 12)" />
    </g>
  ),
  antimatter: (
    <g>
      <circle cx="9" cy="12" r="5" />
      <circle cx="15" cy="12" r="5" />
    </g>
  ),
  dyson: (
    <g>
      <circle cx="12" cy="12" r="2.4" />
      <path d="M5 12 A7 7 0 0 1 19 12" />
      <path d="M19 12 A7 7 0 0 1 5 12" stroke-dasharray="2 2.4" />
    </g>
  ),
  neutron: (
    <g>
      <path d="M12 4 L19 8 V16 L12 20 L5 16 V8 Z" />
      <circle cx="12" cy="12" r="2" />
    </g>
  ),
  blackhole: (
    <g>
      <circle cx="12" cy="12" r="6.5" />
      <circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none" />
    </g>
  ),
  galactic: (
    <g>
      <path d="M4 18 C9 14 9 10 12 8 C15 6 18 6 20 6" />
      <path d="M4 18 C6 18 9 18 12 16 C15 14 15 10 20 6" stroke-dasharray="2 2.4" />
    </g>
  ),
  // Upgrades
  overclock: (
    <g>
      <path d="M6 14 L12 8 L18 14" />
      <path d="M6 18 L12 12 L18 18" />
    </g>
  ),
  coherence: (
    <g>
      <circle cx="12" cy="12" r="2" />
      <circle cx="12" cy="12" r="5" />
      <circle cx="12" cy="12" r="8" stroke-dasharray="2 2.6" />
    </g>
  ),
  cascade: (
    <g>
      <path d="M4 14 Q8 8 12 14 T20 14" />
      <path d="M4 18 Q8 12 12 18 T20 18" stroke-dasharray="2 2.4" />
    </g>
  ),
  zeropoint: (
    <g>
      <circle cx="12" cy="12" r="2.2" fill="currentColor" stroke="none" />
      <path d="M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20" />
    </g>
  ),
  catalyst: (
    <g>
      <path d="M12 4 V8 M12 16 V20 M4 12 H8 M16 12 H20 M6.5 6.5 L9 9 M15 15 L17.5 17.5 M17.5 6.5 L15 9 M9 15 L6.5 17.5" />
      <circle cx="12" cy="12" r="2.4" />
    </g>
  ),
  horizon: (
    <g>
      <ellipse cx="12" cy="12" rx="8" ry="3" />
      <circle cx="12" cy="12" r="2.6" fill="currentColor" stroke="none" />
    </g>
  ),
};

export function Glyph({ name, size = 22, tint = false, style, ...rest }) {
  const color = tint ? "var(--accent)" : "var(--text-mid)";
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke={color}
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ display: "block", ...style }}
      {...rest}
    >
      {PATHS[name] || PATHS.fusion}
    </svg>
  );
}
