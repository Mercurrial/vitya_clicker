import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/app_info.dart';

/// Лицо игры за пределами Flutter: подпись под иконкой, заголовок окна,
/// превью ссылки, сами иконки.
///
/// Всё это живёт в файлах платформ — XML, plist, .rc, HTML, — куда
/// константу из Dart не подставить, и никакой другой тест туда не смотрит.
/// Так в окне Windows до переименования и висело «idle_game» из шаблона
/// Flutter, а иконка iOS была синим логотипом Flutter: править было нечего,
/// пока кто-то случайно не открыл сборку.
void main() {
  test('название одно на всех платформах', () {
    final html = _read('web/index.html');
    final manifest = jsonDecode(_read('web/manifest.json')) as Map<String, dynamic>;
    final ios = _read('ios/Runner/Info.plist');
    final macos = _read('macos/Runner/Info.plist');

    final places = {
      'вкладка браузера': _find(html, r'<title>([^<]*)</title>'),
      'ярлык на экране «Домой»': _find(html, r'apple-mobile-web-app-title" content="([^"]*)"'),
      'заголовок превью ссылки': _find(html, r'og:title" content="([^"]*)"'),
      'сайт в превью ссылки': _find(html, r'og:site_name" content="([^"]*)"'),
      'веб-приложение': manifest['name'] as String,
      'веб-приложение, коротко': manifest['short_name'] as String,
      'Android': _find(_read('android/app/src/main/AndroidManifest.xml'), r'android:label="([^"]*)"'),
      'iOS, под иконкой': _plist(ios, 'CFBundleDisplayName'),
      'iOS, в настройках': _plist(ios, 'CFBundleName'),
      'macOS, меню': _plist(macos, 'CFBundleName'),
      'Windows, окно': _unescape(_find(_read('windows/runner/main.cpp'), r'window\.Create\(L"([^"]*)"')),
      'Windows, свойства файла': _find(_read('windows/runner/Runner.rc'), r'"ProductName", "([^"]*)"'),
      'Linux, окно': _find(_read('linux/my_application.cc'), r'gtk_window_set_title\(window, "([^"]*)"'),
    };
    for (final MapEntry(key: place, value: name) in places.entries) {
      expect(name, kGameTitle, reason: place);
    }
  });

  test('превью ссылки ведёт на выложенную картинку', () {
    final html = _read('web/index.html');
    final url = _find(html, r'og:url" content="([^"]*)"');
    // Мессенджер читает страницу без <base>: путь к картинке — только полный,
    // и только на тот же сайт, иначе он молча покажет ссылку без картинки.
    expect(url, startsWith('https://'));
    expect(url, endsWith('/'));
    expect(_find(html, r'og:image" content="([^"]*)"'), '${url}og.png');

    final (width, height) = _pngSize('web/og.png');
    expect('$width', _find(html, r'og:image:width" content="([^"]*)"'));
    expect('$height', _find(html, r'og:image:height" content="([^"]*)"'));

    // В README ссылка «играть» — на тот же адрес: после переименования
    // репозитория правятся оба места, а не одно.
    expect(_read('README.md'), contains(url));
  });

  test('README показывает только существующие картинки', () {
    // Картинки в README лежат рядом с кодом и переименовываются вместе с
    // ним; GitHub на битую ссылку молча рисует пустую рамку.
    final readme = _read('README.md');
    final sources = [
      ...RegExp(r'<img src="([^"]+)"').allMatches(readme).map((m) => m[1]!),
      ...RegExp(r'!\[[^\]]*\]\(([^)\s]+)').allMatches(readme).map((m) => m[1]!),
    ].where((src) => !src.startsWith('http'));
    expect(sources, isNotEmpty);
    for (final src in sources) {
      expect(File(src).existsSync(), isTrue, reason: src);
    }
  });

  test('иконки iOS и macOS того размера, что заявлен Xcode', () {
    // Xcode не собирает набор, где размер файла не совпал с заявленным, —
    // а собрать для проверки здесь негде, Mac нет.
    for (final dir in [
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset',
    ]) {
      final contents = jsonDecode(_read('$dir/Contents.json')) as Map<String, dynamic>;
      for (final image in (contents['images'] as List).cast<Map<String, dynamic>>()) {
        final file = image['filename'] as String;
        final points = double.parse((image['size'] as String).split('x').first);
        final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
        final (width, height) = _pngSize('$dir/$file');
        final expected = (points * scale).round();
        expect((width, height), (expected, expected), reason: '$dir/$file');
      }
    }
  });

  test('адаптивная иконка Android собрана из существующих слоёв', () {
    final xml = _read('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
    final layers = RegExp(r'@mipmap/(\w+)').allMatches(xml).map((m) => m[1]!).toList();
    expect(layers, containsAll(['ic_launcher_background', 'ic_launcher_foreground']));
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final layer in layers) {
        final path = 'android/app/src/main/res/mipmap-$density/$layer.png';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _find(String text, String pattern) {
  final match = RegExp(pattern).firstMatch(text);
  expect(match, isNotNull, reason: 'не найдено: $pattern');
  return match![1]!;
}

String _plist(String plist, String key) => _find(plist, '<key>$key</key>\\s*<string>([^<]*)</string>');

/// `В` в строке C++ → «В». Кириллица в main.cpp записана кодами, см.
/// комментарий там.
String _unescape(String s) => s.replaceAllMapped(
    RegExp(r'\\u([0-9a-fA-F]{4})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));

/// Ширина и высота PNG — из заголовка IHDR, без декодирования картинки.
(int, int) _pngSize(String path) {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  return (bytes.getUint32(16), bytes.getUint32(20));
}
