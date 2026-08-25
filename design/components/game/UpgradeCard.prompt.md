Upgrade card for the 2-column Upgrades grid — one-time multipliers. Glyph, title, effect description, price, Buy.

```jsx
<UpgradeCard glyph="overclock" title="Fusion Overclock"
  desc="Fusion Core ×2" price="3.40e8 J" state="available" onBuy={buy} />
```

`state="available"` gives an amber border + glow and an active Buy; `locked` dims + greyscales; `purchased` shows a cyan check, struck-through price, and fades to ~0.4. Lay out two per row with a 12px gap.
