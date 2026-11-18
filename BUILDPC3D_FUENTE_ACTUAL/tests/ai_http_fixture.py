"""Servidor efímero para probar el cliente HTTP real de Godot sin clave Groq.

Uso: python tests/ai_http_fixture.py
Sale después de cuatro solicitudes; solo escucha en localhost.
"""
import json
import socket
import sys
from http.server import ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
import app


class Fixture(app.Handler):
    def do_POST(self):
        if self.path == "/good":
            # Recorre el Handler real y su serialización; solo Groq se simula.
            self.path = "/interpretar"
            return super().do_POST()
        if self.path == "/invalid":
            payload = b"not json"
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path == "/error":
            return self.respond(503, {"error": "simulated"})
        if self.path == "/disconnect":
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()


def fake_classify(text):
    if text != "Quiero un PC para diseño":
        raise ValueError("Texto inesperado en JSON")
    return {"uso": "edicion"}


if __name__ == "__main__":
    app.classify = fake_classify
    with ThreadingHTTPServer(("127.0.0.1", 18937), Fixture) as server:
        server.timeout = 30
        print("Fixture HTTP listo: 127.0.0.1:18937", flush=True)
        for _ in range(4):
            server.handle_request()
