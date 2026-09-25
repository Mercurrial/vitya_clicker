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

  /// Отложенные копии нечитаемых сейвов — отдельно от основного ключа.
  ///
  /// Хранилище их не разбирает: что внутри, решает [SaveService]. Отдельный
  /// ключ нужен потому, что основной перезапишет первый же автосейв нового
  /// гаража, а до этой задачи копии не было вовсе — гараж пропадал молча.
  Future<String?> readRescue();
  Future<void> writeRescue(String data);
  Future<void> clearRescue();
}

/// Хранилище в памяти — работает без плагинов (тесты, ранняя разработка).
/// В релизе подменяется на реализацию поверх `shared_preferences`.
class MemorySaveStorage implements SaveStorage {
  String? _data;
  String? _rescue;
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

  @override
  Future<String?> readRescue() async => _rescue;

  @override
  Future<void> writeRescue(String data) async => _rescue = data;

  @override
  Future<void> clearRescue() async => _rescue = null;
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

  /// Сейв записан более новой версией игры. Он не испорчен — эта версия его
  /// просто не понимает, и начинать поверх него новый гараж нельзя.
  ///
  /// Раньше это был [wasCorrupt], и игра стирала сейв: на iPhone игра с
  /// экрана «Домой» открывается закэшированной старой сборкой, и первый же
  /// её автосейв затирал прогресс, записанный новой.
  final bool fromFuture;

  /// Строка как она лежала в хранилище. Нужна, чтобы отложить нечитаемый
  /// сейв целиком, а не то, что из него удалось разобрать.
  final String? raw;

  const LoadResult({
    this.data,
    this.wasMigrated = false,
    this.wasCorrupt = false,
    this.fromTestVersion = false,
    this.fromFuture = false,
    this.raw,
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
  /// [LoadResult.wasCorrupt], игра стартует заново. Сейв новой версии —
  /// [LoadResult.fromFuture], его не трогают вовсе.
  LoadResult decode(String? raw) {
    if (raw == null || raw.isEmpty) return const LoadResult();
    final corrupt = LoadResult(wasCorrupt: true, raw: raw);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return corrupt;
      json = decoded;
    } catch (_) {
      return corrupt;
    }

    var version = json['version'];
    if (version is! int || version < 1) return corrupt;

    // Сейв из будущей версии (откат приложения) — безопаснее не трогать.
    if (version > kSaveVersion) return LoadResult(fromFuture: true, raw: raw);

    final migrated = version < kSaveVersion;
    while (version < kSaveVersion) {
      final step = _migrations[version];
      if (step == null) return corrupt;
      json = step(json);
      version++;
      json['version'] = version;
    }

    return LoadResult(data: json, wasMigrated: migrated, raw: raw);
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

  /// Полный сброс стирает только сейв: отложенные копии — не нынешний
  /// гараж, и сброс нынешнего их не касается.
  Future<void> wipe() => storage.clear();

  /// Сколько нечитаемых сейвов держим отложенными.
  ///
  /// Лежащая копия не перезаписывается следующей: она — единственное место,
  /// где живёт потерянный гараж, и затереть её новой порчей значило бы
  /// потерять его так же молча, только на шаг позже. Новая ложится рядом:
  /// во второй раз ломается уже новый гараж, и он тоже чей-то прогресс.
  ///
  /// Потолок — на случай, когда сейв ломается на каждом запуске. Это поломка
  /// в самой игре, и каждая новая копия — свежий гараж на пару минут, а
  /// ценна первая. Без потолка копии съели бы хранилище браузера (около
  /// 5 МБ на сайт), и перестал бы писаться сам сейв. Сверх потолка копия не
  /// ложится, и игроку это говорят прямо, давая скопировать строку.
  static const int maxRescued = 3;

  /// Отложить нечитаемый сейв. Звать ДО первой записи: основной ключ
  /// перезапишет первый же автосейв.
  ///
  /// `true` — копия лежит, в том числе если такая же уже лежала: игру
  /// закрыли раньше автосейва, и тот же битый сейв прочитан второй раз.
  /// `false` — не легла: упёрлись в [maxRescued] или отказало хранилище.
  /// Тогда выдавать её игроку за сохранённую нельзя.
  Future<bool> rescue(String raw) async {
    final copies = await rescued();
    if (copies.contains(raw)) return true;
    if (copies.length >= maxRescued) return false;
    final encoded = jsonEncode([...copies, raw]);
    try {
      await storage.writeRescue(encoded);
      // Переполненное хранилище браузера может не принять запись, ничего не
      // сказав. Верим только тому, что читается обратно.
      return await storage.readRescue() == encoded;
    } catch (_) {
      return false;
    }
  }

  /// Отложенные копии, старые первыми.
  Future<List<String>> rescued() async {
    final stored = await storage.readRescue();
    if (stored == null || stored.isEmpty) return const [];
    // Не список строк — всё равно не выбрасываем: ключ заведён ровно затем,
    // чтобы ничего не терять.
    try {
      final list = jsonDecode(stored);
      if (list is List && list.every((e) => e is String)) {
        return List<String>.from(list);
      }
    } on FormatException {
      return [stored];
    }
    return [stored];
  }

  /// Убрать одну копию: гараж из неё вернули или игрок оставил нынешний.
  Future<void> forget(String raw) async {
    final rest = [...await rescued()]..remove(raw);
    if (rest.isEmpty) return storage.clearRescue();
    return storage.writeRescue(jsonEncode(rest));
  }
}
