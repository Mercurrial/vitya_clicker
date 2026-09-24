#!/usr/bin/env python3
"""Значки целей: двадцать разных, а не девять на двадцать.

Прошлый набор раздавал один значок нескольким целям: «Первая капля» и «Рука
набита» были одним пальцем, «Целый литр», «Первая тысяча» и «Миллион» — одной
каплей. В сетке целей это превращалось в угадайку: отличить цель от цели можно
было только по подписи.

Значки собираются теми же примитивами и той же палитрой, что и аппараты
(`sprite_lab.py`), на сетке 16×16 без обрезки — чтобы в ячейках все стояли
одинаково.

    python tools/goal_icons_lab.py          — проверить
    python tools/goal_icons_lab.py --dart   — переписать lib/ui/pixel/goal_icons_gen.dart
    python tools/goal_icons_lab.py --png f  — превью
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_lab import PALETTE, T, Canvas, preview  # noqa: E402

S = 16


def canvas():
    return Canvas(S, S)


def fire_log():
    # Первая капля: полено и огонёк — «подкинуть дров».
    c = canvas()
    c.rect(2, 12, 13, 14, "e")
    c.hline(2, 13, 12, "o")
    c.put(3, 13, "E")
    c.put(12, 13, "E")
    for x, top in ((5, 7), (6, 5), (7, 4), (8, 5), (9, 6), (10, 8)):
        c.vline(x, top, 11, "2")
    for x, top in ((6, 8), (7, 7), (8, 8)):
        c.vline(x, top, 11, "3")
    c.put(7, 10, "4")
    c.outline()
    return c


def jar_first():
    # Начало дела: одна банка.
    c = canvas()
    c.rect(5, 1, 10, 2, "M")
    c.rect(5, 3, 10, 4, "G")
    c.rect(4, 5, 11, 14, "G")
    c.rect(5, 8, 10, 14, "b")
    c.hline(5, 10, 8, "B")
    c.cylinder(4, 11, 5, 14, "G")
    c.put(7, 11, "w")
    c.shade("M")
    c.outline()
    return c


def coin():
    # Первый рубль: монета.
    c = canvas()
    c.ellipse(7.5, 7.5, 6, 6, "C")
    c.ring(7.5, 7.5, 4.6, 4.6, "c", 0.8)
    # Буква «Р» с перекладиной — знак рубля.
    c.vline(6, 4, 11, "D")
    c.hline(6, 9, 4, "D")
    c.hline(6, 9, 7, "D")
    c.vline(9, 5, 6, "D")
    c.hline(5, 8, 9, "D")
    c.shade("C")
    c.outline()
    return c


def bottle():
    # Целый литр: бутылка с этикеткой.
    c = canvas()
    c.rect(7, 0, 8, 1, "r")
    c.rect(7, 2, 8, 4, "G")
    c.rect(6, 5, 9, 5, "G")
    c.rect(5, 6, 10, 15, "G")
    c.rect(6, 8, 9, 15, "b")
    c.rect(5, 10, 10, 12, "p")
    c.hline(6, 9, 11, "r")
    c.cylinder(5, 10, 6, 15, "G")
    c.outline()
    return c


def ten_jars():
    # Десяток: ящик с бутылками.
    c = canvas()
    for i, x in enumerate(range(2, 14, 3)):
        c.rect(x, 3, x + 1, 9, "G")
        c.rect(x, 1, x + 1, 2, "M" if i % 2 else "r")
    c.rect(1, 8, 14, 15, "e")
    c.hline(1, 14, 8, "o")
    c.hline(1, 14, 11, "E")
    c.vline(1, 8, 15, "E")
    c.vline(14, 8, 15, "E")
    c.outline()
    return c


def assortment():
    # Ассортимент: банка, бидон и фляга рядом.
    c = canvas()
    c.rect(1, 7, 4, 14, "G")
    c.rect(2, 10, 3, 14, "b")
    c.rect(1, 6, 4, 6, "M")
    c.rect(6, 5, 9, 14, "p")
    c.rect(7, 3, 8, 4, "p")
    c.hline(6, 9, 12, "u")
    c.rect(11, 6, 14, 14, "v")
    c.rect(12, 4, 13, 5, "M")
    c.outline()
    return c


def full_tank():
    # Под завязку: бочка, из которой переливается.
    c = canvas()
    c.rect(3, 4, 12, 15, "M")
    c.cylinder(3, 12, 4, 15, "M")
    for y in (6, 13):
        c.hline(3, 12, y, "m")
    c.rect(4, 2, 11, 3, "b")
    c.hline(5, 10, 1, "B")
    c.vline(12, 3, 6, "b")
    c.vline(13, 5, 8, "b")
    c.put(13, 10, "b")
    c.outline()
    return c


def banknotes():
    # Первая тысяча: пачка купюр с резинкой.
    c = canvas()
    for i in range(3):
        c.rect(1 + i, 9 - i * 2, 12 + i, 13 - i * 2, "z")
        c.hline(1 + i, 12 + i, 9 - i * 2, "Z")
    c.ellipse(9, 7, 1.6, 1.6, "V")
    c.vline(6, 4, 9, "r")
    c.outline()
    return c


def filter_seal():
    # Не бодяжим: печать качества.
    c = canvas()
    c.ellipse(7.5, 6.5, 5.5, 5.5, "C")
    c.ring(7.5, 6.5, 3.8, 3.8, "D", 0.9)
    c.put(6, 6, "D")
    c.put(7, 7, "D")
    c.put(8, 6, "D")
    c.put(9, 5, "D")
    c.rect(4, 11, 6, 15, "r")
    c.rect(9, 11, 11, 15, "r")
    c.put(5, 15, T)
    c.put(10, 15, T)
    c.shade("C")
    c.outline()
    return c


def canister():
    # Тара нашлась: канистра.
    c = canvas()
    c.rect(2, 4, 13, 15, "r")
    c.rect(4, 1, 8, 3, "R")
    c.rect(5, 2, 7, 2, T)
    c.rect(10, 2, 12, 3, "M")
    c.line(3, 6, 12, 14, "R")
    c.line(12, 6, 3, 14, "R")
    c.cylinder(2, 13, 4, 15, "r")
    c.outline()
    return c


def hand():
    # Рука набита: кулак с мозолью.
    c = canvas()
    c.rect(3, 5, 12, 12, "O")
    for x in (3, 6, 9):
        c.rect(x, 3, x + 2, 5, "O")
        c.vline(x + 2, 3, 7, "e")
    c.rect(1, 7, 3, 11, "O")
    c.rect(5, 13, 10, 15, "p")
    c.put(7, 4, "r")
    c.shade("e")
    c.outline()
    return c


def dedov_mini():
    # Дедово наследство: куб с отводом.
    c = canvas()
    c.rect(2, 7, 9, 14, "C")
    c.ellipse(5.5, 7, 3.5, 2, "C")
    c.rect(5, 3, 6, 5, "C")
    c.hline(6, 12, 3, "C")
    c.vline(12, 3, 10, "C")
    c.rect(11, 11, 14, 14, "G")
    c.rect(12, 12, 13, 14, "b")
    c.hline(2, 9, 10, "c")
    c.cylinder(2, 9, 6, 14, "C")
    c.outline()
    return c


def pallet():
    # Сотня: штабель ящиков.
    c = canvas()
    for (x, y) in ((1, 10), (6, 10), (11, 10), (3, 5), (8, 5), (5, 0)):
        c.rect(x, y, x + 4, y + 4, "e")
        c.hline(x, x + 4, y, "o")
        c.vline(x + 4, y, y + 4, "E")
        c.put(x + 2, y + 2, "E")
    c.hline(0, 15, 15, "i")
    c.outline()
    return c


def money_bag():
    # Миллион: мешок с деньгами.
    c = canvas()
    c.ellipse(7.5, 10, 6, 5, "b")
    c.rect(6, 3, 9, 5, "b")
    c.hline(5, 10, 5, "E")
    c.rect(5, 1, 10, 2, "b")
    # Знак рубля.
    c.vline(6, 7, 13, "E")
    c.hline(6, 9, 7, "E")
    c.hline(6, 9, 10, "E")
    c.vline(9, 8, 9, "E")
    c.hline(5, 8, 12, "E")
    c.shade("b")
    c.outline()
    return c


def brigade():
    # Бригада: три каски пирамидой.
    c = canvas()

    def hat(x, y, col):
        dark = "R" if col == "r" else "x"
        c.hline(x + 2, x + 4, y, col)
        for yy in (y + 1, y + 2, y + 3):
            c.hline(x + 1, x + 5, yy, col)
        c.hline(x, x + 6, y + 4, col)
        c.vline(x + 3, y, y + 3, dark)
        c.put(x + 2, y + 1, "Y")

    hat(0, 10, "y")
    hat(8, 10, "y")
    hat(4, 3, "r")
    c.outline()
    return c


def diploma():
    # Всё по науке: книга с закладкой.
    c = canvas()
    c.rect(2, 2, 13, 14, "u")
    c.rect(3, 3, 12, 13, "q")
    c.vline(7, 3, 13, "P")
    for y in (5, 7, 9, 11):
        c.hline(4, 6, y, "P")
        c.hline(9, 11, y, "P")
    c.rect(10, 0, 11, 5, "r")
    c.outline()
    return c


def bed():
    # Утро добрым не бывает: кровать и «Z».
    c = canvas()
    c.rect(1, 10, 14, 13, "e")
    c.rect(1, 14, 2, 15, "E")
    c.rect(13, 14, 14, 15, "E")
    c.rect(1, 6, 2, 13, "E")
    c.rect(3, 7, 5, 9, "q")
    c.rect(5, 8, 13, 10, "u")
    c.hline(5, 13, 8, "l")
    for x, y in ((9, 0), (10, 0), (11, 0), (12, 0), (11, 1), (10, 2), (9, 3), (10, 3), (11, 3), (12, 3)):
        c.put(x, y, "N")
    c.outline()
    return c


def owl():
    # Мудрость приходит: сова.
    c = canvas()
    c.ellipse(7.5, 9, 5.5, 6, "e")
    c.put(3, 2, "e")
    c.put(12, 2, "e")
    c.rect(3, 3, 12, 4, "e")
    for cx in (5, 10):
        c.ellipse(cx, 7, 2, 2, "q")
        c.put(cx, 7, "k")
    c.put(7, 9, "y")
    c.put(8, 9, "y")
    c.rect(5, 12, 10, 14, "o")
    c.shade("e")
    c.outline()
    return c


def alarm():
    # И снова здравствуйте: будильник.
    c = canvas()
    c.ellipse(7.5, 8.5, 6, 6, "r")
    c.ellipse(7.5, 8.5, 4.4, 4.4, "q")
    c.vline(7, 5, 9, "k")
    c.hline(8, 10, 9, "k")
    c.ellipse(3, 2.5, 2, 1.6, "M")
    c.ellipse(12, 2.5, 2, 1.6, "M")
    c.put(3, 15, "r")
    c.put(12, 15, "r")
    c.outline()
    return c


def lake():
    # Своё озеро: самогон до горизонта, камыш и солнце.
    c = canvas()
    c.rect(0, 8, 15, 14, "b")
    c.hline(1, 14, 15, "b")
    c.hline(0, 15, 8, "B")
    for y, xs in ((10, (2, 3, 4, 10, 11)), (12, (6, 7, 8, 13, 14)), (14, (3, 4, 10, 11))):
        for x in xs:
            c.put(x, y, "B")
    c.ellipse(11, 4, 2.2, 2.2, "3")
    for x, top in ((1, 3), (2, 5), (3, 4)):
        c.vline(x, top, 8, "v")
        c.put(x, top, "e")
    c.outline()
    return c


GOALS = [
    ("a_first_tap", fire_log),
    ("a_first_still", jar_first),
    ("a_first_sale", coin),
    ("a_litre", bottle),
    ("a_ten", ten_jars),
    ("a_assortment", assortment),
    ("a_full_tank", full_tank),
    ("a_thousand", banknotes),
    ("a_quality", filter_seal),
    ("a_tank_up", canister),
    ("a_hands", hand),
    ("a_dedov", dedov_mini),
    ("a_hundred", pallet),
    ("a_million", money_bag),
    ("a_brigade", brigade),
    ("a_synergy", diploma),
    ("a_first_hangover", bed),
    ("a_wise", owl),
    ("a_again", alarm),
    ("a_legacy", lake),
]


def rows_of(c):
    return ["".join(r) for r in c.g]


HEADER = """// СГЕНЕРИРОВАНО tools/goal_icons_lab.py — руками не править.
//
// Поправить значок: изменить функцию в goal_icons_lab.py и запустить
//   python tools/goal_icons_lab.py --dart

part of 'goal_icons.dart';

/// Значки целей по идентификатору достижения, 16×16, палитра аппаратов.
const Map<String, PixelSprite> _kGoalIcons = {"""


def to_dart():
    out = [HEADER]
    for gid, fn in GOALS:
        out.append(f"  '{gid}': PixelSprite([")
        for r in rows_of(fn()):
            out.append(f"    '{r}',")
        out.append("  ]),")
    out.append("};")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    problems = []
    for gid, fn in GOALS:
        rows = rows_of(fn())
        unknown = {ch for r in rows for ch in r if ch != T and ch not in PALETTE}
        if unknown:
            problems.append(f"{gid}: нет в палитре {''.join(sorted(unknown))}")
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if "--dart" in sys.argv:
        here = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(here, "..", "lib", "ui", "pixel", "goal_icons_gen.dart")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(to_dart())
        print("записан", os.path.normpath(path))
    if "--png" in sys.argv:
        out = sys.argv[sys.argv.index("--png") + 1]
        preview([(g, rows_of(fn())) for g, fn in GOALS], out, scale=6)
        print("превью", out)
