import React from "react";
import { GlyphName } from "./Glyph";

export interface GlyphTileProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Glyph to display. */
  name: GlyphName;
  /** Cyan-tinted tile when the entity is active/unlocked. Default false. */
  active?: boolean;
  /** Square edge length in px. Default 44. */
  size?: number;
}

/** Rounded tile containing a geometric glyph, used as the leading element of rows and cards. */
export function GlyphTile(props: GlyphTileProps): JSX.Element;
