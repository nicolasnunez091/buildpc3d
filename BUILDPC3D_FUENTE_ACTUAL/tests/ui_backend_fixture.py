"""Backend local con Groq simulado para probar ambos botones de la UI."""
import os
from http.server import ThreadingHTTPServer

from backend_groq_fixture import app, fake_groq

if __name__ == "__main__":
    os.environ["GROQ_API_KEY"] = "FAKE_TEST_KEY"
    os.environ["GROQ_MODEL"] = app.DEFAULT_MODEL
    os.environ.pop("GROQ_JSON_MODE", None)
    app.urllib.request.urlopen = fake_groq
    with ThreadingHTTPServer(("127.0.0.1", 18941), app.Handler) as server:
        server.timeout = 30
        print("UI backend listo; proveedor simulado", flush=True)
        for _ in range(2):
            server.handle_request()
