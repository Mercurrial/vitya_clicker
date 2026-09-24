#!/usr/bin/env python3
"""Мастерская спрайтов: аппараты собираются геометрией, а не строками руками.

Рисовать двадцать строк по тридцать символов руками — значит гарантированно
получить кривые окружности и разъехавшуюся светотень. Здесь форма задаётся
примитивами, а объём накладывается по единым правилам: свет от лампы сверху
слева, цилиндры отдельной растяжкой. Поэтому все тринадцать аппаратов выглядят
частями одного мира, а не набором наклеек из разных наборов.

    python tools/sprite_lab.py            — проверить все спрайты
    python tools/sprite_lab.py --dart     — переписать lib/ui/pixel/still_sprites_gen.dart
    python tools/sprite_lab.py --png out  — превью всех спрайтов в out.png

Спрайты обрезаются по содержимому: снизу у каждого нет пустых строк, поэтому
аппарат стоит на полке, а не висит над ней.
"""

import math
import os
import struct
import sys
import zlib

T = "."  # прозрачно

# --------------------------------------------------------------------------
# Палитра. Каждый материал — лестница тонов: тень, основа, свет, блик.
# Должна совпадать с kStillPalette в still_sprites.dart — проверяет тест.
# --------------------------------------------------------------------------
PALETTE = {
    "k": 0x1A1410,  # контур
    "s": 0x55000000,  # контактная тень (ARGB)
    # медь
    "c": 0x8C5430, "C": 0xC87941, "d": 0xE09A5C, "D": 0xF5C08A,
    # сталь
    "m": 0x5E5750, "M": 0x8E8578, "n": 0xB3AA9C, "N": 0xDDD5C7,
    # стекло
    "g": 0x3B4A47, "G": 0x5E7A73, "h": 0x86A69C, "H": 0xC4DDD3,
    # брага и самогон
    "x": 0xA89060, "b": 0xD8C48A, "B": 0xF2E2B8, "w": 0xFFF6DE,
    # эмаль, крашеное белое
    "P": 0xA89C84, "p": 0xD9CFB8, "q": 0xEDE5D2, "Q": 0xFFFBF0,
    # дерево
    "E": 0x4A2F1C, "e": 0x74502F, "o": 0x98693F, "O": 0xB88A55,
    # красная краска, кирпич
    "R": 0x6E2A1C, "r": 0xA8402A, "t": 0xC85A3E, "T": 0xE68062,
    # чугун, резина, тёмное железо
    "I": 0x201C19, "i": 0x38322D, "j": 0x544C45, "J": 0x70675E,
    # армейская зелень
    "V": 0x363F22, "v": 0x55603A, "z": 0x717E4C, "Z": 0x909C63,
    # синева: космос и кабина
    "U": 0x2E4660, "u": 0x4F7299, "l": 0x7EA2C8, "L": 0xB5D0EA,
    # свет в окнах — перекрашивается жаром
    "y": 0xFFC766, "Y": 0xFFF0C0,
    # огонь
    "1": 0xB8361A, "2": 0xFF8A00, "3": 0xFFC766, "4": 0xFFF3D6,
    # пар (полупрозрачный)
    "S": 0x55D8D0C0,
}

