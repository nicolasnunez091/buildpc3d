"""Servidor local real del backend con SOLO el proveedor Groq simulado.

Uso: python tests/backend_groq_fixture.py
Ocho solicitudes; no usa ni busca claves reales, no accede a Internet.
"""
import io
import json
import os
import sys
import urllib.error
from http.server import ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
import app  # noqa: E402

RESPONSES = {
    "Quiero un computador para diseño gráfico": "edicion",
    "Necesito una PC para jugar Valorant": "juegos",
    "Quiero una computadora para programar": "edicion",
    "Necesito editar videos y hacer renders": "edicion",
    "Busco algo económico para Word y Excel": "ofimatica",
    "Quiero jugar y editar videos": "edicion",
    "Quiero jugar con respuesta inválida": "respuesta_invalida",
}


def fake_groq(request, timeout):
    data = json.loads(request.data)
    assert timeout == 15 and data["response_format"]["type"] == "json_schema"
    text = data["messages"][-1]["content"]
    if text == "Quiero jugar con servicio desconectado":
        raise urllib.error.URLError("offline simulado")
    content = json.dumps({"uso": RESPONSES[text]})
    return io.BytesIO(json.dumps({"choices": [{"message": {"content": content}}]}).encode())


if __name__ == "__main__":
    os.environ["GROQ_API_KEY"] = "FAKE_TEST_KEY"
    os.environ["GROQ_MODEL"] = app.DEFAULT_MODEL
    os.environ.pop("GROQ_JSON_MODE", None)
    app.urllib.request.urlopen = fake_groq
    with ThreadingHTTPServer(("127.0.0.1", 18939), app.Handler) as server:
        server.timeout = 30
        print("Backend listo con proveedor simulado: 127.0.0.1:18939", flush=True)
        for _ in range(8):
            server.handle_request()
