#!/usr/bin/env python3
"""Баннер игры: шапка README, превью ссылки в мессенджерах, обложка репозитория.

Одна картинка 1280×640 на все три места — такой размер GitHub просит для
обложки, а Telegram и WhatsApp показывают его без обрезки.

    python tools/make_banner.py        — переписать web/og.png

Картинка лежит в web/, потому что превью ссылки берёт её с сайта: мессенджер
видит только то, что выложено, а не то, что лежит в репозитории.

Ничего не рисуется заново. Аппараты — из tools/sprite_lab.py, Витя — из
tools/make_icons.dart: копия рисунка здесь разошлась бы с иконкой с первой же
правки. Буквы — свой пиксельный шрифт ниже: шрифт из системы нарисовал бы
гладкие буквы посреди пиксель-арта.
"""

import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_lab  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "web", "og.png")

SCALE = 2                      # один пиксель рисунка — 2×2 точки картинки
W, H = 1280 // SCALE, 640 // SCALE

TITLE = "ВИТЯ В ДЕЛЕ"
SUBTITLE = "ОТ БАНКИ ДО КОЛЛАЙДЕРА"

# --------------------------------------------------------------------------
# Шрифт: 5×7, только буквы, которые нужны. Строка выше заглавной — под
# кратку «Й»: без неё «Й» не отличить от «И».
# --------------------------------------------------------------------------
FONT = {
    "А": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "Б": ["#####", "#....", "#....", "####.", "#...#", "#...#", "####."],
    "В": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "Д": ["..##.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"],
    "Е": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "И": ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
    "Й": [".###.", "#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
    "К": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "Л": ["..###", ".#..#", ".#..#", ".#..#", ".#..#", ".#..#", "#...#"],
    "Н": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "О": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "Р": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Т": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "Я": [".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"],
    " ": ["....."] * 7,
}


def text_width(text, px):
    return len(text) * 6 * px - px


def draw_text(canvas, text, x, y, px, face, shadow):
    """Буквы с тенью на пиксель вниз-вправо — иначе янтарь тонет в кирпиче."""
    for colour, dx, dy in ((shadow, px, px), (face, 0, 0)):
        cx = x
        for ch in text:
            glyph = FONT[ch]
            top = y - (len(glyph) - 7) * px
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "#":
                        rect(canvas, cx + gx * px + dx, top + gy * px + dy, px, px, colour)
            cx += 6 * px


# --------------------------------------------------------------------------
# Витя — из генератора иконки.
# --------------------------------------------------------------------------


def load_vitya():
    src = open(os.path.join(ROOT, "tools", "make_icons.dart"), encoding="utf-8").read()
    art_block = src.split("const List<String> _art = [", 1)[1].split("];", 1)[0]
    rows = re.findall(r"^\s*'([^']+)',", art_block, re.M)
    pal_block = src.split("const Map<String, int> _palette = {", 1)[1].split("};", 1)[0]
    palette = {k: int(v, 16) for k, v in re.findall(r"'(.)': 0x([0-9A-Fa-f]{8})", pal_block)}
    inset = int(re.search(r"const int _inset = (\d+);", src).group(1))
    side = len(rows) - 2 * inset
    crop = [r[inset:inset + side] for r in rows[inset:inset + side]]
    return crop, palette


def icon_background(x, y, n):
    """Тот же янтарь, что `_background` в make_icons.dart, в координатах поля."""
    field = 48
    t = y / (field - 1)
    base = mix(0xF2B04A, 0xB8641A, t)
    d = math.hypot(x - field * 0.3, y - field * 0.18) / (field * 0.95)
    glow = max(0.0, 1 - d)
    return mix(base, 0xFFD98A, glow * glow * 0.6)


# --------------------------------------------------------------------------
# Холст
# --------------------------------------------------------------------------


def rgb(v):
    return v if isinstance(v, tuple) else ((v >> 16) & 255, (v >> 8) & 255, v & 255)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(rgb(a), rgb(b)))


def rect(canvas, x0, y0, w, h, colour, alpha=1.0):
    for y in range(max(0, y0), min(H, y0 + h)):
        for x in range(max(0, x0), min(W, x0 + w)):
            blend(canvas, x, y, colour, alpha)


def blend(canvas, x, y, colour, alpha=1.0):
    if not (0 <= x < W and 0 <= y < H):
        return
    if alpha >= 1:
        canvas[y][x] = colour
        return
    old = canvas[y][x]
    canvas[y][x] = tuple(round(o + (c - o) * alpha) for o, c in zip(old, colour))


