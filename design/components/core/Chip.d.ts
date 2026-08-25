import React from "react";

export interface ChipProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Leading symbol, e.g. "▲" or "⊙". */
  icon?: React.ReactNode;
  /** Mono, tabular value string, e.g. "1.34e18 J/s". */
  value: React.ReactNode;
  /** accent = cyan production rate, mid = muted per-tap. Default mid. */
  tone?: "accent" | "mid";
}

/** Small mono stat pill for the rate readouts beneath the hero counter. */
export function Chip(props: ChipProps): JSX.Element;