# Материалы: основа -> (тень, свет, блик).
MATERIALS = {
    "C": ("c", "d", "D"),
    "M": ("m", "n", "N"),
    "G": ("g", "h", "H"),
    "b": ("x", "B", "w"),
    "p": ("P", "q", "Q"),
    "e": ("E", "o", "O"),
    "r": ("R", "t", "T"),
    "i": ("I", "j", "J"),
    "v": ("V", "z", "Z"),
    "u": ("U", "l", "L"),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [[T] * w for _ in range(h)]

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return T

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch)

    def hline(self, x0, x1, y, ch):
        self.rect(x0, y, x1, y, ch)

    def vline(self, x, y0, y1, ch):
        self.rect(x, y0, x, y1, ch)

    def ellipse(self, cx, cy, rx, ry, ch):
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
                dx = (x - cx) / max(rx, 0.5)
                dy = (y - cy) / max(ry, 0.5)
                if dx * dx + dy * dy <= 1.0:
                    self.put(x, y, ch)

    def ring(self, cx, cy, rx, ry, ch, thick=1.0):
        for y in range(math.floor(cy - ry - 1), math.ceil(cy + ry) + 2):
            for x in range(math.floor(cx - rx - 1), math.ceil(cx + rx) + 2):
                dx = (x - cx) / max(rx, 0.5)
                dy = (y - cy) / max(ry, 0.5)
                d = math.sqrt(dx * dx + dy * dy)
                if abs(d - 1.0) * min(rx, ry) <= thick / 2 + 0.25:
                    self.put(x, y, ch)

    def line(self, x0, y0, x1, y1, ch):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self.put(x0, y0, ch)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def replace_in(self, x0, y0, x1, y1, src, dst):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.get(x, y) == src:
                    self.put(x, y, dst)

    # --- объём -----------------------------------------------------------

    def cylinder(self, x0, x1, y0, y1, base):
        """Растяжка по цилиндру: блик на первой четверти, тень у правого края.

        Банки, бидоны и бочки круглые, и плоская светотень по краям делает их
        коробками. Растяжка — ровно то, из-за чего цилиндр читается цилиндром.
        """
        shadow, light, hi = MATERIALS[base]
        span = max(x1 - x0, 1)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.get(x, y) != base:
                    continue
                t = (x - x0) / span
                if t < 0.08:
                    self.put(x, y, shadow if t < 0.04 and span > 8 else base)
                elif 0.18 <= t < 0.30:
                    self.put(x, y, hi if 0.22 <= t < 0.28 else light)
                elif t >= 0.80:
                    self.put(x, y, shadow)

    def shade(self, base):
        """Светотень по краям силуэта: свет сверху-слева, тень снизу-справа."""
        shadow, light, hi = MATERIALS[base]
        src = [row[:] for row in self.g]

        def at(x, y):
            if 0 <= x < self.w and 0 <= y < self.h:
                return src[y][x]
            return T

        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] != base:
                    continue
                up, left = at(x, y - 1), at(x - 1, y)
                down, right = at(x, y + 1), at(x + 1, y)
                edge = lambda ch: ch != base and ch not in MATERIALS.get(base, ())
                if edge(up) and edge(left):
                    self.g[y][x] = hi
                elif edge(up) or edge(left):
                    self.g[y][x] = light
                elif edge(down) or edge(right):
                    self.g[y][x] = shadow

    def outline(self, ch="k"):
        """Контур по внешнему силуэту. Внутри форму держит светотень."""
        src = [row[:] for row in self.g]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] != T:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h:
                        nb = src[ny][nx]
                        if nb not in (T, ch, "s") and not nb.isdigit():
                            self.g[y][x] = ch
                            break

    def trimmed(self):
        """Обрезать пустые поля. Снизу — обязательно: аппарат стоит на полке."""
        rows = ["".join(r) for r in self.g]
        filled = [i for i, r in enumerate(rows) if r.strip(T)]
        top, bottom = filled[0], filled[-1]
        cols = [x for x in range(self.w) if any(rows[y][x] != T for y in range(top, bottom + 1))]
        left, right = cols[0], cols[-1]
        out = [r[left:right + 1] for r in rows[top:bottom + 1]]
        # Чётная ширина — чтобы спрайт вставал ровно по центру полки.
        if len(out[0]) % 2:
            out = [r + T for r in out]
        return out


# --------------------------------------------------------------------------
# Аппараты. Порядок — лестница игры: от кухонной банки до коллайдера.
# Масштаб общий: высота растёт вместе с тиром, и империя видна по силуэтам.
# --------------------------------------------------------------------------


def banka():
    c = Canvas(18, 22)
    # Капроновая крышка.
    c.rect(4, 1, 12, 2, "M")
    # Горло и плечики.
    c.rect(5, 3, 11, 4, "G")
    c.rect(4, 5, 12, 5, "G")
    # Тулово.
    c.rect(3, 6, 13, 19, "G")
    c.hline(4, 12, 20, "G")
    # Брага: чуть выше середины, с пенкой.
    c.rect(4, 10, 12, 19, "b")
    c.hline(5, 11, 20, "b")
    c.hline(4, 12, 10, "B")
    c.cylinder(3, 13, 6, 20, "G")
    c.cylinder(4, 12, 11, 20, "b")
    # Пузырьки — брага живая.
    for x, y in ((7, 13), (10, 15), (6, 17), (9, 18), (11, 12)):
        c.put(x, y, "w")
    c.shade("M")
    c.outline()
    return c


