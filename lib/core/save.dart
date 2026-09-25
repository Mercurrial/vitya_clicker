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
///
/// Новый ФАКТ — не несовместимое изменение. Он ложится новым ключом (лучше
/// своим блоком, как `stats`), а сериализатор читает отсутствующий ключ как
/// значение по умолчанию. Версия и миграция нужны, только когда меняется
/// смысл того, что уже лежит у игроков: единицы, формула, переезд поля.
const int kSaveVersion = 1;

/// Куда физически кладём сейв.
abstract class SaveStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();

  /// Лежит ли рядом сейв тестовой сборки (до выпуска 1.0.0).
  ///
  /// Его не читают: он записан под старым ключом, и его версии 1–5 совпали
  /// бы по номеру с новыми, хотя значат другое. Спрашиваем только затем,
  /// чтобы честно сказать игроку, куда делся гараж, а не молча показать
  /// пустой.
  Future<bool> hasTestSave();
}

/// Хранилище в памяти — работает без плагинов (тесты, ранняя разработка).
/// В релизе подменяется на реализацию поверх `shared_preferences`.
class MemorySaveStorage implements SaveStorage {
  String? _data;
  final bool _testSave;

  MemorySaveStorage({bool testSave = false}) : _testSave = testSave;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async => _data = data;

  @override
  Future<void> clear() async => _data = null;

  @override
  Future<bool> hasTestSave() async => _testSave;
}

/// Миграция одной версии на следующую.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> json);

/// Итог загрузки: данные + что с ними случилось по дороге.
class LoadResult {
  final Map<String, dynamic>? data;
  final bool wasMigrated;
  final bool wasCorrupt;

  /// Своего сейва нет, но есть сейв тестовой сборки. Гараж начинается
  /// заново, и игроку надо сказать почему — это не порча и не потеря.
  final bool fromTestVersion;

  const LoadResult({
    this.data,
    this.wasMigrated = false,
    this.wasCorrupt = false,
    this.fromTestVersion = false,
  });

  bool get isEmpty => data == null;
}

class SaveCodec {
  const SaveCodec();

  /// Миграции по возрастанию: ключ — версия, ИЗ которой мигрируем.
  ///
  /// Пусто намеренно. До выпуска 1.0.0 цепочка доросла до v5, но все эти
  /// сейвы писали сборки для своих, и владелец решил начать выпуск с чистого
  /// листа (docs/DECISIONS.md, «Чистый старт»). Тестовые сейвы лежат под
  /// другим ключом хранилища и сюда не попадают вовсе, поэтому переводить
  /// их нечем и незачем. Первый шаг появится, когда у выпущенного формата
  /// поменяется смысл, — и с тех пор правила CLAUDE.md про миграции в силе.
  static final Map<int, Migration> _migrations = {};

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

  Future<LoadResult> load() async {
    final raw = await storage.read();
    if ((raw == null || raw.isEmpty) && await storage.hasTestSave()) {
      return const LoadResult(fromTestVersion: true);
    }
    return codec.decode(raw);
  }

  Future<void> save(Map<String, dynamic> state) async =>
      storage.write(codec.encode(state));

  Future<void> wipe() => storage.clear();
}
