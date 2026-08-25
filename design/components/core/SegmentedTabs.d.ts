import React from "react";

export interface SegmentedTabsProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Ordered tab labels, e.g. ["Generators", "Upgrades"]. */
  tabs: string[];
  /** Currently active label. */
  active: string;
  /** Called with the newly selected label. */
  onChange?: (tab: string) => void;
}

/** Segmented control with a sliding cyan thumb. Used for the bottom-sheet tabs. */
export function SegmentedTabs(props: SegmentedTabsProps): JSX.Element;
