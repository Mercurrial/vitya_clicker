#!/usr/bin/env python3
"""Мастерская спрайтов: собираем пиксель-арт геометрией, а не набором строк.

Рисовать 32 строки по 32 символа руками — значит гарантированно получить кривые
окружности и разъехавшуюся светотень. Здесь форма задаётся примитивами, а
затенение накладывается по единому правилу «свет сверху-слева», поэтому все
аппараты выглядят частями одного мира.

    python tools/sprite_lab.py          — проверить и вывести сетку
    python tools/sprite_lab.py --dart   — выдать готовый Dart-литерал
"""

import math
import sys

W = H = 32

# Ключи палитры. Для каждого материала — лестница из четырёх тонов,
# иначе объём не читается и предмет выглядит наклейкой.
#   c/C/d/D — медь: тень, база, свет, блик
#   m/M/n/N — сталь
#   g/G/h   — стекло
#   b/B/w   — брага и самогон
#   f/F/r/R — огонь
#   k       — контур, s — контактная тень
TRANSPARENT = "."


def blank():
    return [[TRANSPARENT] * W for _ in range(H)]


def put(g, x, y, ch):
    if 0 <= x < W and 0 <= y < H:
        g[y][x] = ch


def get(g, x, y):
    if 0 <= x < W and 0 <= y < H:
        return g[y][x]
    return TRANSPARENT


def fill_rect(g, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(g, x, y, ch)


def fill_ellipse(g, cx, cy, rx, ry, ch):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if rx == 0 or ry == 0:
                continue
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                put(g, x, y, ch)


def stroke_ellipse(g, cx, cy, rx, ry, ch, steps=180):
    for i in range(steps):
        a = 2 * math.pi * i / steps
        put(g, round(cx + rx * math.cos(a)), round(cy + ry * math.sin(a)), ch)


def line(g, x0, y0, x1, y1, ch):
    """Прямая по Брезенхэму — без сглаживания, как и положено пикселю."""
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        put(g, x0, y0, ch)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def shade(g, base, shadow, light, highlight):
    """Светотень по единому правилу: лампа висит сверху-слева.

    Пиксель базового цвета становится светлым, если слева/сверху от него
    пусто (значит, это освещённая грань), и уходит в тень у правого и нижнего
    края. Так все предметы освещены одинаково и собираются в одну сцену.
    """
    src = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if src[y][x] != base:
                continue
            left_open = src[y][x - 1] if x > 0 else TRANSPARENT
            up_open = src[y - 1][x] if y > 0 else TRANSPARENT
            right_open = src[y][x + 1] if x < W - 1 else TRANSPARENT
            down_open = src[y + 1][x] if y < H - 1 else TRANSPARENT

            lit = left_open in (TRANSPARENT, "k") or up_open in (TRANSPARENT, "k")
            dark = right_open in (TRANSPARENT, "k") or down_open in (TRANSPARENT, "k")

            if lit and up_open in (TRANSPARENT, "k") and left_open in (TRANSPARENT, "k"):
                g[y][x] = highlight
            elif lit:
                g[y][x] = light
            elif dark:
                g[y][x] = shadow


def outline(g, ch="k"):
    """Контур только по внешнему силуэту — внутри форму держит светотень."""
    src = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if src[y][x] != TRANSPARENT:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = get_src(src, x + dx, y + dy)
                if nb not in (TRANSPARENT, ch):
                    put(g, x, y, ch)
                    break


def get_src(src, x, y):
    if 0 <= x < W and 0 <= y < H:
        return src[y][x]
    return TRANSPARENT


def ground_shadow(g, cx, y, rx):
    """Контактная тень — без неё предмет висит в воздухе."""
    for x in range(cx - rx, cx + rx + 1):
        if 0 <= x < W:
            t = abs(x - cx) / max(rx, 1)
            if t < 0.95 and get(g, x, y) == TRANSPARENT:
                put(g, x, y, "s")


# --------------------------------------------------------------------------
# Аппарат «Дедов»: куб на огне, отвод, змеевик, приёмная банка.
# Эталон, по которому равняются остальные.
# --------------------------------------------------------------------------
def dedov():
    g = blank()

    # Приёмная банка справа — рисуем первой, она уходит за змеевик.
    fill_rect(g, 23, 21, 28, 26, "G")
    fill_rect(g, 24, 23, 27, 25, "B")

    # Куб: тулово и купол.
    fill_rect(g, 5, 12, 17, 24, "C")
    fill_ellipse(g, 11, 12, 6, 4, "C")

    # Обод по середине тулова — читается как клёпаный шов.
    fill_rect(g, 5, 18, 17, 18, "c")

    # Отвод: вверх из купола, дуга вправо.
    line(g, 12, 7, 12, 4, "C")
    line(g, 12, 4, 20, 4, "C")
    line(g, 20, 4, 24, 7, "C")

    # Змеевик: три витка холодильника.
    for i, cy in enumerate((10, 14, 18)):
        stroke_ellipse(g, 25, cy, 4, 2, "C")

    # Капля на выходе.
    put(g, 25, 20, "B")

    # Огонь под кубом.
    for x in range(6, 17):
        h = 2 + (x % 3)
        for y in range(25, 25 + h):
            put(g, x, y, "F")
    for x in range(8, 15):
        put(g, x, 25, "R")

    shade(g, "C", "c", "d", "D")
    shade(g, "G", "g", "h", "h")
    shade(g, "B", "b", "w", "w")
    shade(g, "F", "f", "r", "R")
    outline(g)
    ground_shadow(g, 12, 28, 10)
    return g


SPRITES = {"dedov": dedov}


def render(g):
    return ["".join(row) for row in g]


def validate(rows, name):
    problems = []
    if len(rows) != H:
        problems.append(f"{name}: строк {len(rows)}, ожидалось {H}")
    for i, r in enumerate(rows):
        if len(r) != W:
            problems.append(f"{name}: строка {i} длиной {len(r)}, ожидалось {W}")
    return problems


if __name__ == "__main__":
    as_dart = "--dart" in sys.argv
    for name, fn in SPRITES.items():
        rows = render(fn())
        problems = validate(rows, name)
        if problems:
            print("\n".join(problems))
            sys.exit(1)
        if as_dart:
            print(f"const _{name} = PixelSprite([")
            for r in rows:
                print(f"  '{r}',")
            print("]);")
        else:
            print(f"--- {name} ({W}x{H}) ---")
            for r in rows:
                print(r)
            used = sorted({ch for r in rows for ch in r if ch != TRANSPARENT})
            print("использовано ключей:", "".join(used))
