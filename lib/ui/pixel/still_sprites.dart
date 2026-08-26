import 'pixel_sprite.dart';

/// Спрайты аппаратов Вити, 16×16.
///
/// Размер выбран намеренно мелким: на такой сетке силуэт важнее деталей,
/// поэтому каждый аппарат узнаётся с одного взгляда даже на телефоне.
/// Ключи символов — см. [kGaragePalette].

/// Трёхлитровая банка: стекло, крышка, брага.
const _banka = PixelSprite([
  '................',
  '.....MMMMM......',
  '....kkkkkkk.....',
  '....kGwwwGk.....',
  '....kG...Gk.....',
  '....kG...Gk.....',
  '....kGbbbGk.....',
  '....kGbbbGk.....',
  '....kGBBBGk.....',
  '....kGBBBGk.....',
  '....kGBBBGk.....',
  '....kGBBBGk.....',
  '....kkkkkkk.....',
  '................',
  '................',
  '................',
]);

/// Бидон эмалированный: ручка, гладкий бок.
const _bidon = PixelSprite([
  '................',
  '......mmm.......',
  '.....kMMMk......',
  '....kkkkkkk.....',
  '....kMMMMMk.....',
  '...kkMMMMMkk....',
  '...kmMMMMMmk....',
  '...kmMbbbMmk....',
  '...kmMbbbMmk....',
  '...kmMBBBMmk....',
  '...kmMBBBMmk....',
  '...kmMBBBMmk....',
  '...kkkkkkkkk....',
  '................',
  '................',
  '................',
]);

/// Фляга армейская: плоская, с узким горлом.
const _flyaga = PixelSprite([
  '................',
  '.......kk.......',
  '......kmmk......',
  '.....kkkkkk.....',
  '....kmMMMMmk....',
  '...kmMMMMMMmk...',
  '...kmMbbbbMmk...',
  '...kmMbbbbMmk...',
  '...kmMBBBBMmk...',
  '...kmMBBBBMmk...',
  '...kmMBBBBMmk...',
  '...kmMMMMMMmk...',
  '....kkkkkkkk....',
  '................',
  '................',
  '................',
]);

/// Аппарат «Дедов»: куб, отвод, приёмная банка и огонь снизу.
const _dedov = PixelSprite([
  '................',
  '....CC..........',
  '...C..C.........',
  '...C...CCCC.....',
  '...C.......C....',
  '..kkkkkk...C....',
  '..kCCCCCk..C....',
  '..kCaaaCk..C....',
  '..kCaaaCk.kkk...',
  '..kCBBBCk.kBk...',
  '..kCBBBCk.kBk...',
  '..kkkkkkk.kkk...',
  '...fFfFf........',
  '................',
  '................',
  '................',
]);

/// Медный змеевик: витки холодильника и капля на выходе.
const _zmeevik = PixelSprite([
  '................',
  '...CCCCCCCC.....',
  '..C........C....',
  '..C.CCCCCC.C....',
  '..C.C....C.C....',
  '..C.C.CC.C.C....',
  '..C.C.CC.C.C....',
  '..C.C....C.C....',
  '..C.CCCCCC.C....',
  '..C........C....',
  '...CCCCCCCC.....',
  '......C.........',
  '......C.........',
  '.....BBB........',
  '................',
  '................',
]);

/// Гаражный цех: три куба в ряд, уже производство.
const _tseh = PixelSprite([
  '................',
  '.kk....kk...kk..',
  '.kCk...kCk..kCk.',
  '.kCk...kCk..kCk.',
  'kkkkk.kkkkkkkkkk',
  'kCCCk.kCCCkkCCCk',
  'kCaCk.kCaCkkCaCk',
  'kCaCk.kCaCkkCaCk',
  'kCBCk.kCBCkkCBCk',
  'kkkkk.kkkkkkkkkk',
  '.fFf...fFf..fFf.',
  '................',
  '................',
  '................',
  '................',
  '................',
]);

/// Промышленный силуэт — для старших тиров, пока у них нет своего спрайта.
const _industrial = PixelSprite([
  '................',
  '..k..........k..',
  '..kk........kk..',
  '..kMk......kMk..',
  '.kkkkkkkkkkkkkk.',
  '.kMMMMMMMMMMMMk.',
  '.kMrMMrMMrMMrMk.',
  '.kMMMMMMMMMMMMk.',
  '.kMaaMMaaMMaaMk.',
  '.kMaaMMaaMMaaMk.',
  '.kMMMMMMMMMMMMk.',
  '.kBBMMBBMMBBMMk.',
  '.kkkkkkkkkkkkkk.',
  '..kk..kk..kk....',
  '................',
  '................',
]);

/// Пар над аппаратом — три кадра, чтобы клубился.
const kSteamFrames = [
  PixelSprite([
    '................',
    '................',
    '.......ss.......',
    '......ssss......',
    '.......ss.......',
    '................',
  ]),
  PixelSprite([
    '................',
    '......ss........',
    '.....ssss.......',
    '......ss..ss....',
    '................',
    '................',
  ]),
  PixelSprite([
    '.....ss.........',
    '....ssss...ss...',
    '.....ss....ss...',
    '................',
    '................',
    '................',
  ]),
];

/// Аппарат по идентификатору генератора.
///
/// Старшие тиры пока делят промышленный силуэт — лучше узнаваемая заглушка,
/// чем пустое место.
PixelSprite stillSpriteFor(String id) {
  switch (id) {
    case 'banka':
      return _banka;
    case 'bidon':
      return _bidon;
    case 'flyaga':
      return _flyaga;
    case 'dedov':
      return _dedov;
    case 'zmeevik':
      return _zmeevik;
    case 'tseh':
      return _tseh;
    default:
      return _industrial;
  }
}

/// Есть ли у аппарата открытый огонь — им управляем подсветкой от жара.
bool stillHasFire(String id) => id == 'dedov' || id == 'tseh';