def bidon():
    c = Canvas(20, 26)
    # Крышка с ручкой-«ухом».
    c.rect(8, 1, 11, 1, "M")
    c.rect(6, 2, 13, 3, "M")
    # Горловина.
    c.rect(7, 4, 12, 7, "p")
    # Плечи — эмаль сходит на конус.
    c.rect(6, 8, 13, 8, "p")
    c.rect(5, 9, 14, 9, "p")
    c.rect(4, 10, 15, 22, "p")
    c.hline(5, 14, 23, "p")
    c.cylinder(4, 15, 4, 23, "p")
    # Обод по низу и синяя полоска по плечу — у всех бидонов она была.
    c.hline(4, 15, 20, "u")
    c.cylinder(4, 15, 20, 20, "u")
    # Скол эмали — бидон видал виды.
    c.put(12, 15, "i")
    c.put(13, 15, "i")
    c.put(12, 16, "i")
    # Дужка.
    for x, y in ((4, 9), (3, 10), (2, 11), (2, 12), (15, 9), (16, 10), (17, 11), (17, 12)):
        c.put(x, y, "M")
    c.shade("M")
    c.outline()
    return c


def flyaga():
    # Сорокалитровая армейская фляга: широкая, крашеная, с зажимом крышки.
    c = Canvas(24, 30)
    c.rect(8, 1, 15, 2, "M")  # крышка
    c.rect(9, 0, 14, 0, "M")
    c.rect(18, 1, 19, 4, "M")  # зажим
    c.rect(15, 3, 18, 3, "M")
    c.rect(8, 3, 15, 6, "v")  # горло
    c.rect(7, 7, 16, 7, "v")
    c.rect(5, 8, 18, 8, "v")
    c.rect(4, 9, 19, 9, "v")
    c.rect(3, 10, 20, 26, "v")
    c.hline(4, 19, 27, "v")
    c.cylinder(3, 20, 3, 27, "v")
    # Рёбра жёсткости.
    for y in (14, 21):
        c.hline(3, 20, y, "V")
    # Трафаретная звезда.
    for x, y in ((11, 16), (10, 17), (11, 17), (12, 17), (11, 18), (9, 17), (13, 17), (10, 19), (12, 19)):
        c.put(x, y, "B")
    # Ручки по бокам.
    c.rect(1, 11, 2, 13, "M")
    c.rect(21, 11, 22, 13, "M")
    c.shade("M")
    c.outline()
    return c


def dedov():
    # Куб на огне, шлем, отвод в змеевик, приёмная банка.
    c = Canvas(34, 28)
    # Куб.
    c.rect(2, 12, 15, 25, "C")
    c.ellipse(8.5, 12, 6.5, 3.5, "C")
    c.hline(2, 15, 18, "c")  # клёпаный шов
    for x in range(3, 15, 3):
        c.put(x, 18, "D")
    c.cylinder(2, 15, 9, 25, "C")
    # Шлем и отвод.
    c.rect(8, 5, 9, 9, "C")
    c.ellipse(8.5, 5, 2.5, 2, "C")
    c.line(10, 4, 22, 4, "C")
    c.line(10, 5, 22, 5, "c")
    c.line(22, 4, 25, 8, "C")
    # Холодильник: ведро с витками.
    c.rect(20, 9, 30, 21, "M")
    c.cylinder(20, 30, 9, 21, "M")
    for y in (11, 14, 17):
        c.hline(21, 29, y, "C")
        c.put(21, y + 1, "c")
        c.put(29, y + 1, "c")
    # Выход и капля.
    c.rect(29, 21, 30, 22, "C")
    c.put(30, 23, "B")
    # Приёмная банка.
    c.rect(27, 24, 32, 27, "G")
    c.rect(28, 25, 31, 27, "b")
    c.cylinder(27, 32, 24, 27, "G")
    # Манометр на кубе.
    c.ellipse(12, 15, 1.5, 1.5, "q")
    c.put(12, 15, "k")
    c.shade("M")
    c.outline()
    return c


