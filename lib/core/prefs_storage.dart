/// Реальное хранилище сейва поверх `shared_preferences`.
///
/// Единственное место в проекте, которое знает про плагин: остальной код видит
/// только [SaveStorage]. Благодаря этому логика сейвов тестируется без плагинов
/// (см. `MemorySaveStorage`).
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'save.dart';
import 'settings.dart';

class PrefsSaveStorage implements SaveStorage {
  static const String _key = 'vitya_save_v1';

  final SharedPreferences _prefs;

  const PrefsSaveStorage(this._prefs);

  /// Готовит хранилище; вызывать один раз на старте после
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<PrefsSaveStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsSaveStorage(prefs);
  }

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String data) async => _prefs.setString(_key, data);

  @override
  Future<void> clear() async => _prefs.remove(_key);
}

/// Настройки поверх того же `shared_preferences`.
///
/// Читает синхронно: экземпляр [SharedPreferences] уже держит значения в
/// памяти, а настройка нужна на первом же кадре — ждать её асинхронно значило
/// бы показать игроку один стиль и тут же подменить другим.
class PrefsSettingsStore implements SettingsStore {
  static const String _prefix = 'vitya_setting_';

  final SharedPreferences _prefs;

  const PrefsSettingsStore(this._prefs);

  @override
  String? read(String key) => _prefs.getString('$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _prefs.setString('$_prefix$key', value);
}

/// Открывает оба хранилища на одном экземпляре `shared_preferences`.
Future<({PrefsSaveStorage saves, PrefsSettingsStore settings})>
    openStorages() async {
  final prefs = await SharedPreferences.getInstance();
  return (saves: PrefsSaveStorage(prefs), settings: PrefsSettingsStore(prefs));
}
