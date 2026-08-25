import React from "react";

export interface CoreProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Pressed state: scale 0.96 + intensified glow. Drive briefly on tap. */
  pressed?: boolean;
  /** Diameter in px. Default 210. */
  size?: number;
  /** Optional overlay nodes (ripple, particles, floating text). */
  children?: React.ReactNode;
}

/**
 * Central star-core tap button — radial plasma gradient, dark ring, glow halo, idle pulse.
 * Idle pulse is disabled under prefers-reduced-motion.
 */
export function Core(props: CoreProps): JSX.Element;
