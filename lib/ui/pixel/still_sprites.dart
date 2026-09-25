import 'dart:ui' show Color;

import 'pixel_sprite.dart';

part 'still_sprites_gen.dart';

/// Аппараты Вити: у каждой ступени лестницы свой силуэт.
///
/// Сами спрайты собираются в `tools/sprite_lab.py` из примитивов и лежат в
/// `still_sprites_gen.dart`. Руками их не рисуем: тринадцать предметов с общей
/// светотенью вручную не выдержать — у прошлой версии семь старших ступеней
/// делили одну заглушку, а младшие висели над полкой на трёх пустых строках.
///
/// Масштаб у спрайтов общий: коллайдер действительно больше банки, и по
/// силуэтам на полу видно, как далеко Витя зашёл.

/// Палитра аппаратов.
final Map<String, Color> kStillPalette = {
  for (final e in kStillPaletteArgb.entries) e.key: Color(e.value),
};

/// Палитра со светом в окнах под текущий жар.
///
/// Окна завода, иллюминаторы станции, пучок коллайдера — у старших аппаратов
/// огня нет, и жар виден по ним: тлеет — свет тусклый, в окне — ровный,
/// перегрев — красноватый.
Map<String, Color> stillPaletteFor({required bool inWindow, required bool overheated}) {
  if (overheated) return _hotPalette;
  if (inWindow) return kStillPalette;
  return _dimPalette;
}

final Map<String, Color> _dimPalette = {
  ...kStillPalette,
  'y': const Color(0xFFB8864F),
  'Y': const Color(0xFFD9B27A),
};

final Map<String, Color> _hotPalette = {
  ...kStillPalette,
  'y': const Color(0xFFFF7A4A),
  'Y': const Color(0xFFFFC2A0),
};

/// Аппарат по идентификатору генератора.
PixelSprite stillSpriteFor(String id) => switch (id) {
      'banka' => _banka,
      'bidon' => _bidon,
      'flyaga' => _flyaga,
      'dedov' => _dedov,
      'zmeevik' => _zmeevik,
      'tseh' => _tseh,
      'podval' => _podval,
      'tsisterna' => _tsisterna,
      'druzhba' => _druzhba,
      'zavod' => _zavod,
      'tanker' => _tanker,
      'orbita' => _orbita,
      'collider' => _collider,
      _ => _banka,
    };

/// Стоит ли аппарат на огне. У остальных жар виден по свету в окнах и пару.
///
/// Огонь под танкером или орбитальной станцией читался бы как авария, а не
/// как работа.
bool stillHasFire(String id) => const {
      'banka',
      'bidon',
      'flyaga',
      'dedov',
      'tseh',
    }.contains(id);

/// Пар над аппаратом — четыре кадра клуба, который поднимается и тает.
///
/// Прошлый пар был тремя ромбиками по четыре точки, и над каждым аппаратом
/// висел серый крестик. Клуб читается паром, только когда у него есть форма:
/// плотное ядро внизу, рыхлый край, разрыв наверху.
const kSteamFrames = [
  PixelSprite([
    '............',
    '............',
    '............',
    '.....SS.....',
    '....SSSS....',
    '.....SS.....',
  ]),
  PixelSprite([
    '............',
    '............',
    '.....SS.....',
    '....SSSS....',
    '...SSS.SS...',
    '.....S......',
  ]),
  PixelSprite([
    '............',
    '....SS.S....',
    '...SSSSSS...',
    '..SS.SS.S...',
    '.....S......',
    '............',
  ]),
  PixelSprite([
    '...S....S...',
    '..SS.SS.SS..',
    '...S.SS.S...',
    '.....S......',
    '............',
    '............',
  ]),
];

/// Густой пар при перегреве — валит клубами.
const kHeavySteamFrames = [
  PixelSprite([
    '............',
    '....SSSS....',
    '...SSSSSS...',
    '..SSSSSSSS..',
    '...SSSSSS...',
    '....SSSS....',
  ]),
  PixelSprite([
    '...SS..SS...',
    '..SSSSSSSS..',
    '.SSSSSSSSSS.',
    '..SSSSSSSS..',
    '...SSSSSS...',
    '.....SS.....',
  ]),
  PixelSprite([
    '.SS......SS.',
    'SSSS.SS.SSSS',
    '.SSSSSSSSSS.',
    '..SSSSSSSS..',
    '....SSSS....',
    '............',
  ]),
];

/// Огонь под аппаратом.
///
/// Жар — центральная механика игры, и огонь переносит её в сцену: видно, что
/// палец что-то делает, не отрывая глаз от гаража.
///
/// Три состояния вместо плавной шкалы намеренно: пиксель-арт плохо переносит
/// полутона, а игроку и нужно различать ровно три вещи — «мало», «в самый
/// раз», «перегрел».
const List<PixelSprite> kEmberFrames = [
  PixelSprite([
    '............',
    '............',
    '..1..2...1..',
    '.1212.12121.',
  ]),
  PixelSprite([
    '............',
    '............',
    '.2...1..2...',
    '.12121.1212.',
  ]),
];

/// Ровное пламя — жар в рабочем окне.
const List<PixelSprite> kFlameFrames = [
  PixelSprite([
    '....2..2....',
    '...232.232..',
    '..23333332..',
    '.1222222221.',
  ]),
  PixelSprite([
    '...2..2.2...',
    '..232.2332..',
    '..23333332..',
    '.1222222221.',
  ]),
  PixelSprite([
    '.....22.2...',
    '..2332.232..',
    '.233333332..',
    '.1222222221.',
  ]),
];

/// Ревущее пламя — перегрев. Выше, шире и с белым нутром.
const List<PixelSprite> kBlazeFrames = [
  PixelSprite([
    '..2.232.2...',
    '.2323432322.',
    '233334433332',
    '233333333332',
    '122222222221',
  ]),
  PixelSprite([
    '...232.2.2..',
    '..2342332...',
    '233344333332',
    '233333333332',
    '122222222221',
  ]),
  PixelSprite([
    '.2.2.232.2..',
    '.232443232..',
    '233344333332',
    '233333333332',
    '122222222221',
  ]),
];

/// Какие кадры показывать при таком жаре.
///
/// Пороги совпадают с окном шкалы: то, что игрок видит под аппаратом, должно
/// означать ровно то же, что и полоска внизу.
List<PixelSprite> fireFramesFor({required bool inWindow, required bool overheated}) {
  if (overheated) return kBlazeFrames;
  if (inWindow) return kFlameFrames;
  return kEmberFrames;
}
