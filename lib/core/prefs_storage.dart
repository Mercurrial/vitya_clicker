/// Реальное хранилище сейва поверх `shared_preferences`.
///
/// Единственное место в проекте, которое знает про плагин: остальной код видит
/// только [SaveStorage]. Благодаря этому логика сейвов тестируется без плагинов
/// (см. `MemorySaveStorage`).
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'save.dart';

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
