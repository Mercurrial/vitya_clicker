A generator list row for the Generators tab — glyph tile, name + ×N owned + J/s contribution, and a Buy price pill.

```jsx
<GeneratorRow glyph="fusion" name="Fusion Core" count={12}
  rate="+2.40e9 J/s" price="1.20e7 J" affordable onBuy={buy} />
```

`affordable` turns the Buy pill amber (dim otherwise). `locked` greyscales + dims the whole row for not-yet-unlocked generators. `highlighted` gives a cyan edge to the next available unlock. Pass pre-formatted mono strings for `rate` and `price`.
