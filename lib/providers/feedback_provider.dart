/// Звук и вибрация в дереве провайдеров.
///
/// Выключатели живут здесь, а не внутри [Feedback], потому что их надо и
/// сохранять, и показывать галочкой. Сам [Feedback] про хранилище не знает —
/// ему говорят «включено» или «выключено».
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import '../core/sfx.dart';
import 'settings_provider.dart';

/// Куда выводить звук.
///
/// По умолчанию — в тишину. Настоящий вывод подставляется в `main` через
/// override, и благодаря этому ни один тест не пытается открыть динамик.
final soundOutputProvider = Provider<SoundOutput>((ref) {
  const output = SilentOutput();
  ref.onDispose(output.dispose);
  return output;
});

/// Включён ли звук. Читается из настроек один раз при создании.
class SoundEnabled extends Notifier<bool> {
  @override
  bool build() =>
      settingOn(ref.read(settingsStoreProvider).read(SettingsKeys.sound));

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).write(SettingsKeys.sound, settingValue(on));
  }

  void toggle() => set(!state);
}

final soundEnabledProvider =
    NotifierProvider<SoundEnabled, bool>(SoundEnabled.new);

/// Включена ли вибрация.
class HapticsEnabled extends Notifier<bool> {
  @override
  bool build() =>
      settingOn(ref.read(settingsStoreProvider).read(SettingsKeys.haptics));

  void set(bool on) {
    state = on;
    ref
        .read(settingsStoreProvider)
        .write(SettingsKeys.haptics, settingValue(on));
  }

  void toggle() => set(!state);
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabled, bool>(HapticsEnabled.new);

/// Отдача игры.
///
/// `watch`, а не `read`, у выключателей намеренно: переключив галочку, игрок
/// обязан услышать разницу со следующего же нажатия, не перезапуская игру.
final feedbackProvider = Provider<Feedback>((ref) {
  final feedback = Feedback(
    output: ref.watch(soundOutputProvider),
    sound: ref.watch(soundEnabledProvider),
    haptics: ref.watch(hapticsEnabledProvider),
  );
  return feedback;
});
