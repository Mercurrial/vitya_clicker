import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';

import 'support/economy_fingerprint.dart';
import 'support/save_facts.dart';

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
/// Каждый выпуск кладёт рядом свой эталон: так накапливается история
/// форматов, и каждая новая версия проверяется против всех прошлых.
///
/// ## До выпуска
///
/// Эталоны тестовых сборок (1.0.0 и 1.1.0 для своих) удалены при чистом
/// старте (docs/DECISIONS.md): их сейвы выпуск не читает. Пока папка пуста,
/// игроков нет — договариваться не с кем. Версии баланса и сейва стоят на
/// единице, журнал не пишется, отпечаток чисел не сверяется: экономику ещё
/// перестраивают, и объяснять правку некому.
///
/// Первый эталон снимает выпуск 1.0.0 (`tools/make_fixture.dart`), и с ним
/// всё строгое включается само — без чьей-то памяти и без правки этого
/// файла, кроме отпечатка, который выпуск записывает вместе с эталоном.
void main() {
  const ser = GameSerializer();
  const codec = SaveCodec();
  final now = DateTime.utc(2026, 12, 1);

  final dir = Directory('test/fixtures');
  final saves = dir.existsSync()
      ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))
      : <File>[];

  final released = saves.isNotEmpty;

  group('До выпуска версии не поднимаются', () {
    // Пока эталона нет, подъём версии — не забота об игроке, а шум: у
    // выпуска появился бы журнал из записей, которые никто не застал, и
    // миграции из форматов, которых ни у кого нет.
    test('версия баланса — 1, в журнале одна запись', () {
      expect(kBalanceVersion, 1,
          reason: 'эталона в test/fixtures нет — игроков нет, версию '
              'баланса до выпуска не поднимают');
      expect([for (final r in kBalanceLog) r.version], [1],
          reason: 'до выпуска журнал не пишется: объяснять правку некому');
    });

    test('версия сейва — 1', () {
      expect(kSaveVersion, 1,
          reason: 'эталона в test/fixtures нет — формат до выпуска правится '
              'на месте, без версий и миграций');
    });
  }, skip: released ? 'выпуск состоялся: действуют правила ниже' : false);

  // Факты эталона, которые загрузка вправе поменять, — путь и почему; путь
  // покрывает и всё, что под ним. Служебные ключи (version, balanceVersion,
  // lastSeen) не факты и в сверку не входят вовсе — см. kServiceKeys.
  //
  // Сейчас здесь пусто: загрузка ничего не пересчитывает, только читает.
  // Сюда попадает осознанная правка после выпуска — id, убранный из игры,
  // ключ, переименованный миграцией, — с тем, чем это возмещено игроку или
  // куда переехало значение. Не способ заглушить упавшую сверку: пропавший
  // факт — это то, что игрок потерял.
  const mayChange = <String, String>{};

  group('Сейвы выпущенных версий открываются', () {
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

        // Факты обязаны пережить обновление — все, а не выборочно: сверка
        // двух ключей из двадцати пропустила бы потерю потока, статистики
        // или портала. Сверяется с файлом, а не с тем, что вернула миграция:
        // факт, потерянный миграцией, игрок теряет точно так же. Оценки
        // (доход, мудрость) могут измениться — на то они и оценки, в сейве
        // их нет.
        final original =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final lost = lostFacts(
          original,
          ser.toJson(state, lastSeenMillis: now.millisecondsSinceEpoch),
          allowed: mayChange,
        );
        expect(lost, isEmpty,
            reason: 'сейв версии $name открылся, но потерял факты — у каждого, '
                'кто на ней играл, пропадёт то же самое');

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
    // Отпечаток — все числа экономики, от которых зависят доход, цены и
    // скорость прогресса, а не только поля Balance.
    //
    // Нужен потому, что забыть поднять kBalanceVersion очень легко: правишь
    // одно число, тесты зелёные, а игрок при обновлении не получает ни
    // объяснения, ни компенсации — просто замечает, что доход поехал.
    // Отпечаток превращает эту забывчивость в упавший тест. Первый отпечаток
    // собирался из одних полей Balance и промолчал бы о правке цены сорта,
    // гостя или серии жара.
    //
    // Что в отпечатке, а что сознательно нет, — test/support/
    // economy_fingerprint.dart. Что каждое число в него действительно
    // попадает и что новое не забыто, проверяет economy_fingerprint_test —
    // всегда, а не только после выпуска.
    //
    // До выпуска сверка пропускается: экономику ещё перестраивают. Выпуск,
    // снимая первый эталон, записывает сюда действующий отпечаток — тест
    // сам его напечатает, упав на первом прогоне с эталоном.
    test('числа экономики совпадают с записанным отпечатком', skip: released
        ? false
        : 'до выпуска: эталона в test/fixtures нет, числа ещё правят', () {
      // Пусто до выпуска 1.0.0: записывает выпуск (задача 9 плана).
      const expected = r'''
''';

      final actual = economyFingerprint(currentEconomy());
      final changes = fingerprintChanges(expected, actual);
      if (changes.isEmpty) return;

      final block = "const expected = r'''\n$actual\n''';";
      fail(expected.trim().isEmpty
          ? 'отпечаток чисел экономики не записан. Выпуск записывает его '
              'вместе с первым эталоном — вот действующий, целиком:\n\n$block'
          : 'числа экономики изменились:\n${changes.join('\n')}\n\n'
              'Это нормально — но тогда:\n'
              '  1) подними kBalanceVersion;\n'
              '  2) добавь запись в kBalanceLog: что изменилось и почему;\n'
              '  3) если игроку стало хуже — isNerf: true и компенсация;\n'
              '  4) обнови отпечаток здесь:\n\n$block\n\n'
              'Пункт 3 — единственная причина, по которой всё это существует.');
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

    test('номер сборки не меньше розданного', () {
      // Имя версии при чистом старте ушло с 1.1.0 назад на 1.0.0, а номер
      // сборки — нет: у друзей стоит APK 1.1.0+2, и Android не поставит
      // поверх сборку с меньшим номером. Удалить игру ради обновления —
      // потерять гараж.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final build = RegExp(r'^version:\s*\S+\+(\d+)', multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(int.tryParse(build ?? ''), greaterThan(2),
          reason: 'розданная сборка — 1.1.0+2; следующая обязана быть больше');
    });
  });
}