def zmeevik():
    # Медный змеевик в бочке с проточной водой. Витки видны в окне бочки.
    c = Canvas(28, 32)
    # Бочка-холодильник.
    c.rect(3, 4, 20, 27, "M")
    c.ellipse(11.5, 4, 8.5, 2, "M")
    c.cylinder(3, 20, 3, 27, "M")
    # Прорезь, в которой видно медь.
    c.rect(6, 7, 17, 24, "g")
    for i, y in enumerate(range(8, 24, 3)):
        c.hline(6, 17, y, "C")
        c.hline(6, 17, y + 1, "c")
        c.put(6 + (i % 2) * 11, y + 2, "C")
    c.replace_in(6, 7, 17, 24, "g", "i")
    # Обручи.
    for y in (5, 26):
        c.hline(3, 20, y, "m")
    # Шланг с водой сверху и выход снизу.
    c.line(20, 6, 24, 2, "i")
    c.line(21, 6, 25, 2, "i")
    c.rect(20, 23, 24, 24, "C")
    c.rect(23, 25, 24, 25, "C")
    c.put(24, 26, "B")
    c.rect(21, 27, 26, 31, "G")
    c.rect(22, 28, 25, 31, "b")
    c.cylinder(21, 26, 27, 31, "G")
    # Ножки.
    c.rect(4, 28, 5, 31, "i")
    c.rect(18, 28, 19, 31, "i")
    c.shade("i")
    c.outline()
    return c


def tseh():
    # Три колонны на общей раме, трубы между ними — уже производство.
    c = Canvas(38, 34)
    xs = (2, 14, 26)
    heights = (8, 3, 11)
    for x, top in zip(xs, heights):
        c.rect(x, top + 3, x + 8, 28, "C")
        c.ellipse(x + 4, top + 3, 4, 2, "C")
        c.cylinder(x, x + 8, top, 28, "C")
        # Царги колонны.
        for y in range(top + 7, 27, 5):
            c.hline(x, x + 8, y, "c")
        # Смотровое окошко с кипящим.
        c.rect(x + 3, 21, x + 5, 23, "b")
        c.put(x + 4, 22, "w")
    # Трубы поверху.
    c.hline(6, 30, 2, "M")
    c.vline(6, 2, 11, "M")
    c.vline(18, 2, 6, "M")
    c.vline(30, 2, 14, "M")
    # Рама.
    c.rect(0, 29, 36, 30, "i")
    c.rect(1, 31, 2, 33, "i")
    c.rect(34, 31, 35, 33, "i")
    c.rect(17, 31, 19, 33, "i")
    c.shade("M")
    c.shade("i")
    c.outline()
    return c


def podval():
    # Погреб Петровича: дубовые бочки штабелем, кран, лампочка.
    c = Canvas(34, 28)

    def barrel(cx, cy, rx, ry):
        c.ellipse(cx, cy, rx, ry, "e")
        c.rect(round(cx - rx + 1), round(cy - ry), round(cx + rx - 1), round(cy + ry), "e")
        c.cylinder(round(cx - rx), round(cx + rx), round(cy - ry), round(cy + ry), "e")
        for dx in (-rx + 2, rx - 2):
            c.vline(round(cx + dx), round(cy - ry + 1), round(cy + ry - 1), "M")
        c.vline(round(cx), round(cy - ry + 1), round(cy + ry - 1), "E")

    barrel(8, 21, 7, 6)
    barrel(24, 21, 7, 6)
    barrel(16, 9, 7, 6)
    # Краны.
    for x in (8, 24):
        c.rect(x - 1, 25, x, 26, "C")
        c.put(x, 27, "B")
    c.rect(15, 13, 16, 14, "C")
    c.shade("M")
    c.shade("C")
    c.outline()
    return c


