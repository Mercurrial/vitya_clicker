import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';

/// Договор с уже выпущенной версией.
///
/// Всё остальное тестирование отвечает на вопрос «работает ли то, что я
/// написал сегодня». Этот файл отвечает на другой: **не сломал ли я то, что
/// уже стоит у людей на телефонах**. Это разные вопросы, и второй важнее:
/// ошибку в новой фиче игрок переживёт, потерю гаража — нет.
///
/// ## Эталонный сейв
///
/// В `test/fixtures/` лежит настоящий сейв, записанный выпущенной версией.
/// Каждая следующая версия обязана его открыть и не потерять факты. Файл
/// НЕ ПРАВИТСЯ — это снимок прошлого, а не тестовые данные. Если он перестал
/// читаться, чинить надо код, а не файл.
///
/// Когда выйдет 1.1, рядом ляжет её эталон: так накапливается история
/// форматов, и каждая новая версия проверяется против всех прошлых.
void main() {
  const ser = GameSerializer();
  const codec = SaveCodec();
  final now = DateTime.utc(2026, 12, 1);

  final dir = Directory('test/fixtures');
  final saves = dir.existsSync()
      ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))
      : <File>[];

  group('Сейвы выпущенных версий открываются', () {
    test('эталоны вообще существуют', () {
      expect(saves, isNotEmpty,
          reason: 'без эталонного сейва обещание «обновление не потеряет '
              'прогресс» ничем не подкреплено');
    });

    for (final file in saves) {
      final name = file.uri.pathSegments.last;

      test('$name читается текущей версией', () {
        final result = codec.decode(file.readAsStringSync());

        expect(result.wasCorrupt, isFalse,
            reason: 'сейв версии $name перестал читаться — это потерянный '
                'гараж у каждого, кто на ней играл');
        expect(result.data, isNotNull);

        final state = ser.fromJson(
          result.data!,
          content: kGenerators,
          upgrades: kUpgrades,
          now: now,
        );

        // Факты обязаны пережить обновление. Оценки (доход, мудрость) могут
        // измениться — на то они и оценки.
        final original = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final stills = (original['stills'] as Map?) ?? const {};
        for (final entry in stills.entries) {
          final owned = state.generators.items
              .firstWhere((g) => g.id == entry.key,
                  orElse: () => kGenerators.first)
              .ownedCount;
          if (kGenerators.any((g) => g.id == entry.key)) {
            expect(owned, entry.value,
                reason: 'потеряны аппараты «${entry.key}»');
          }
        }

        expect(state.prestige.totalEverEarned,
            closeTo((original['lifetime'] as num?)?.toDouble() ?? 0, 1e-6),
            reason: 'потеряна история — из неё растёт вся мудрость');

        // И главное: состояние живое, а не просто разобранное.
        expect(() => state.mlPerSecond, returnsNormally);
        expect(state.mlPerSecond, greaterThanOrEqualTo(0));
      });

      test('$name переживает круг через код переноса', () {
        // Игрок мог сохранить прогресс кодом на старой версии и вставить его
        // уже на новой.
        final code = encodeSaveCode(file.readAsStringSync());
        final back = decodeSaveCode(code);

        expect(back.isOk, isTrue, reason: back.message);
        expect(codec.decode(back.save).wasCorrupt, isFalse);
      });
    }
  });

  group('Забыть поднять версию баланса нельзя', () {
    /// Отпечаток действующих чисел.
    ///
    /// Нужен потому, что забыть поднять [kBalanceVersion] очень легко: правишь
    /// одно число в `balance.dart`, тесты зелёные, а игрок при обновлении не
    /// получает ни объяснения, ни компенсации — просто замечает, что доход
    /// поехал. Отпечаток превращает эту забывчивость в упавший тест.
    ///
    /// Поменял числа — поменяй и отпечаток, добавив запись в [kBalanceLog] и
    /// подняв версию. Это ровно тот момент, когда стоит остановиться и
    /// подумать, что сказать игроку.
    String fingerprint(Balance b) => [
          b.costGrowth,
          b.firstWisdomMl,
          b.bonusPerWisdom,
          b.basePricePerMl,
          b.baseTankMl,
          b.baseBufferSeconds,
          b.maxBufferSeconds,
          b.milestones.join(','),
          b.firstGeneratorCost,
          b.tierCostRatio,
          b.firstGeneratorOutput,
          b.tierOutputRatio,
          b.raidSeizure,
        ].join('|');

    test('числа баланса совпадают с записанным отпечатком', () {
      const expected = '1.26|250000000.0|0.08|0.1|2000.0|120.0|1800.0|'
          '10,25,50,100|15.0|30.0|1.0|6.05|0.4';

      expect(
        fingerprint(kBalance),
        expected,
        reason: 'числа баланса изменились. Это нормально — но тогда:\n'
            '  1) подними kBalanceVersion;\n'
            '  2) добавь запись в kBalanceLog: что изменилось и почему;\n'
            '  3) если игроку стало хуже — назначь компенсацию;\n'
            '  4) обнови отпечаток здесь.\n'
            'Пункт 3 — единственная причина, по которой всё это существует.',
      );
    });

    test('версия баланса объявлена в журнале', () {
      final versions = {for (final r in kBalanceLog) r.version};
      expect(versions, contains(kBalanceVersion),
          reason: 'текущая версия баланса не описана в kBalanceLog: игрок '
              'увидит изменения, но не получит объяснения');
    });
  });

  group('Версия приложения', () {
    test('в pubspec стоит версия с номером сборки', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);

      expect(match, isNotNull);
      final version = match!.group(1)!;
      expect(version, contains('+'),
          reason: 'без +N Android не отличит новую сборку от старой и не даст '
              'поставить обновление поверх');
    });
  });
}
