/// Отдача игры: звук и вибрация.
///
/// ## Почему это один фасад, а не два вызова по месту
///
/// Раньше вибрация звалась напрямую — `HapticFeedback.mediumImpact()` в шести
/// местах. Пока её нельзя было выключить, это работало. Стоит появиться
/// галочке в настройках, и каждое из шести мест обязано про неё помнить, а
/// седьмое, дописанное через месяц, — уже не вспомнит.
///
/// Поэтому и звук, и вибрация проходят через [Feedback]. Он один смотрит на
/// настройки, и добавить новое место отдачи, забыв про выключатель, нельзя:
/// другого пути просто нет.
///
/// ## Почему звук не ждут
///
/// [Feedback.play] ничего не возвращает и никогда не бросает. Звук — украшение;
/// если звуковая подсистема недоступна (а в браузере до первого касания она
/// именно такова), игра обязана продолжать работать молча, а не падать.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Что звучит.
enum Sfx {
  /// Подкинуть дров — начало зажима.
  stoke,

  /// Жар вошёл в окно.
  window,

  /// Перегрел: серия сгорела.
  overheat,

  /// Купил аппарат или улучшение.
  buy,

  /// Сдал товар.
  sell,

  /// Лёг проспаться.
  hangover,
}

extension SfxAsset on Sfx {
  /// Путь внутри `assets/`. Файлы синтезируются `tools/make_sounds.dart`.
  String get asset => 'sfx/$name.wav';
}

/// Сила вибрации. Своё перечисление, а не `HapticFeedback` напрямую, — чтобы
/// вызывающий код не знал про `package:flutter/services`.
enum Buzz { light, medium, select }

/// Кто умеет издавать звук. Подменяется в тестах и на платформах без звука.
abstract class SoundOutput {
  void play(Sfx sfx);
  void dispose();
}

/// Тишина. Используется в тестах и когда звук выключен.
class SilentOutput implements SoundOutput {
  const SilentOutput();

  @override
  void play(Sfx sfx) {}

  @override
  void dispose() {}
}

/// Отдача с оглядкой на настройки.
class Feedback {
  final SoundOutput _output;

  /// Читаются из настроек при создании и меняются переключателем.
  bool sound;
  bool haptics;

  Feedback({
    required SoundOutput output,
    this.sound = true,
    this.haptics = true,
  }) : _output = output;

  void play(Sfx sfx) {
    if (!sound) return;
    _output.play(sfx);
  }

  void buzz(Buzz kind) {
    if (!haptics) return;

    // Вибрация ходит через платформенный канал, а он может оказаться
    // недоступен: браузер, рабочий стол, запуск без биндинга. Уронить из-за
    // этого покупку было бы абсурдно.
    //
    // Ловим в ДВА приёма, и это не перестраховка. `HapticFeedback` —
    // асинхронный: ошибка канала не вылетает из вызова, а приезжает в
    // возвращённом Future. Обычный try её не видит, и она всплывает как
    // необработанная — что и уронило половину тестов, когда защита была одна.
    try {
      final done = switch (kind) {
        Buzz.light => HapticFeedback.lightImpact(),
        Buzz.medium => HapticFeedback.mediumImpact(),
        Buzz.select => HapticFeedback.selectionClick(),
      };
      done.catchError(reportSfxFailure);
    } catch (e) {
      reportSfxFailure(e);
    }
  }

  /// Звук и вибрация разом — обычный случай для заметного действия.
  void hit(Sfx sfx, Buzz kind) {
    play(sfx);
    buzz(kind);
  }

  void dispose() => _output.dispose();
}

/// Разбор значения настройки. Отсутствующая настройка означает «включено»:
/// игрок, который ничего не трогал, должен получить игру целиком.
bool settingOn(String? raw) => raw != 'off';

/// Как записать настройку обратно.
String settingValue(bool on) => on ? 'on' : 'off';

/// Логировать ли сбои звука. В отладке — да, в собранной игре — нет: игроку
/// от сообщения «не смог проиграть wav» пользы никакой.
void reportSfxFailure(Object error) {
  if (kDebugMode) debugPrint('звук не проигрался: $error');
}
