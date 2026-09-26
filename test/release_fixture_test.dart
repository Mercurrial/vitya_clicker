import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';

import '../tools/make_fixture.dart' show fixtureSave;
import 'support/save_facts.dart';

/// Эталон выпуска несёт все факты.
///
/// Эталон снимается один раз, при выпуске, и после этого не правится никогда
/// (release_contract_test.dart). Что в него не легло, того следующие версии
/// не проверят: лежи в эталоне нулевой поток — сломанное чтение потока
/// читало бы тот же ноль, и договор промолчал бы. Дописать эталон после
/// выпуска уже нельзя.
///
/// Поэтому то, что выпуск запишет, проверяется заранее и всегда: сейв из
/// tools/make_fixture.dart, строкой, как ляжет в файл. Появится новый ключ
/// сейва — тест скажет довести до него партию, пока это ещё можно.
void main() {
  // Собирается в первом же тесте, а не при загрузке файла: разошедшаяся с
  // балансом партия должна упасть тестом со своей причиной.
  late final save = const SaveCodec().decode(fixtureSave()).data!;

  // Загрузка — позже любого момента партии: иначе «начало захода»,
  // которое без ключа читается как момент загрузки, могло бы совпасть.
  final now = DateTime.utc(2027, 3, 1);

  test('в эталоне лежит каждый ключ, который читает загрузка', () {
    // Ключи, которые пишутся не всегда (портал, наивысшая ступень, самый
    // быстрый заход), по одной записи не найти: партия без коллайдера
    // портала не пишет. Поэтому список ключей берётся у загрузки — она
    // спрашивает каждый, есть он или нет.
    final asked = _keysAskedOnLoad(save, now);
    final missing = [
      for (final path in asked)
        if (!_hasFact(save, path)) path,
    ];

    // Статистика пишется всегда и лежит блоком: не видит её ключей — опрос
    // не заглядывает внутрь блоков, и пропуски в портале он бы не заметил.
    expect(asked, contains('stats.playSec'),
        reason: 'опрос ключей загрузки сломан: во вложенные блоки он не '
            'заглядывает');
    expect(missing, isEmpty,
        reason: 'загрузка читает эти ключи, а в эталоне их нет или они '
            'пусты. Доведи партию в tools/make_fixture.dart до них, пока '
            'эталон не снят');
  });

  test('каждый факт отличается от того, что загрузка возьмёт без него', () {
    // Не по умолчанию — значит, не совпадает с тем, что загрузка прочитает,
    // не найдя ключа. Совпадает — сломанное чтение этого ключа договор не
    // заметит: ноль в эталоне и ноль от забытого ключа неотличимы.
    final facts = saveFacts(save);
    final weak = [
      for (final MapEntry(key: path, value: value) in facts.entries)
        if (saveFacts(reloaded(_withoutFact(save, path), now))[path] == value)
          '$path = $value',
    ];

    expect(facts, isNotEmpty);
    expect(weak, isEmpty,
        reason: 'эти факты эталона совпадают с тем, что загрузка возьмёт без '
            'них. Партия в tools/make_fixture.dart должна дать им другие '
            'значения');
  });

  test('читается текущей версией без потерь', () {
    // То же, что договор проверит на снятом эталоне, — заранее: иначе
    // первая сверка случилась бы в день выпуска.
    expect(lostFacts(save, reloaded(save, now)), isEmpty);
  });

  test('состояние живое: производство идёт', () {
    final state = const GameSerializer()
        .fromJson(save, content: kGenerators, upgrades: kUpgrades, now: now);
    expect(state.mlPerSecond, greaterThan(0));
    expect(state.prestige.wisdom, greaterThan(0));
  });
}

/// Какие ключи спрашивает загрузка у сейва [save] — путями, как в
/// [saveFacts], включая блоки (`portal`, `portal.garage`).
Set<String> _keysAskedOnLoad(Map<String, dynamic> save, DateTime now) {
  final asked = <String>{};
  const GameSerializer().fromJson(
    _Asked(save, '', asked),
    content: kGenerators,
    upgrades: kUpgrades,
    now: now,
  );
  return asked;
}

/// Сейв, который записывает, о каких ключах его спросили. Вложенный блок
/// отдаёт таким же — так видны и ключи статистики, и ключи снимка портала.
class _Asked extends MapBase<String, dynamic> {
  _Asked(this._inner, this._path, this._asked);

  final Map<String, dynamic> _inner;
  final String _path;
  final Set<String> _asked;

  String _at(Object? key) => _path.isEmpty ? '$key' : '$_path.$key';

  @override
  dynamic operator [](Object? key) {
    _asked.add(_at(key));
    final value = _inner[key];
    return value is Map<String, dynamic> ? _Asked(value, _at(key), _asked) : value;
  }

  @override
  bool containsKey(Object? key) {
    _asked.add(_at(key));
    return _inner.containsKey(key);
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('загрузка не пишет в сейв');

  @override
  dynamic remove(Object? key) =>
      throw UnsupportedError('загрузка не пишет в сейв');

  @override
  void clear() => throw UnsupportedError('загрузка не пишет в сейв');
}

/// Лежит ли в сейве [path] — и не пустым блоком: пустой список купленного
/// так же ничего не проверяет, как отсутствующий.
bool _hasFact(Map<String, dynamic> save, String path) {
  Object? node = save;
  for (final key in path.split('.')) {
    if (node is! Map || !node.containsKey(key)) return false;
    node = node[key];
  }
  return switch (node) {
    null => false,
    Map(isEmpty: true) || List(isEmpty: true) => false,
    _ => true,
  };
}

/// Сейв без одного факта — будто версия, которая его записала, о нём не
/// знала.
Map<String, dynamic> _withoutFact(Map<String, dynamic> save, String path) {
  final copy = jsonDecode(jsonEncode(save)) as Map<String, dynamic>;
  final item = RegExp(r'^(.*)\[(.*)\]$').firstMatch(path);
  final keys = (item?.group(1) ?? path).split('.');

  Object? node = copy;
  for (final key in keys.take(keys.length - 1)) {
    node = (node as Map)[key];
  }
  final last = keys.last;
  if (item != null) {
    ((node as Map)[last] as List).remove(item.group(2));
  } else {
    (node as Map).remove(last);
  }
  return copy;
}
