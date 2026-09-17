/// Сохранения: версионированный JSON + цепочка миграций.
///
/// Версия пишется с первого дня намеренно: без неё любое будущее изменение
/// структуры ломает сейвы у всех, кто уже играет. Миграции применяются
/// последовательно (v1 → v2 → v3…), поэтому старый сейв доживает до текущей
/// версии за один проход.
///
/// Хранилище спрятано за [SaveStorage]: игровой код не знает, лежит сейв в
/// `shared_preferences`, в файле или в памяти. Это же развязывает нас с
/// плагинами (на Windows они требуют Developer Mode).
library;

import 'dart:convert';
import 'dart:math' as math;

/// Текущая версия формата сейва. Поднимать при КАЖДОМ несовместимом изменении,
/// добавляя миграцию в [SaveCodec._migrations].
const int kSaveVersion = 5;

/// Куда физически кладём сейв.
abstract class SaveStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// Хранилище в памяти — работает без плагинов (тесты, ранняя разработка).
/// В релизе подменяется на реализацию поверх `shared_preferences`.
class MemorySaveStorage implements SaveStorage {
  String? _data;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async => _data = data;

  @override
  Future<void> clear() async => _data = null;
}

/// Миграция одной версии на следующую.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> json);

/// Итог загрузки: данные + что с ними случилось по дороге.
class LoadResult {
  final Map<String, dynamic>? data;
  final bool wasMigrated;
  final bool wasCorrupt;

  const LoadResult({this.data, this.wasMigrated = false, this.wasCorrupt = false});

  bool get isEmpty => data == null;
}

class SaveCodec {
  const SaveCodec();

  /// Миграции по возрастанию: ключ — версия, ИЗ которой мигрируем.
  static final Map<int, Migration> _migrations = {
    // v1 считал объём в литрах; v2 перешла на миллилитры, чтобы начало игры
    // ощущалось как «капает по чуть-чуть». Переводим накопленное и историю.
    1: (json) {
      double scale(dynamic v) => v is num ? v.toDouble() * 1000 : 0.0;
      return {
        ...json,
        'ml': scale(json['litres']),
        'lifetime': scale(json['lifetime']),
      }..remove('litres');
    },

    // v2 покупала оборудование за сам самогон. В v3 появились рубли: то, что
    // было накоплено, честнее считать уже проданным по базовой цене, а бак
    // отдать игроку пустым.
    2: (json) {
      final ml = json['ml'];
      final money = ml is num ? ml.toDouble() * 0.1 : 0.0;
      return {...json, 'ml': 0.0, 'money': money};
    },

    // v3 считала мудрость как корень из нагнанного, и она убегала в сотни
    // тысяч — игра ломалась за полчаса. v4 считает логарифмом, поэтому
    // накопленное надо пересчитать: иначе старые сейвы остались бы с
    // множителем в шестизначные проценты.
    //
    // Формула продублирована намеренно: миграции обязаны быть неизменными во
    // времени, а PrestigeState.wisdomFor будет меняться дальше.
    3: (json) {
      final lifetime = json['lifetime'];
      final ml = lifetime is num ? lifetime.toDouble() : 0.0;
      final wisdom =
          ml <= 0 ? 0 : (math.log(1 + ml / 1e6) / math.ln2).floor();
      return {...json, 'wisdom': wisdom < 0 ? 0 : wisdom};
    },

    // v4 хранила мудрость числом — то есть ОЦЕНКУ, а не факт. Из-за этого
    // каждая правка формулы требовала новой миграции и действовала только на
    // тех, кто обновился.
    //
    // v5 хранит факт: сколько было нагнано на момент последнего похмелья.
    // Мудрость из него вычисляется при каждой загрузке, поэтому следующая
    // правка формулы применится у всех и сразу.
    //
    // Обратный перевод точен: wisdomFor(1e6·(2^w − 1)) == w. Множитель 1e6 —
    // это firstWisdomMl НА МОМЕНТ v4, и он тут зашит намеренно: миграция
    // обязана читать то, что реально лежит у игрока, а не то, чему равна
    // константа сегодня.
    4: (json) {
      final w = json['wisdom'];
      final wisdom = w is num ? w.toInt() : 0;
      final claimed = wisdom <= 0 ? 0.0 : 1e6 * (math.pow(2, wisdom) - 1);
      return {
        ...json,
        'claimedMl': claimed,
        'bonusWisdom': 0,
      }..remove('wisdom');
    },
  };

  /// Упаковка состояния в строку с проставленной версией.
  String encode(Map<String, dynamic> state) {
    return jsonEncode({...state, 'version': kSaveVersion});
  }

  /// Разбор строки с приведением к текущей версии.
  ///
  /// Битый сейв не роняет игру: возвращается пустой результат с флагом
  /// [LoadResult.wasCorrupt], игра стартует заново.
  LoadResult decode(String? raw) {
    if (raw == null || raw.isEmpty) return const LoadResult();

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const LoadResult(wasCorrupt: true);
      }
      json = decoded;
    } catch (_) {
      return const LoadResult(wasCorrupt: true);
    }

    var version = json['version'];
    if (version is! int || version < 1) return const LoadResult(wasCorrupt: true);

    // Сейв из будущей версии (откат приложения) — безопаснее не трогать.
    if (version > kSaveVersion) return const LoadResult(wasCorrupt: true);

    final migrated = version < kSaveVersion;
    while (version < kSaveVersion) {
      final step = _migrations[version];
      if (step == null) return const LoadResult(wasCorrupt: true);
      json = step(json);
      version++;
      json['version'] = version;
    }

    return LoadResult(data: json, wasMigrated: migrated);
  }
}

/// Фасад над хранилищем и кодеком — с этим работает игра.
class SaveService {
  final SaveStorage storage;
  final SaveCodec codec;

  const SaveService({required this.storage, this.codec = const SaveCodec()});

  Future<LoadResult> load() async => codec.decode(await storage.read());

  Future<void> save(Map<String, dynamic> state) async =>
      storage.write(codec.encode(state));

  Future<void> wipe() => storage.clear();
}
