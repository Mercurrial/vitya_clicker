import React from "react";
import { GlyphName } from "../core/Glyph";

export type UpgradeState = "available" | "locked" | "purchased";

export interface UpgradeCardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Geometric glyph name. */
  glyph: GlyphName;
  /** Upgrade title, e.g. "Fusion Overclock". */
  title: string;
  /** Effect description, e.g. "Fusion Core ×2". */
  desc: React.ReactNode;
  /** Mono price string. */
  price: React.ReactNode;
  /**
   * available -> amber border/glow + active Buy.
   * locked -> dimmed + greyscale. purchased -> check + struck price + faded.
   */
  state?: UpgradeState;
  onBuy?: () => void;
}

/** Upgrade card for the 2-column Upgrades grid (one-time multipliers). */
export function UpgradeCard(props: UpgradeCardProps): JSX.Element;
