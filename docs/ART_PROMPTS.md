# Промпты для генерации спрайтов

Куда класть: **`assets/images/stills/`**
Имя файла: **`<id>.png`** — id должен совпадать с идентификатором аппарата в
`lib/content/game_content.dart`, иначе спрайт не подхватится.

Формат: **PNG с прозрачным фоном**, квадрат. Любой размер от 256×256 —
уменьшением и приведением к палитре займётся код (`PixelPortraitCache` уже
это умеет), поэтому гнаться за точными 64×64 не нужно.

---

## Общий блок стиля

**Добавляй его к КАЖДОМУ промпту без изменений** — именно он делает 13 разных
генераций одним миром. Меняется только описание предмета.

```
pixel art sprite, 64x64 pixel grid, crisp square pixels, no anti-aliasing,
no dithering, transparent background, single object centered, side view,
orthographic, light source from upper-left, soft contact shadow at the base,
limited warm palette: dark brown #120D08, copper #A55E2E #C87941 #E8A868,
steel #6E6459 #9A8F80, glass #46605A #6E8C82, amber liquid #D8C48A #F2E2B8,
fire #FF8A00 #FFC24B, cozy garage workshop mood, no text, no letters,
no watermark, no background elements
```

---

## 1. `banka.png` — Трёхлитровая банка
```
A three-litre glass jar filled two-thirds with cloudy amber homebrew,
metal screw lid, a few bubbles rising, simple and humble.
```

## 2. `bidon.png` — Бидон эмалированный
```
An old enamelled milk can with a carrying handle and a dented lid,
scuffed white-and-blue enamel over steel, standing upright.
```

## 3. `flyaga.png` — Фляга армейская
```
A flat army canteen flask in a worn canvas cover with a narrow screw neck
and a short strap, military green fabric over metal.
```

## 4. `dedov.png` — Аппарат «Дедов»
```
A small handmade copper pot still: rounded copper boiler with a riveted
seam, domed lid, a copper pipe curving up and to the right into a coiled
condenser, a glass jar catching a drop, small orange flame underneath.
```

## 5. `zmeevik.png` — Медный змеевик
```
A copper cooling coil: a spiral copper tube of five clear turns mounted in
a metal water barrel, one droplet falling from the lower outlet.
```

## 6. `tseh.png` — Гаражный цех
```
A garage workbench with three linked copper stills of different heights
connected by pipes, tools hanging above, a workshop set-up rather than a
single device.
```

## 7. `podval.png` — Подвал у Петровича
```
A cellar brewing station: two large wooden barrels and a steel tank under
a low brick arch, a bare hanging bulb, hoses running between them.
```

## 8. `tsisterna.png` — Цистерна «МОЛОКО»
```
A road tanker trailer barrel, dairy-white with a big riveted steel band,
resting on chocks, a small hatch on top, clearly repurposed.
```

## 9. `druzhba.png` — Трубопровод «Дружба-2»
```
An industrial pipeline junction: thick pipes on concrete supports with
valve wheels and a pressure gauge, running left to right, rust and steel.
```

## 10. `zavod.png` — Завод «Кристалл-Витя»
```
A small distillery plant: two tall stainless columns, a boiler, catwalks
and a chimney with a wisp of steam, seen as a compact factory block.
```

## 11. `tanker.png` — Танкер «Первач»
```
A sea tanker ship carrying a huge riveted barrel instead of cargo holds,
bridge tower at the stern, waterline visible, industrial and absurd.
```

## 12. `orbita.png` — Орбитальная «Мир-2»
```
An orbital station module built around a giant copper still, solar panels
on both sides, docking port, antenna, a soft glow from the boiler.
```

## 13. `collider.png` — Самогонный коллайдер
```
A circular particle collider ring made of copper tubing with glowing amber
plasma inside, magnets and cables around the ring, a small still at its
centre, science-fiction scale.
```

---

## Как проверять результат

1. Предмет **узнаётся по силуэту** — закрой глаза на цвет, форма должна читаться.
2. Свет **сверху-слева** — если тень легла иначе, перегенерируй.
3. Фон **прозрачный**, без подложки и рамки.
4. Один предмет в кадре, по центру, без обрезки по краям.

Если генератор упорно рисует фон — попроси `isolated on transparent background,
alpha channel, cutout sticker` и вырежи фон любым удалятором.

---

## Что ещё понадобится позже (не сейчас)

- `assets/images/buyers/petrovich.png` — сосед-скупщик
- `assets/images/buyers/uchastkovyi.png` — участковый Николай Петрович
- `assets/images/ui/garage_bg.png` — фон гаража, если захотим детальнее кирпича
