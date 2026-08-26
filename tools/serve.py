#!/usr/bin/env python3
"""Локальный сервер для проверки сборки.

Обычный `python -m http.server` вместе с flutter_service_worker.js приводит к
тому, что браузер продолжает крутить старую версию игры даже после пересборки.
Мы уже потеряли на этом раунд обсуждения: код был новый, а на экране — старый.

Поэтому здесь всё отдаётся с запретом кэширования, а регистрация service
worker'а вырезается из index.html на лету. Обычного F5 достаточно.

    python tools/serve.py [порт]
"""

import functools
import http.server
import os
import re
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8770

_UNREGISTER_SW = """<script>
(function () {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.getRegistrations().then(function (regs) {
    var had = regs.length > 0;
    regs.forEach(function (r) { r.unregister(); });
    if (window.caches) {
      caches.keys().then(function (keys) { keys.forEach(function (k) { caches.delete(k); }); });
    }
    // Старый worker уже обслужил эту страницу — перезагружаемся начисто.
    if (had) location.reload();
  });
})();
</script>"""


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        # index.html правим на лету: без регистрации service worker'а браузер
        # физически не может показать вчерашнюю сборку.
        if self.path in ("/", "/index.html"):
            try:
                with open(os.path.join(ROOT, "index.html"), "rb") as f:
                    html = f.read().decode("utf-8")
            except OSError:
                self.send_error(404, "index.html not found — сначала flutter build web")
                return

            html = re.sub(r"serviceWorker\s*:\s*\{[^}]*\}", "serviceWorker: null", html)
            html = html.replace("flutter_service_worker.js", "")

            # Мало не регистрировать новый worker: тот, что браузер сохранил
            # раньше, продолжит перехватывать запросы и отдавать вчерашнюю
            # сборку. Поэтому при каждой загрузке сносим всё, что осталось.
            html = html.replace("<head>", "<head>\n" + _UNREGISTER_SW, 1)
            body = html.encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # Сам файл service worker'а не отдаём вовсе.
        if "flutter_service_worker.js" in self.path:
            self.send_error(404, "service worker отключён для локальной проверки")
            return

        super().do_GET()

    def log_message(self, fmt, *args):
        pass  # тишина: интересны только ошибки сборки, а не поток запросов


if __name__ == "__main__":
    if not os.path.isdir(ROOT):
        sys.exit("Нет build/web — сначала выполни: flutter build web")

    handler = functools.partial(NoCacheHandler, directory=ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), handler) as httpd:
        print(f"Витя гонит: http://localhost:{PORT}  (кэш отключён)")
        httpd.serve_forever()
