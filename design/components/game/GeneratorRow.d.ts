import React from "react";
import { GlyphName } from "../core/Glyph";

export interface GeneratorRowProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Geometric glyph name for this generator. */
  glyph: GlyphName;
  /** Generator name, e.g. "Fusion Core". */
  name: string;
  /** Number owned; shows "×N" and tints the glyph when > 0. */
  count?: number;
  /** Mono contribution string, e.g. "+2.40e9 J/s". */
  rate: React.ReactNode;
  /** Mono price string, e.g. "1.20e7 J". */
  price: React.ReactNode;
  /** Player can afford it -> amber Buy pill. Default false. */
  affordable?: boolean;
  /** Not yet unlocked -> greyscale + dimmed whole row. Default false. */
  locked?: boolean;
  /** Nearest available to unlock -> cyan-edged highlight. Default false. */
  highlighted?: boolean;
  onBuy?: () => void;
}

/** One generator row: glyph tile · name/count/rate · Buy pill. */
export function GeneratorRow(props: GeneratorRowProps): JSX.Element;
