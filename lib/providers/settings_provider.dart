/// Хранилище настроек в дереве провайдеров.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';

/// Хранилище настроек. Подменяется в `main` через override; без него игра
/// работает, но звук, вибрация и обучение не переживут перезапуск (так и в
/// тестах).
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => MemorySettingsStore());
