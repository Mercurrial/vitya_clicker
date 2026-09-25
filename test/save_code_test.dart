import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';

/// Перенос прогресса строкой.
///
/// Эта штука существует ради одного: на iPhone игра живёт как сайт, и её сейв
/// лежит в хранилище браузера, откуда его можно потерять. Код — запасной
/// выход. Если он окажется ненадёжным, он бесполезен: игрок узнает об этом
/// ровно в тот момент, когда прогресс уже потерян.
void main() {
  const save = '{"version":5,"ml":1234.5,"money":99,"stills":{"banka":7},'
      '"bought":["tap_ruka"],"claimedMl":250000.0,"lifetime":3e6}';

  group('Круг: свернуть и развернуть', () {
    test('прогресс возвращается байт в байт', () {
      final result = decodeSaveCode(encodeSaveCode(save));
      expect(result.isOk, isTrue, reason: result.message);
      expect(result.save, save);
    });

    test('внутри кода лежит настоящий JSON', () {
      final back = decodeSaveCode(encodeSaveCode(save)).save!;
      final json = jsonDecode(back) as Map<String, dynamic>;
      expect(json['stills'], {'banka': 7});
      expect(json['claimedMl'], 250000.0);
    });

    test('код узнаётся по началу строки', () {
      expect(encodeSaveCode(save).startsWith(kSaveCodePrefix), isTrue);
    });

    test('пробелы и переносы из мессенджера не мешают', () {
      // Код почти всегда приезжает вставкой из чата, где его переносит.
      final code = encodeSaveCode(save);
      final mangled = '  ${code.substring(0, 20)}\n'
          '${code.substring(20, 60)} ${code.substring(60)}  ';
      expect(decodeSaveCode(mangled).save, save);
    });

    test('русские буквы внутри сейва переживают дорогу', () {
      const withCyrillic = '{"note":"Дедов запас, ½ бака"}';
      expect(decodeSaveCode(encodeSaveCode(withCyrillic)).save, withCyrillic);
    });
  });

  group('Битый код не портит прогресс', () {
    test('обрезанный код отвергается', () {
      final code = encodeSaveCode(save);
      final cut = code.substring(0, code.length - 12);
      final result = decodeSaveCode(cut);
      expect(result.isOk, isFalse);
      expect(result.error, SaveCodeError.damaged);
    });

    test('подменённый символ в середине отвергается', () {
      final code = encodeSaveCode(save);
      final mid = code.length ~/ 2;
      final broken = code.replaceRange(
        mid,
        mid + 1,
        code[mid] == 'A' ? 'B' : 'A',
      );
      expect(decodeSaveCode(broken).error, SaveCodeError.damaged);
    });

    test('чужой текст не притворяется кодом', () {
      for (final junk in ['', '   ', 'привет', 'вот мой код', 'VITYA', 'VITYA1.']) {
        final result = decodeSaveCode(junk);
        expect(result.isOk, isFalse, reason: 'принял «$junk»');
      }
      expect(decodeSaveCode(null).error, SaveCodeError.notACode);
    });

    test('код из будущей версии не разбирается вслепую', () {
      final code = encodeSaveCode(save);
      final fromFuture = code.replaceFirst(
        '$kSaveCodePrefix$kSaveCodeVersion',
        '$kSaveCodePrefix${kSaveCodeVersion + 1}',
      );
      expect(decodeSaveCode(fromFuture).error, SaveCodeError.fromFuture);
    });

    test('код тестовой сборки узнаётся и объясняется', () {
      // До выпуска 1.0.0 коды начинались с VITYA1. Сейв внутри такого кода —
      // тестового формата, и разобрать его как новый нельзя: номера версий
      // совпадают, а смысл — нет.
      final code = encodeSaveCode(save);
      final testCode = code.replaceFirst(
        '$kSaveCodePrefix$kSaveCodeVersion',
        '${kSaveCodePrefix}1',
      );
      final result = decodeSaveCode(testCode);
      expect(result.isOk, isFalse);
      expect(result.error, SaveCodeError.fromTestVersion);
    });

    test('валидная база64 с мусором внутри не проходит', () {
      // Кто-то собрал код руками: сумма сойдётся, а содержимое не наше.
      final payload = base64Url.encode(utf8.encode('это не json'));
      var crc = 0xFFFFFFFF;
      for (final b in utf8.encode(payload)) {
        var c = (crc ^ b) & 0xFF;
        for (var k = 0; k < 8; k++) {
          c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
        }
        crc = c ^ (crc >> 8);
      }
      final code = '$kSaveCodePrefix$kSaveCodeVersion.$payload.'
          '${((crc ^ 0xFFFFFFFF) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
      expect(decodeSaveCode(code).isOk, isFalse);
    });

    test('у каждой беды своё объяснение для игрока', () {
      for (final error in SaveCodeError.values) {
        final result = SaveCodeResult.failed(error);
        expect(result.message, isNotEmpty);
        expect(result.message.toLowerCase().contains('ошибка'), isFalse,
            reason: '«ошибка» — это не объяснение: ${result.message}');
      }
    });
  });

  group('Размер', () {
    test('код влезает в одно сообщение', () {
      // Настоящий сейв поздней игры: всё куплено, все достижения открыты.
      final big = jsonEncode({
        'version': 1,
        'ml': 1.2345e12,
        'money': 9.87e14,
        'taps': 123456,
        'stills': {for (var i = 0; i < 13; i++) 'generator_$i': 9999},
        'bought': [for (var i = 0; i < 22; i++) 'upgrade_number_$i'],
        'achievements': [for (var i = 0; i < 30; i++) 'achievement_number_$i'],
        'claimedMl': 4.79e18,
        'lifetime': 5.1e18,
        'hangovers': 42,
        'balanceVersion': 1,
        'lastSeen': 1780000000000,
      });
      final code = encodeSaveCode(big);
      // Предел — одно сообщение в мессенджере (около четырёх тысяч знаков).
      // Здесь нарочно худший случай: всё куплено и всё открыто.
      expect(code.length, lessThan(3500),
          reason: 'код длиной ${code.length} в одно сообщение не влезет');
      expect(decodeSaveCode(code).save, big);
    });
  });

  group('Перенос через настоящую игру', () {
    test('прогресс переезжает на «другое устройство» целиком', () async {
      final container = ProviderContainer(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
      );
      addTearDown(container.dispose);

      // Играем: покупаем аппараты, берём улучшение, копим историю.
      final notifier = container.read(gameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        resources: notifier.state.resources.copyWith(money: 1e9),
      );
      for (var i = 0; i < 14; i++) {
        notifier.buyGenerator('banka');
      }
      notifier.buyGenerator('bidon');
      notifier.buyUpgrade('tap_ruka');
      notifier.registerTouch();
      final before = container.read(gameProvider);

      final code = notifier.exportCode();

      // «Другое устройство»: чистый контейнер, ничего не знающий о первом.
      final fresh = ProviderContainer(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
      );
      addTearDown(fresh.dispose);

      final error = await fresh.read(gameProvider.notifier).importCode(code);
      expect(error, isNull);

      final after = fresh.read(gameProvider);
      int owned(GameState s, String id) =>
          s.generators.items.firstWhere((g) => g.id == id).ownedCount;
      expect(owned(after, 'banka'), owned(before, 'banka'));
      expect(owned(after, 'bidon'), owned(before, 'bidon'));
      expect(after.resources.money, closeTo(before.resources.money, 1e-6));
      expect(after.mlPerSecond, closeTo(before.mlPerSecond, 1e-9));
      expect(after.clicker.totalTaps, before.clicker.totalTaps);
      expect(
        after.upgrades.items.where((u) => u.purchased).map((u) => u.id),
        contains('tap_ruka'),
      );
    });

    test('мусор из буфера не стирает текущий прогресс', () async {
      final container = ProviderContainer(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        resources: notifier.state.resources.copyWith(money: 777),
      );

      for (final junk in [null, '', 'случайно скопировал сообщение']) {
        final error = await notifier.importCode(junk);
        expect(error, isNotNull, reason: 'принял «$junk»');
      }
      expect(container.read(gameProvider).resources.money, 777,
          reason: 'неудачный импорт обязан оставить гараж как был');
    });

    test('код тестовой сборки не трогает гараж', () async {
      final container = ProviderContainer(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
      );
      addTearDown(container.dispose);

      // Код тестовой сборки: сейв v5 внутри, версия кода 1. Собран тем же
      // кодировщиком и переписан на версию 1 — сумма от этого не меняется.
      final testCode = encodeSaveCode(
        '{"version": 5, "ml": 0, "money": 5e6, "lifetime": 8.4e9}',
      ).replaceFirst('$kSaveCodePrefix$kSaveCodeVersion', '${kSaveCodePrefix}1');

      final notifier = container.read(gameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        resources: notifier.state.resources.copyWith(money: 777),
      );

      expect(await notifier.importCode(testCode),
          SaveCodeError.fromTestVersion);
      expect(container.read(gameProvider).resources.money, 777);
    });
  });
}
