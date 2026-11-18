"""Prueba manual Godot + HTTP simulado; no accede a Groq."""
import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

counts = {"ok": 0, "badhealth": 0, "failpost": 0}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        route = self.path.split("/")[1]
        self.reply(503 if route == "badhealth" else 200, {"status": "ok"})

    def do_POST(self):
        route = self.path.split("/")[1]
        counts[route] += 1
        self.rfile.read(int(self.headers["Content-Length"]))
        self.reply(503 if route == "failpost" else 200, {"uso": "edicion", "fuente": "groq"})


def main():
    root = Path(__file__).resolve().parents[1]
    exe = os.environ["GODOT_CONSOLE"]
    server = ThreadingHTTPServer(("127.0.0.1", 18949), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        result = subprocess.run([exe, "--headless", "--path", str(root / "godot"),
                                 "--script", "res://tests/android_warmup.gd"], timeout=45)
        assert result.returncode == 0
        assert counts == {"ok": 1, "badhealth": 0, "failpost": 1}, counts
        print("OK: exactamente un POST tras health y ninguno si health falla")
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    main()
