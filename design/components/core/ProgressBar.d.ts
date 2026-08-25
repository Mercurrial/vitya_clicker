import React from "react";

export interface ProgressBarProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Fill fraction 0..1. */
  value: number;
}

/** Thin cyan progress bar for the Kardashev tier scale. */
export function ProgressBar(props: ProgressBarProps): JSX.Element;
