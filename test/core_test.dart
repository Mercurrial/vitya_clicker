import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/formatters.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/save.dart';

void main() {
  group('Fmt.short', () {
    test('числа меньше тысячи — целые, без суффикса', () {
      expect(Fmt.short(0), '0');
      expect(Fmt.short(7.9), '7');
      expect(Fmt.short(999), '999');
    });

    test('переходы через степени тысячи', () {
      expect(Fmt.short(1000), '1К');
      expect(Fmt.short(1500), '1.5К');
      expect(Fmt.short(2300000), '2.3М');
      expect(Fmt.short(4.2e9), '4.2Б');
      expect(Fmt.short(1e12), '1Т');
    });

    test('значащих цифр всегда три — ширина не скачет', () {
      expect(Fmt.short(9990), '9.99К');
      expect(Fmt.short(99900), '99.9К');
      expect(Fmt.short(999000), '999К');
    });

    test('хвостовые нули срезаются, а живым счётчикам остаются', () {
      // «10К л» читается сразу, «10.00К л» — как ошибка округления. А вот
      // касса тикает каждый кадр, и её ширина прыгать не должна.
      expect(Fmt.short(10000), '10К');
      expect(Fmt.short(2500), '2.5К');
      expect(Fmt.short(1500, trim: false), '1.50К');
      expect(Fmt.money(2000, trim: false), '2.00К ₽');
      expect(Fmt.volume(1200, trim: false), '1.20 л');
    });

    test('крайние случаи не роняют игру', () {
      expect(Fmt.short(double.nan), '0');
      expect(Fmt.short(double.infinity), '∞');
      expect(Fmt.short(-1500), '-1.5К');
    });
  });

  group('Fmt.volume — миллилитры и литры', () {
    test('до литра показываем миллилитры', () {
      expect(Fmt.volume(0), '0 мл');
      expect(Fmt.volume(5), '5 мл');
      expect(Fmt.volume(850.7), '850 мл');
      expect(Fmt.volume(999), '999 мл');
    });

    test('от литра переключаемся на литры', () {
      expect(Fmt.volume(1000), '1 л');
      expect(Fmt.volume(1200), '1.2 л');
      expect(Fmt.volume(2500000), '2.5К л');
    });

    test('число и единица согласованы между собой', () {
      expect(Fmt.volumeNumber(850), '850');
      expect(Fmt.volumeUnit(850), 'мл');
      expect(Fmt.volumeNumber(1200), '1.2');
      expect(Fmt.volumeUnit(1200), 'л');
    });

    test('скорость получает суффикс', () {
      expect(Fmt.rate(120), '120 мл/с');
      expect(Fmt.rate(5000), '5 л/с');
    });
  });

  group('Fmt.clock — обратный отсчёт', () {
    test('минуты и секунды, с часами — если нужно', () {
      expect(Fmt.clock(const Duration(seconds: 7)), '0:07');
      expect(Fmt.clock(const Duration(minutes: 12, seconds: 3)), '12:03');
      expect(Fmt.clock(const Duration(hours: 1, minutes: 5)), '1:05:00');
    });
  });

  group('Fmt.plural — русское склонение', () {
    String litres(int n) => Fmt.plural(n, 'литр', 'литра', 'литров');

    test('единственное число', () {
      expect(litres(1), 'литр');
      expect(litres(21), 'литр');
      expect(litres(101), 'литр');
    });

    test('от двух до четырёх', () {
      expect(litres(2), 'литра');
      expect(litres(23), 'литра');
    });

    test('множественное', () {
      expect(litres(5), 'литров');
      expect(litres(0), 'литров');
    });

    test('исключение 11–14', () {
      expect(litres(11), 'литров');
      expect(litres(12), 'литров');
      expect(litres(14), 'литров');
      expect(litres(111), 'литров');
    });
  });

  group('GameClock', () {
    DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

    test('нет метки — нет начисления', () {
      const clock = GameClock();
      expect(clock.since(null).elapsed, Duration.zero);
      expect(clock.since(0).elapsed, Duration.zero);
    });

    test('обычное отсутствие засчитывается полностью', () {
      final clock = GameClock(now: () => at(3600 * 1000));
      final r = clock.since(600 * 1000); // прошло 50 минут
      expect(r.elapsed, const Duration(minutes: 50));
      expect(r.isMeaningful, isTrue);
    });

    // Потолок в 8 часов держал бак на возврате. Бака больше нет — за
    // отсутствие копится поток, и держит его копилка, а не часы.
    test('длинное отсутствие не обрезается', () {
      final clock = GameClock(now: () => at(100 * 3600 * 1000));
      final r = clock.since(1);
      expect(r.elapsed.inHours, 99);
      expect(r.rolledBack, isFalse);
    });

    test('перевод часов назад не даёт прогресса', () {
      final clock = GameClock(now: () => at(1000));
      final r = clock.since(900000); // метка «из будущего»
      expect(r.rolledBack, isTrue);
      expect(r.elapsed, Duration.zero);
    });

    test('короткая отлучка не показывает экран возвращения', () {
      final clock = GameClock(now: () => at(30 * 1000));
      expect(clock.since(1).isMeaningful, isFalse);
    });
  });

  group('SaveCodec', () {
    const codec = SaveCodec();

    test('сейв переживает круг кодирование → разбор', () {
      final raw = codec.encode({'litres': 12.5, 'gens': [1, 2, 3]});
      final result = codec.decode(raw);
      expect(result.isEmpty, isFalse);
      expect(result.data!['litres'], 12.5);
      expect(result.data!['version'], kSaveVersion);
      expect(result.wasCorrupt, isFalse);
    });

    test('пусто — это не ошибка, а новая игра', () {
      expect(codec.decode(null).isEmpty, isTrue);
      expect(codec.decode('').isEmpty, isTrue);
      expect(codec.decode(null).wasCorrupt, isFalse);
    });

    test('битый сейв не роняет игру', () {
      expect(codec.decode('{не json').wasCorrupt, isTrue);
      expect(codec.decode('[1,2,3]').wasCorrupt, isTrue);
      expect(codec.decode('{"нет":"версии"}').wasCorrupt, isTrue);
    });

    test('сейв из будущей версии не трогаем', () {
      const future = '{"version": ${kSaveVersion + 1}, "ml": 1}';
      final result = codec.decode(future);
      expect(result.isEmpty, isTrue, reason: 'эта версия его не понимает');
      // Не порча: испорченный заменяют новым гаражом, а этот цел и ждёт
      // новую версию (save_rescue_test.dart).
      expect(result.fromFuture, isTrue);
      expect(result.wasCorrupt, isFalse);
    });

    test('до выпуска сейв не мигрирует: версия одна', () {
      // Цепочка тестовых сборок (v1–v5) удалена при чистом старте. Сейв
      // текущей версии разбирается как есть.
      final result = codec.decode('{"version": 1, "ml": 5}');
      expect(result.wasCorrupt, isFalse);
      expect(result.wasMigrated, isFalse);
      expect(result.data!['ml'], 5);
    });
  });

  group('SaveService', () {
    test('сохранение и загрузка через хранилище', () async {
      final service = SaveService(storage: MemorySaveStorage());
      expect((await service.load()).isEmpty, isTrue);

      await service.save({'litres': 42.0});
      final loaded = await service.load();
      expect(loaded.data!['litres'], 42.0);

      await service.wipe();
      expect((await service.load()).isEmpty, isTrue);
    });

    test('сейв тестовой сборки не читается, а узнаётся', () async {
      final service =
          SaveService(storage: MemorySaveStorage(testSave: true));
      final loaded = await service.load();

      expect(loaded.isEmpty, isTrue, reason: 'гараж начинается заново');
      expect(loaded.fromTestVersion, isTrue,
          reason: 'игроку надо сказать, куда делся гараж');
      expect(loaded.wasCorrupt, isFalse,
          reason: 'это не порча, а решение: пугать «сейв повреждён» незачем');
    });

    test('свой сейв важнее тестового, и сообщение не повторяется', () async {
      final service =
          SaveService(storage: MemorySaveStorage(testSave: true));
      await service.save({'ml': 7.0});
      final loaded = await service.load();

      expect(loaded.fromTestVersion, isFalse);
      expect(loaded.data!['ml'], 7.0);
    });
  });
}