def tsisterna():
    # Молоковоз «МОЛОКО»: кабина, цистерна, колёса.
    c = Canvas(44, 26)
    # Цистерна — длинный цилиндр по горизонтали.
    c.rect(13, 5, 41, 17, "p")
    c.ellipse(13, 11, 2, 6, "p")
    c.ellipse(41, 11, 2, 6, "p")
    # Горизонтальная растяжка: свет сверху, тень снизу.
    for x in range(11, 44):
        for y in range(5, 18):
            if c.get(x, y) == "p":
                if y <= 6:
                    c.put(x, y, "Q" if y == 6 else "q")
                elif y >= 15:
                    c.put(x, y, "P")
    # Синяя полоса с надписью: буквы угадываются, а не читаются — и так надо.
    c.hline(12, 42, 10, "u")
    c.hline(12, 42, 11, "u")
    c.hline(12, 42, 12, "u")
    for x in range(17, 38, 4):
        c.rect(x, 10, x + 2, 12, "q")
        c.put(x + 1, 11, "u")
    # Люк сверху.
    c.rect(26, 3, 30, 4, "M")
    # Кабина.
    c.rect(2, 7, 11, 18, "u")
    c.rect(4, 3, 11, 6, "u")
    c.rect(5, 4, 9, 7, "l")  # стекло
    c.put(5, 4, "L")
    c.rect(1, 14, 2, 15, "y")  # фара
    c.shade("u")
    # Рама.
    c.rect(1, 18, 42, 19, "i")
    # Колёса.
    for cx in (7, 30, 37):
        c.ellipse(cx, 21, 3.2, 3.2, "I")
        c.ellipse(cx, 21, 1.2, 1.2, "M")
    c.outline()
    return c


def druzhba():
    # Магистраль: толстые трубы, фланцы, задвижка с красным штурвалом.
    c = Canvas(40, 30)
    # Две трубы: дальняя и ближняя.
    c.rect(0, 8, 39, 13, "M")
    c.rect(0, 17, 39, 24, "M")
    for y0, y1 in ((8, 13), (17, 24)):
        for x in range(40):
            for y in range(y0, y1 + 1):
                t = (y - y0) / (y1 - y0)
                if t < 0.2:
                    c.put(x, y, "n" if t > 0 else "N")
                elif t > 0.75:
                    c.put(x, y, "m")
    # Фланцы с болтами.
    for x in (6, 33):
        c.rect(x, 15, x + 2, 26, "i")
        c.put(x + 1, 16, "J")
        c.put(x + 1, 25, "J")
    for x in (10, 29):
        c.rect(x, 6, x + 1, 15, "i")
    # Задвижка и штурвал.
    c.rect(18, 11, 21, 17, "i")
    c.vline(19, 3, 11, "M")
    c.vline(20, 3, 11, "m")
    c.ring(19.5, 3, 5, 1.6, "r", 1.2)
    c.hline(15, 24, 3, "r")
    # Манометр.
    c.vline(26, 13, 16, "M")
    c.ellipse(26, 11, 2.2, 2.2, "q")
    c.put(26, 11, "k")
    c.put(27, 10, "r")
    # Опоры.
    for x in (3, 36):
        c.rect(x, 25, x + 1, 29, "i")
    c.shade("r")
    c.outline()
    return c


