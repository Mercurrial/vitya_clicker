import React from "react";

export type ButtonVariant = "cta" | "cta-ghost" | "accent" | "ghost";
export type ButtonSize = "sm" | "md";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /**
   * cta — amber gradient, ONLY when affordable/buyable.
   * cta-ghost — dim outline for a buy the player cannot yet afford.
   * accent — cyan identity actions. ghost — neutral.
   */
  variant?: ButtonVariant;
  /** sm = 36px pill, md = 44px. Default md. */
  size?: ButtonSize;
  disabled?: boolean;
  children?: React.ReactNode;
}

/** Pill button. Amber CTA is reserved for affordable purchases (<=10% of the UI). */
export function Button(props: ButtonProps): JSX.Element;
