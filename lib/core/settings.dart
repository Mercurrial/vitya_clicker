/// Настройки интерфейса.
///
/// Живут ОТДЕЛЬНО от сейва, и это осознанно. Сейв версионирован и обвешан
/// миграциями, потому что в нём прогресс: потерять его нельзя. Звук и
/// вибрация — не прогресс. Сунуть его в тот же JSON значило бы поднимать версию формата
/// и писать миграцию ради галочки в настройках.
///
/// Хранилище спрятано за [SettingsStore] по той же причине, что и сейв:
/// игровой код не должен знать про плагины.
library;

/// Куда физически кладём настройки.
abstract class SettingsStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// Настройки в памяти — для тестов и для платформ без плагинов.
class MemorySettingsStore implements SettingsStore {
  final Map<String, String> _values;

  MemorySettingsStore([Map<String, String>? initial])
      : _values = {...?initial};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Ключи настроек. Строки собраны здесь, чтобы опечатка в одном месте не
/// приводила к молча потерянной настройке.
abstract final class SettingsKeys {
  /// Докуда дошло обучение. В настройках, а не в сейве: это не прогресс
  /// гаража, и поднимать ради него версию формата сохранения незачем.
  static const tutorial = 'tutorial_step';

  /// Звук и вибрация. Хранятся строками 'on'/'off' — формат хранилища
  /// строковый, а заводить сериализацию булева ради двух галочек незачем.
  static const sound = 'sound';
  static const haptics = 'haptics';
}
