Mono stat pill for the rate readouts under the hero counter.

```jsx
<Chip icon="▲" value="1.34e18 J/s" tone="accent" />
<Chip icon="⊙" value="8.00e15 J/tap" tone="mid" />
```

Always feed it pre-formatted mono strings (tabular figures hold the width). `tone="accent"` for production (J/s), `mid` for per-tap.
