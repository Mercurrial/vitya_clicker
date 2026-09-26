/// Факты сейва — то, что обязано пережить обновление.
///
/// Сейв — дерево: статистика и портал лежат блоками, купленное — списками.
/// Сравнивать его целиком нельзя: у новой версии ключей больше, а служебные
/// меняются при каждой записи. Поэтому дерево раскладывается на факты —
/// путь до листа и значение — и сверяется по ним.
///
/// Первая сверка эталона проверяла два ключа из двадцати — аппараты и
/// нагнанное. Сломай следующая версия чтение потока, статистики или
/// портала, договор с выпуском промолчал бы.
library;

import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';

/// Служебные ключи — не факты об игроке: версию сейва ставит кодек, версию
/// баланса и момент выхода — каждая запись заново.
const kServiceKeys = {'version', 'balanceVersion', 'lastSeen'};

/// Факты сейва: путь → значение. Служебных ключей среди них нет.
///
/// Путь — ключи через точку: `stats.playSec`, `portal.garage.at`,
/// `stills.banka`. Список в сейве — множество id (купленные улучшения,
/// цели), поэтому каждый id — свой факт: `bought[heat_1]`. Порядок фактом
/// не считается: сериализатор пишет список в порядке контента, а не покупок.
Map<String, Object?> saveFacts(Map<String, dynamic> save) {
  final facts = <String, Object?>{};
  void walk(String path, Object? value) {
    if (value is Map) {
      for (final MapEntry(:key, :value) in value.entries) {
        walk('$path.$key', value);
      }
    } else if (value is List) {
      for (final id in value) {
        facts['$path[$id]'] = true;
      }
    } else {
      facts[path] = value;
    }
  }

  for (final MapEntry(:key, :value) in save.entries) {
    if (!kServiceKeys.contains(key)) walk(key, value);
  }
  return facts;
}

/// Сейв [save], прочитанный текущей версией и записанный заново — то, что
/// от него останется у игрока после обновления.
Map<String, dynamic> reloaded(Map<String, dynamic> save, DateTime now) {
  const ser = GameSerializer();
  final state =
      ser.fromJson(save, content: kGenerators, upgrades: kUpgrades, now: now);
  return ser.toJson(state, lastSeenMillis: now.millisecondsSinceEpoch);
}

/// Факты [saved], которых нет в [loaded] или которые там другие. Строка на
/// факт — что было и что стало.
///
/// [allowed] — пути, которым загрузка вправе дать другое значение, с
/// причиной. Путь покрывает и всё, что под ним: `portal` — весь блок.
List<String> lostFacts(
  Map<String, dynamic> saved,
  Map<String, dynamic> loaded, {
  Map<String, String> allowed = const {},
}) {
  final after = saveFacts(loaded);
  return [
    for (final MapEntry(key: path, value: was) in saveFacts(saved).entries)
      if (!allowed.keys.any((a) => covers(a, path)) &&
          (!after.containsKey(path) || after[path] != was))
        after.containsKey(path)
            ? '$path: было $was, стало ${after[path]}'
            : '$path: было $was, пропал',
  ];
}

/// Путь [outer] — это [path] или блок, в котором он лежит.
bool covers(String outer, String path) =>
    path == outer || path.startsWith('$outer.') || path.startsWith('$outer[');
