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

/// Огонь под аппаратом.
///
/// Жар — центральная механика игры, но до сих пор он жил только в шкале:
/// полоска ползала, а гараж выглядел одинаково и при тлеющих углях, и при
/// перегреве. Огонь переносит механику в сцену — становится видно, что
/// нажатия делают, не отрывая глаз от Вити.
///
/// Три состояния вместо плавной шкалы намеренно: пиксель-арт плохо переносит
/// полутона, а игроку и нужно различать ровно три вещи — «мало», «в самый
/// раз», «перегрел».
const List<PixelSprite> kEmberFrames = [
  PixelSprite([
    '............',
    '............',
    '..f......f..',
    '.ff.f..ff.f.',
  ]),
  PixelSprite([
    '............',
    '............',
    '.f...f....f.',
    '.ff.ff..f.ff',
  ]),
];

/// Ровное пламя — жар в рабочем окне.
const List<PixelSprite> kFlameFrames = [
  PixelSprite([
    '....f..f....',
    '...fFf.fFf..',
    '..fFFFFFFF..',
    '.ffffffffff.',
  ]),
  PixelSprite([
    '...f..f.f...',
    '..fFf.fFFf..',
    '..fFFFFFFf..',
    '.ffffffffff.',
  ]),
  PixelSprite([
    '.....ff.f...',
    '..fFFf.fFf..',
    '.fFFFFFFFF..',
    '.ffffffffff.',
  ]),
];

/// Ревущее пламя — перегрев. Выше, шире и с белым нутром.
const List<PixelSprite> kBlazeFrames = [
  PixelSprite([
    '..f.fFf.f...',
    '.fFfFwFfFf..',
    'fFFFFwwFFFFf',
    'fFFFFFFFFFFf',
    'ffffffffffff',
  ]),
  PixelSprite([
    '...fFf.f.f..',
    '..fFwFfFFf..',
    'fFFFwwFFFFFf',
    'fFFFFFFFFFFf',
    'ffffffffffff',
  ]),
  PixelSprite([
    '.f.f.fFf.f..',
    '.fFfFwwFfF..',
    'fFFFwwFFFFFf',
    'fFFFFFFFFFFf',
    'ffffffffffff',
  ]),
];

/// Какие кадры показывать при таком жаре.
///
/// Пороги совпадают с окном шкалы: то, что игрок видит под аппаратом, должно
/// означать ровно то же, что и полоска сверху.
List<PixelSprite> fireFramesFor({required bool inWindow, required bool overheated}) {
  if (overheated) return kBlazeFrames;
  if (inWindow) return kFlameFrames;
  return kEmberFrames;
}
