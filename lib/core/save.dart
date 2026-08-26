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

/// Текущая версия формата сейва. Поднимать при КАЖДОМ несовместимом изменении,
/// добавляя миграцию в [SaveCodec._migrations].
const int kSaveVersion = 2;

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
