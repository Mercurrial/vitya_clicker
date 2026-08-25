import React from "react";

export type GlyphName =
  | "photovoltaic" | "geothermal" | "fusion" | "antimatter"
  | "dyson" | "neutron" | "blackhole" | "galactic"
  | "overclock" | "coherence" | "cascade" | "zeropoint" | "catalyst" | "horizon";

export interface GlyphProps extends React.SVGProps<SVGSVGElement> {
  /** Which geometric glyph to render. */
  name: GlyphName;
  /** Pixel size of the square glyph. Default 22. */
  size?: number;
  /** Cyan tint when the related entity is active/unlocked. Default false (mid grey). */
  tint?: boolean;
}

/** Minimalist stroked geometric glyph for generators and upgrades. */
export function Glyph(props: GlyphProps): JSX.Element;