def wall(canvas):
    """Кирпич гаража в полутьме, свет лампы — над заголовком."""
    lamp_x, lamp_y = 44 + 150, 30
    for y in range(H):
        for x in range(W):
            row = y // 8
            shift = 8 if row % 2 else 0
            mortar = y % 8 == 7 or (x + shift) % 24 == 23
            base = 0x1E150E if mortar else (0x2E2016 if (x + shift) // 24 % 3 else 0x33241A)
            d = math.hypot((x - lamp_x) / 1.8, y - lamp_y) / (W * 0.5)
            light = max(0.0, 1 - d) ** 2
            canvas[y][x] = mix(base, 0x8A5A2F, light * 0.55)
    # по краям темнее: взгляд идёт в середину
    for y in range(H):
        for x in range(W):
            e = min(x, W - 1 - x, y, H - 1 - y) / 60
            if e < 1:
                blend(canvas, x, y, (0x14, 0x10, 0x0C), (1 - e) * 0.5)


def shelf(canvas, y):
    rect(canvas, 0, y, W, 1, (0x98, 0x69, 0x3F))
    rect(canvas, 0, y + 1, W, 5, (0x74, 0x50, 0x2F))
    rect(canvas, 0, y + 6, W, 2, (0x4A, 0x2F, 0x1C))
    rect(canvas, 0, y + 8, W, 3, (0x14, 0x10, 0x0C), 0.6)


def draw_sprite(canvas, rows, x0, y0, palette):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == sprite_lab.T:
                continue
            v = palette[ch]
            alpha = ((v >> 24) & 0xFF) / 255 if v > 0xFFFFFF else 1.0
            blend(canvas, x0 + x, y0 + y, ((v >> 16) & 255, (v >> 8) & 255, v & 255), alpha)


def tile(canvas, crop, palette, x0, y0, scale):
    """Иконка плашкой со скруглёнными углами и тенью — как на экране телефона."""
    n = len(crop)
    size = n * scale
    r = size * 0.22

    def inside(x, y):
        cx = min(max(x, r), size - r)
        cy = min(max(y, r), size - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

    for y in range(size):
        for x in range(size):
            if inside(x + 0.5, y + 0.5):
                blend(canvas, x0 + x + 3, y0 + y + 4, (0x0A, 0x08, 0x06), 0.55)
    for y in range(size):
        for x in range(size):
            if not inside(x + 0.5, y + 0.5):
                continue
            ch = crop[y // scale][x // scale]
            if ch == ".":
                inset = (48 - n) // 2
                colour = icon_background(x // scale + inset, y // scale + inset, n)
            else:
                v = palette[ch]
                colour = ((v >> 16) & 255, (v >> 8) & 255, v & 255)
            blend(canvas, x0 + x, y0 + y, colour)


def lamp(canvas, x, y):
    """Лампочка на шнуре, как в гараже игры: от неё и свет на стене."""
    rect(canvas, x, 0, 1, y, (0x14, 0x10, 0x0C))
    rect(canvas, x - 2, y, 5, 3, (0x3A, 0x2A, 0x1A))
    for gy in range(-14, 22):
        for gx in range(-14, 15):
            d = math.hypot(gx, gy - 6) / 14
            if d < 1:
                blend(canvas, x + gx, y + gy, (0xFF, 0xD9, 0x8A), (1 - d) ** 2 * 0.35)
    rect(canvas, x - 3, y + 3, 7, 6, (0xFF, 0xC7, 0x66))
    rect(canvas, x - 2, y + 9, 5, 2, (0xFF, 0xC7, 0x66))
    rect(canvas, x - 2, y + 4, 3, 4, (0xFF, 0xF0, 0xCE))


def main():
    canvas = [[(0, 0, 0)] * W for _ in range(H)]
    wall(canvas)

    left = 44
    crop, palette = load_vitya()
    scale = 4
    tile_size = len(crop) * scale
    lamp(canvas, left + 150, 16)

    # Лестница аппаратов на полке: от банки до коллайдера, как в игре.
    stills = sprite_lab.build_all()
    gap = 5
    total = sum(len(rows[0]) for _, rows in stills) + gap * (len(stills) - 1)
    shelf_y = H - 40
    shelf(canvas, shelf_y)
    x = (W - total) // 2
    for _, rows in stills:
        draw_sprite(canvas, rows, x, shelf_y - len(rows), sprite_lab.PALETTE)
        x += len(rows[0]) + gap

    draw_text(canvas, TITLE, left, 78, 6, (0xF2, 0xB0, 0x4A), (0x14, 0x10, 0x0C))
    draw_text(canvas, SUBTITLE, left + 1, 142, 3, (0xED, 0xE5, 0xD2), (0x14, 0x10, 0x0C))
    tile(canvas, crop, palette, W - left - tile_size, 62, scale)

    pixels = bytearray()
    for y in range(H * SCALE):
        row = canvas[y // SCALE]
        for x in range(W * SCALE):
            pixels += bytes((*row[x // SCALE], 255))
    sprite_lab.write_png(OUT, pixels, W * SCALE, H * SCALE)
    print(f"{os.path.relpath(OUT, ROOT)}  {W * SCALE}x{H * SCALE}")


if __name__ == "__main__":
    main()