def zavod():
    # «Кристалл-Витя»: кирпичный корпус, пилообразная крыша, труба с дымом.
    c = Canvas(40, 40)
    # Труба.
    c.rect(29, 2, 33, 30, "r")
    for y in (6, 7):
        c.hline(29, 33, y, "q")
    c.rect(28, 1, 34, 2, "r")
    # Корпус.
    c.rect(1, 20, 36, 38, "r")
    # Пилообразная крыша.
    for i in range(4):
        x0 = 1 + i * 7
        for k in range(6):
            c.hline(x0, x0 + k, 19 - k, "i")
        c.vline(x0 + 6, 13, 19, "Y")
    # Кирпичная кладка: швы через ряд.
    for y in range(22, 38, 2):
        for x in range(1 + (y // 2) % 2 * 2, 37, 4):
            c.put(x, y, "R")
    # Окна — горят, когда цех работает.
    for x in (4, 12, 20):
        c.rect(x, 24, x + 4, 30, "y")
        c.vline(x + 2, 24, 30, "i")
        c.hline(x, x + 4, 27, "i")
    # Ворота.
    c.rect(26, 29, 35, 38, "i")
    for y in range(30, 38, 2):
        c.hline(27, 34, y, "j")
    c.shade("r")
    c.outline()
    return c


def tanker():
    # Танкер «Первач»: красное днище, тёмный борт, белая надстройка.
    c = Canvas(52, 30)
    # Корпус с поднятым носом.
    for y in range(16, 27):
        inset = max(0, y - 22)
        c.hline(1 + inset, 47 - inset * 2, y, "i")
    c.rect(44, 13, 50, 20, "i")
    c.line(47, 20, 50, 13, "i")
    for x in range(1, 51):
        for y in range(22, 27):
            if c.get(x, y) == "i":
                c.put(x, y, "r")
    c.hline(1, 49, 16, "J")
    # Палуба: трубопроводы и танки.
    for x in range(14, 42, 7):
        c.rect(x, 13, x + 4, 15, "M")
    c.hline(12, 44, 12, "M")
    # Надстройка на корме.
    c.rect(3, 4, 12, 15, "p")
    c.rect(5, 1, 10, 3, "p")
    for x in range(4, 12, 2):
        c.put(x, 7, "y")
        c.put(x, 10, "y")
    c.rect(7, -1, 8, 0, "r")
    # Мачта на носу.
    c.vline(46, 5, 12, "M")
    c.put(46, 4, "y")
    c.shade("p")
    c.shade("r")
    c.outline()
    return c


def orbita():
    # «Мир-2»: базовый блок, солнечные панели, стыковочный узел.
    c = Canvas(48, 36)
    # Солнечные панели.
    for x0 in (1, 32):
        c.rect(x0, 8, x0 + 14, 26, "u")
        for x in range(x0, x0 + 15, 3):
            c.vline(x, 8, 26, "U")
        for y in range(8, 27, 4):
            c.hline(x0, x0 + 14, y, "U")
        c.put(x0 + 1, 9, "L")
    # Фермы к панелям.
    c.hline(15, 32, 17, "M")
    # Модуль.
    c.rect(18, 4, 29, 32, "p")
    c.cylinder(18, 29, 4, 32, "p")
    c.ellipse(23.5, 4, 5.5, 2, "p")
    c.ellipse(23.5, 32, 5.5, 2, "p")
    for y in (10, 20, 27):
        c.hline(18, 29, y, "P")
    # Золотая плёнка.
    c.rect(19, 12, 28, 18, "C")
    c.cylinder(19, 28, 12, 18, "C")
    # Иллюминаторы.
    for y in (7, 23):
        c.ellipse(23.5, y, 1.5, 1.2, "y")
    # Стыковочный узел.
    c.rect(22, 0, 25, 1, "M")
    c.shade("M")
    c.outline()
    return c


def collider():
    # Самогонный коллайдер: кольцо магнитов и янтарный пучок внутри.
    c = Canvas(48, 40)
    # Тело кольца.
    c.ellipse(23.5, 17, 21, 14, "i")
    c.ellipse(23.5, 17, 14, 8, T)
    # Пучок — светится.
    c.ring(23.5, 17, 17.5, 11, "y", 1.4)
    # Магниты — медные сегменты по кольцу.
    for k in range(12):
        a = 2 * math.pi * k / 12
        x = round(23.5 + 17.5 * math.cos(a))
        y = round(17 + 11 * math.sin(a))
        c.rect(x - 1, y - 1, x + 1, y + 1, "C")
    # Детектор сверху и приёмная цистерна снизу.
    c.rect(20, 0, 27, 4, "M")
    c.put(23, 1, "y")
    c.rect(17, 30, 30, 36, "M")
    c.cylinder(17, 30, 30, 36, "M")
    c.rect(19, 32, 28, 35, "b")
    c.rect(22, 27, 25, 30, "C")
    # Опоры.
    for x in (6, 40):
        c.rect(x, 26, x + 1, 38, "i")
    c.hline(4, 43, 38, "i")
    c.hline(4, 43, 39, "i")
    c.shade("i")
    c.shade("C")
    c.outline()
    return c


STILLS = [
    ("banka", banka),
    ("bidon", bidon),
    ("flyaga", flyaga),
    ("dedov", dedov),
    ("zmeevik", zmeevik),
    ("tseh", tseh),
    ("podval", podval),
    ("tsisterna", tsisterna),
    ("druzhba", druzhba),
    ("zavod", zavod),
    ("tanker", tanker),
    ("orbita", orbita),
    ("collider", collider),
]


def validate(rows, name):
    problems = []
    widths = {len(r) for r in rows}
    if len(widths) != 1:
        problems.append(f"{name}: строки разной длины {sorted(widths)}")
    unknown = {ch for r in rows for ch in r if ch != T and ch not in PALETTE}
    if unknown:
        problems.append(f"{name}: нет в палитре {''.join(sorted(unknown))}")
    if not rows[-1].strip(T):
        problems.append(f"{name}: пустая нижняя строка — аппарат повиснет над полкой")
    return problems


def build_all():
    out = []
    for name, fn in STILLS:
        rows = fn().trimmed()
        out.append((name, rows))
    return out


# --- PNG без сторонних библиотек ------------------------------------------


def write_png(path, pixels, w, h):
    raw = b"".join(b"\x00" + bytes(pixels[y * w * 4:(y + 1) * w * 4]) for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def preview(sprites, path, scale=5):
    pad = 6
    widths = [len(r[0]) for _, r in sprites]
    heights = [len(r) for _, r in sprites]
    per_row = 5
    lines = [sprites[i:i + per_row] for i in range(0, len(sprites), per_row)]
    W = max(sum(len(r[0]) + pad for _, r in line) for line in lines) * scale + pad * scale
    H = sum(max(len(r) for _, r in line) + pad for line in lines) * scale + pad * scale
    bg = (0x24, 0x1C, 0x15, 255)
    px = bytearray(bg * (W * H))
    oy = pad
    for line in lines:
        lh = max(len(r) for _, r in line)
        ox = pad
        for _, rows in line:
            top = oy + lh - len(rows)
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch == T:
                        continue
                    v = PALETTE[ch]
                    a = (v >> 24) & 0xFF if v > 0xFFFFFF else 255
                    rgb = ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
                    for sy in range(scale):
                        for sx in range(scale):
                            X = (ox + x) * scale + sx
                            Y = (top + y) * scale + sy
                            i = (Y * W + X) * 4
                            if a == 255:
                                px[i:i + 4] = bytes((*rgb, 255))
                            else:
                                for k in range(3):
                                    px[i + k] = (px[i + k] * (255 - a) + rgb[k] * a) // 255
            ox += len(rows[0]) + pad
        oy += lh + pad
    write_png(path, px, W, H)


DART_HEADER = """// СГЕНЕРИРОВАНО tools/sprite_lab.py — руками не править.
//
// Форма аппаратов задаётся там примитивами, светотень накладывается по единым
// правилам. Поправить спрайт: изменить функцию в sprite_lab.py и запустить
//   python tools/sprite_lab.py --dart
// ignore_for_file: prefer_single_quotes

part of 'still_sprites.dart';
"""


def to_dart(sprites):
    parts = [DART_HEADER]
    for name, rows in sprites:
        parts.append(f"\nconst _{name} = PixelSprite([")
        for r in rows:
            parts.append(f"  '{r}',")
        parts.append("]);")
    parts.append("\n/// Палитра, по которой собраны спрайты. Сверяется тестом с генератором.")
    parts.append("const Map<String, int> kStillPaletteArgb = {")
    for k, v in PALETTE.items():
        argb = v if v > 0xFFFFFF else 0xFF000000 | v
        parts.append(f"  '{k}': 0x{argb:08X},")
    parts.append("};")
    return "\n".join(parts) + "\n"


if __name__ == "__main__":
    sprites = build_all()
    problems = [p for name, rows in sprites for p in validate(rows, name)]
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if "--dart" in sys.argv:
        here = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(here, "..", "lib", "ui", "pixel", "still_sprites_gen.dart")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(to_dart(sprites))
        print("записан", os.path.normpath(path))
    if "--png" in sys.argv:
        out = sys.argv[sys.argv.index("--png") + 1]
        preview(sprites, out)
        print("превью", out)
    if len(sys.argv) == 1:
        for name, rows in sprites:
            print(f"--- {name} {len(rows[0])}x{len(rows)}")
            for r in rows:
                print(r)
