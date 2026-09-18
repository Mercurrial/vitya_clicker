/// Пиксельные значки целей.
///
/// Раньше в ячейке достижения стоял текст в девять пунктов и подсказка в
/// четыре строки — читать это было невозможно, а отличить одну цель от другой
/// с первого взгляда тем более. Значок решает и то и другое: он опознаётся
/// мгновенно, а название остаётся во всплывающей подсказке.
///
/// Рисуются тем же способом, что и весь остальной арт игры, — сеткой символов
/// прямо в исходнике. Двенадцать на двенадцать: меньше не читается, больше не
/// влезает в ячейку.
library;

import 'pixel_sprite.dart';

/// Палец — всё, что про касание.
const _finger = PixelSprite([
  '............',
  '.....kk.....',
  '....kMMk....',
  '....kMMk....',
  '..kkkMMk....',
  '.kMMkMMkkk..',
  '.kMMMMMMMk..',
  '.kMMMMMMMk..',
  '..kMMMMMk...',
  '..kMMMMMk...',
  '...kkkkk....',
  '............',
]);

/// Банка — первый аппарат и всё, что про количество аппаратов.
const _jar = PixelSprite([
  '............',
  '...cccccc...',
  '...cCCCCc...',
  '...kkkkkk...',
  '..kggggggk..',
  '.kgggggggk..',
  '.kgbbbbbgk..',
  '.kgbbbbbgk..',
  '.kgbbbbbgk..',
  '.kgbbbbbgk..',
  '.kkkkkkkkk..',
  '............',
]);

/// Рубль — всё про деньги и продажу.
const _money = PixelSprite([
  '............',
  '..aaaaaaaa..',
  '.akkkkkkkka.',
  '.ak..aaa..ka',
  '.ak.a...a.ka',
  '.ak.aaaa..ka',
  '.ak.a.....ka',
  '.ak.aaa...ka',
  '.ak.a.....ka',
  '.akkkkkkkka.',
  '..aaaaaaaa..',
  '............',
]);

/// Капля — объёмы.
const _drop = PixelSprite([
  '.....kk.....',
  '.....BB.....',
  '....kBBk....',
  '....BBBB....',
  '...kBBBBk...',
  '..kBBBBBBk..',
  '..kBwBBBBk..',
  '.kBBwBBBBBk.',
  '.kBBBBBBBBk.',
  '..kBBBBBBk..',
  '...kkkkkk...',
  '............',
]);

/// Бак — ёмкость.
const _tank = PixelSprite([
  '............',
  '..kkkkkkkk..',
  '.kmmmmmmmmk.',
  '.km......mk.',
  '.km......mk.',
  '.kmbbbbbbmk.',
  '.kmbbbbbbmk.',
  '.kmbbbbbbmk.',
  '.kmbbbbbbmk.',
  '.kmmmmmmmmk.',
  '..kk....kk..',
  '............',
]);

/// Пламя — жар и серия.
const _flame = PixelSprite([
  '............',
  '.....f......',
  '....ff.f....',
  '...fFff.f...',
  '..fFFFffff..',
  '..fFwFFFff..',
  '.fFFwwFFFFf.',
  '.fFFwwFFFFf.',
  '.fFFFFFFFFf.',
  '..fFFFFFFf..',
  '...ffffff...',
  '............',
]);

/// Кровать — похмелье.
const _bed = PixelSprite([
  '............',
  '............',
  '..kk........',
  '..kk.wwwww..',
  '..kkkwwwwwk.',
  '..kmmmmmmmk.',
  '..kmrrrrrmk.',
  '..kmrrrrrmk.',
  '..kkkkkkkkk.',
  '..k.......k.',
  '..k.......k.',
  '............',
]);

/// Медаль — итоговые, «за всё время».
const _medal = PixelSprite([
  '...k....k...',
  '...kk..kk...',
  '....k..k....',
  '....kkkk....',
  '..kkaaaakk..',
  '.kaaaaaaaak.',
  '.kaawaaaaak.',
  '.kaaaaaaaak.',
  '.kaaaaaaaak.',
  '..kaaaaaak..',
  '...kkkkkk...',
  '............',
]);

/// Звезда — синергии и редкое.
const _star = PixelSprite([
  '............',
  '.....aa.....',
  '....aaaa....',
  '....aaaa....',
  '.aaaaaaaaaa.',
  '..aaawwaaa..',
  '...aawwaa...',
  '...aaaaaa...',
  '..aaa..aaa..',
  '..aa....aa..',
  '.aa......aa.',
  '............',
]);

/// Значок для цели по её идентификатору.
///
/// Сопоставление руками, а не по категориям: у достижений разный смысл, и
/// «первая продажа» просится в рубль, даже если лежит в ряду про начало.
PixelSprite goalIcon(String id) => switch (id) {
      'a_first_tap' || 'a_hands' => _finger,
      'a_first_still' || 'a_ten' || 'a_hundred' || 'a_brigade' => _jar,
      'a_first_sale' || 'a_quality' => _money,
      'a_litre' || 'a_thousand' || 'a_million' => _drop,
      'a_full_tank' || 'a_tank_up' => _tank,
      'a_dedov' || 'a_assortment' => _flame,
      'a_first_hangover' || 'a_again' => _bed,
      'a_wise' || 'a_legacy' => _medal,
      _ => _star,
    };
