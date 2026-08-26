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
      expect(Fmt.short(1000), '1.00К');
      expect(Fmt.short(1500), '1.50К');
      expect(Fmt.short(2300000), '2.30М');
      expect(Fmt.short(4.2e9), '4.20Б');
      expect(Fmt.short(1e12), '1.00Т');
    });

    test('значащих цифр всегда три — ширина не скачет', () {
      expect(Fmt.short(9990), '9.99К');
      expect(Fmt.short(99900), '99.9К');
      expect(Fmt.short(999000), '999К');
    });

    test('крайние случаи не роняют игру', () {
      expect(Fmt.short(double.nan), '0');
      expect(Fmt.short(double.infinity), '∞');
      expect(Fmt.short(-1500), '-1.50К');
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
      expect(Fmt.volume(1000), '1.00 л');
      expect(Fmt.volume(1200), '1.20 л');
      expect(Fmt.volume(2500000), '2.50К л');
    });

    test('число и единица согласованы между собой', () {
      expect(Fmt.volumeNumber(850), '850');
      expect(Fmt.volumeUnit(850), 'мл');
      expect(Fmt.volumeNumber(1200), '1.20');
      expect(Fmt.volumeUnit(1200), 'л');
    });

    test('скорость получает суффикс', () {
      expect(Fmt.rate(120), '120 мл/с');
      expect(Fmt.rate(5000), '5.00 л/с');
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
      expect(clock.since(null).credited, Duration.zero);
      expect(clock.since(0).credited, Duration.zero);
    });

    test('обычное отсутствие засчитывается полностью', () {
      final clock = GameClock(now: () => at(3600 * 1000));
      final r = clock.since(600 * 1000); // прошло 50 минут
      expect(r.credited, const Duration(minutes: 50));
      expect(r.capped, isFalse);
      expect(r.isMeaningful, isTrue);
    });

    test('длинное отсутствие обрезается потолком', () {
      final clock = GameClock(now: () => at(100 * 3600 * 1000));
      final r = clock.since(0 + 1);
      expect(r.credited, GameClock.offlineCap);
      expect(r.capped, isTrue);
      expect(r.elapsed.inHours, greaterThan(GameClock.offlineCap.inHours));
    });

    test('перевод часов назад не даёт прогресса', () {
      final clock = GameClock(now: () => at(1000));
      final r = clock.since(900000); // метка «из будущего»
      expect(r.rolledBack, isTrue);
      expect(r.credited, Duration.zero);
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
      expect(codec.decode(future).wasCorrupt, isTrue);
    });

    test('старый сейв в литрах мигрирует в миллилитры', () {
      // v1 хранил объём в литрах — при переходе на мл всё умножается на 1000.
      const old = '{"version": 1, "litres": 2.5, "lifetime": 10, "wisdom": 3}';
      final result = codec.decode(old);

      expect(result.wasCorrupt, isFalse);
      expect(result.wasMigrated, isTrue);
      expect(result.data!['ml'], 2500);
      expect(result.data!['lifetime'], 10000);
      expect(result.data!['wisdom'], 3, reason: 'непричастные поля не трогаем');
      expect(result.data!.containsKey('litres'), isFalse);
      expect(result.data!['version'], kSaveVersion);
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
  });
}
