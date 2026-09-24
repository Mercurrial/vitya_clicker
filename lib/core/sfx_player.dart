/// Настоящий звук — поверх `audioplayers`.
///
/// Единственное место в проекте, которое знает про звуковой плагин. Остальной
/// код видит только [SoundOutput] — по той же причине, по которой сейв видит
/// только `SaveStorage`: логика не должна зависеть от плагина, иначе её
/// нельзя проверить тестом.
library;

import 'package:audioplayers/audioplayers.dart';

import 'sfx.dart';

class AudioSfxOutput implements SoundOutput {
  /// По проигрывателю на звук.
  ///
  /// Один общий не годится: подкинуть дров можно быстрее, чем доиграет
  /// предыдущий удар, и звуки обрывали бы друг друга. Отдельный проигрыватель
  /// перезапускается сам с собой — это слышно как частые удары, что и нужно.
  ///
  /// Создаются лениво: игрок может не дойти до похмелья за весь вечер, и
  /// держать под него проигрыватель с первой секунды незачем.
  final Map<Sfx, AudioPlayer> _players = {};

  bool _configured = false;

  @override
  void play(Sfx sfx) {
    // Ни одна ошибка звука не имеет права остановить игру: в браузере до
    // первого касания звуковой контекст вообще запрещён, и это нормально.
    try {
      _configure();
      final player = _players.putIfAbsent(sfx, _make);
      player.play(AssetSource(sfx.asset));
    } catch (e) {
      reportSfxFailure(e);
    }
  }

  AudioPlayer _make() => AudioPlayer()
    // Короткие эффекты: задержка важнее качества буферизации.
    ..setPlayerMode(PlayerMode.lowLatency)
    ..setReleaseMode(ReleaseMode.stop);

  /// Звук игры не должен глушить чужую музыку.
  ///
  /// По умолчанию плагин просит исключительный доступ к динамику, и запуск
  /// игры обрывал бы то, что человек слушает. Для эффектов это недопустимо:
  /// в неё играют именно фоном.
  void _configure() {
    if (_configured) return;
    _configured = true;
    AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
