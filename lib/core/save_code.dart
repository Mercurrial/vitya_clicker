/// Перенос прогресса строкой.
///
/// ## Зачем
///
/// На iPhone игра живёт как сайт, добавленный на экран «Домой», и её сейв
/// лежит в хранилище Safari. Это рабочий способ поставить игру без Mac и без
/// переподписи каждые семь дней, но у него есть цена: хранилище браузера —
/// не сейф. Его можно потерять, очистив данные сайта, сменив телефон или
/// просто не заходя очень долго.
///
/// Поэтому прогресс должен уметь выезжать наружу. Код — это весь сейв,
/// свёрнутый в строку, которую можно отправить себе в мессенджер.
///
/// ## Почему именно так
///
/// **Base64, а не сжатие.** В вебе нет zlib из `dart:io`, а тащить пакет
/// ради пары килобайт незачем: сейв маленький.
///
/// **Контрольная сумма обязательна.** Код будут копировать из мессенджеров,
/// где строку легко обрезать или склеить с соседней. Без проверки битый код
/// молча превратился бы в испорченный прогресс — а это ровно та потеря, от
/// которой мы и защищаемся.
///
/// **Версия в начале.** Формат кода переживёт свои изменения так же, как их
/// переживает сейв: по номеру видно, чем разбирать.
library;

import 'dart:convert';

/// Что стоит в начале любого кода. По нему код узнаётся в куске текста.
const String kSaveCodePrefix = 'VITYA';

/// Версия формата кода. Меняется отдельно от версии сейва: сейв внутри кода
/// хранится как есть и приводится к текущей версии обычными миграциями.
const int kSaveCodeVersion = 1;

/// Чем разделены части. Точка выбрана намеренно: мессенджеры не превращают её
/// в перенос строки и не делают из кода ссылку.
const String _separator = '.';

/// Свернуть сейв в строку.
String encodeSaveCode(String rawSave) {
  final payload = base64Url.encode(utf8.encode(rawSave));
  final sum = _checksum(payload);
  return '$kSaveCodePrefix$kSaveCodeVersion$_separator$payload$_separator$sum';
}

/// Почему код не подошёл. Игроку нужно объяснение, а не «ошибка».
enum SaveCodeError {
  /// Пусто или вообще не похоже на код.
  notACode,

  /// Код от более новой версии игры.
  fromFuture,

  /// Контрольная сумма не сошлась: скорее всего, скопировали не целиком.
  damaged,
}

class SaveCodeResult {
  /// Исходная строка сейва — её можно класть в хранилище как есть.
  final String? save;
  final SaveCodeError? error;

  const SaveCodeResult.ok(this.save) : error = null;
  const SaveCodeResult.failed(this.error) : save = null;

  bool get isOk => save != null;

  /// Что показать игроку.
  String get message => switch (error) {
        null => 'Готово',
        SaveCodeError.notACode => 'Это не похоже на код прогресса',
        SaveCodeError.fromFuture => 'Код от более новой версии игры',
        SaveCodeError.damaged => 'Код скопирован не целиком',
      };
}

/// Развернуть строку обратно в сейв.
SaveCodeResult decodeSaveCode(String? code) {
  final trimmed = code?.trim().replaceAll(RegExp(r'\s'), '');
  if (trimmed == null || trimmed.isEmpty) {
    return const SaveCodeResult.failed(SaveCodeError.notACode);
  }
  if (!trimmed.startsWith(kSaveCodePrefix)) {
    return const SaveCodeResult.failed(SaveCodeError.notACode);
  }

  // Дальше строка уже начинается с нашего префикса. Значит, это НАШ код, и
  // любая его порча — это «скопировали не целиком», а не «это не код».
  // Разница не формальная: первое подсказывает игроку, что делать, второе
  // оставляет его в тупике.
  final parts = trimmed.split(_separator);
  if (parts.length != 3) {
    return const SaveCodeResult.failed(SaveCodeError.damaged);
  }

  final version = int.tryParse(parts[0].substring(kSaveCodePrefix.length));
  if (version == null) {
    return const SaveCodeResult.failed(SaveCodeError.damaged);
  }
  if (version > kSaveCodeVersion) {
    return const SaveCodeResult.failed(SaveCodeError.fromFuture);
  }

  final payload = parts[1];
  if (_checksum(payload) != parts[2]) {
    return const SaveCodeResult.failed(SaveCodeError.damaged);
  }

  try {
    final raw = utf8.decode(base64Url.decode(payload));
    // Сейв обязан быть объектом JSON. Если внутри что-то другое — код собран
    // не нами, и подсовывать это в хранилище нельзя.
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const SaveCodeResult.failed(SaveCodeError.damaged);
    }
    return SaveCodeResult.ok(raw);
  } catch (_) {
    return const SaveCodeResult.failed(SaveCodeError.damaged);
  }
}

/// Короткая контрольная сумма (CRC32, 8 шестнадцатеричных знаков).
///
/// Цель не криптографическая, а бытовая: поймать обрезанный или склеенный
/// код. От подделки она не защищает, да и незачем — игра однопользовательская.
String _checksum(String payload) {
  var crc = 0xFFFFFFFF;
  for (final byte in utf8.encode(payload)) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  crc = (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  return crc.toRadixString(16).padLeft(8, '0');
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});
