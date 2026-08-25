Pill button for KARDASHEV. Amber `cta` is reserved strictly for affordable purchases; everything else is cyan `accent`, neutral `ghost`, or `cta-ghost` (an unaffordable buy).

```jsx
<Button variant="cta" size="sm">2.40e6 J</Button>
<Button variant="accent">Activate</Button>
<Button variant="ghost" disabled>Locked</Button>
```

Has a built-in press shrink (scale 0.96). Use `cta` only when the player can afford the action — switch to `cta-ghost` when they can't, so amber never leaks onto unavailable items.
