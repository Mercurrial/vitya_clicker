import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/achievements.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/ui/pixel/goal_icons.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/pixel/still_sprites.dart';

/// Спрайты аппаратов.
///
/// Спрайты генерируются (`tools/sprite_lab.py`), а значит ломаются тихо:
/// поправил функцию, забыл перегенерировать — или перегенерировал с ошибкой,
/// и на экране пустое место. Здесь проверяется то, что глазом замечают
/// последним.
void main() {
  group('Аппараты', () {
    test('у каждой ступени свой спрайт', () {
      // Прошлая версия отдавала семи старшим ступеням одну и ту же заглушку.
      final sprites = {for (final g in kGeneratorNames) g.id: stillSpriteFor(g.id)};
      final distinct = sprites.values.toSet();
      expect(distinct.length, kGeneratorNames.length,
          reason: 'две ступени делят один спрайт');
    });

    test('строки одной длины, символы — из палитры', () {
      for (final g in kGeneratorNames) {
        final s = stillSpriteFor(g.id);
        expect(s.rows.map((r) => r.length).toSet(), hasLength(1),
            reason: '${g.id}: строки разной длины — спрайт поедет');
        for (final row in s.rows) {
          for (final ch in row.split('')) {
            if (ch == '.') continue;
            expect(kStillPalette.containsKey(ch), isTrue,
                reason: '${g.id}: символ «$ch» не в палитре — будет дырой');
          }
        }
      }
    });

    test('аппарат стоит на полке, а не висит над ней', () {
      // У прошлых спрайтов внизу было по три пустых строки: огонь горел
      // отдельно, аппарат парил над полом.
      for (final g in kGeneratorNames) {
        final s = stillSpriteFor(g.id);
        expect(s.rows.last.replaceAll('.', ''), isNotEmpty, reason: g.id);
        expect(s.rows.first.replaceAll('.', ''), isNotEmpty,
            reason: '${g.id}: пустая верхняя строка съедает высоту сцены');
      }
    });

    test('лестница растёт: коллайдер больше банки', () {
      // Масштаб у всех общий, и рост дела читается по силуэтам. Если старшие
      // вдруг станут мельче младших, это перестанет работать.
      int area(String id) => stillSpriteFor(id).width * stillSpriteFor(id).height;
      expect(area('collider'), greaterThan(area('dedov')));
      expect(area('dedov'), greaterThan(area('banka')));
    });

    test('огонь и пар собраны из той же палитры', () {
      for (final frames in [kEmberFrames, kFlameFrames, kBlazeFrames, kSteamFrames, kHeavySteamFrames]) {
        for (final f in frames) {
          expect(f.rows.map((r) => r.length).toSet(), hasLength(1));
          for (final ch in f.rows.join().split('')) {
            if (ch == '.') continue;
            expect(kStillPalette.containsKey(ch), isTrue, reason: 'символ «$ch»');
          }
        }
      }
    });
  });

  group('Значки целей', () {
    test('у каждой цели свой значок, и все разные', () {
      // Прошлый набор раздавал девять значков на двадцать целей.
      for (final a in kAllAchievements) {
        expect(hasGoalIcon(a.id), isTrue, reason: '${a.id}: нет значка');
      }
      final icons = kAllAchievements.map((a) => goalIcon(a.id).rows.join('|')).toSet();
      expect(icons.length, kAllAchievements.length, reason: 'два значка одинаковые');
    });

    test('значки 16×16 и собраны из палитры аппаратов', () {
      for (final a in kAllAchievements) {
        final s = goalIcon(a.id);
        expect(s.width, 16, reason: a.id);
        expect(s.height, 16, reason: a.id);
        for (final ch in s.rows.join().split('')) {
          if (ch == '.') continue;
          expect(kStillPalette.containsKey(ch), isTrue, reason: '${a.id}: «$ch»');
        }
      }
    });
  });

  group('Размер клетки', () {
    test('шаг в полточки, спрайт помещается целиком', () {
      final banka = stillSpriteFor('banka');
      for (final box in [30.0, 46.0, 52.0, 80.0]) {
        final p = pixelToFit(banka, box);
        expect((p * 2) % 1, 0, reason: 'клетка $p не кратна половине точки');
        expect(banka.height * p, lessThanOrEqualTo(box));
      }
    });
  });
}
