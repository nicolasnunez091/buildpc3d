"""Servicio de clasificación BuildPC3D: POST /interpretar -> {"uso": ...}.

Solo este proceso conoce GROQ_API_KEY. Usa HTTP local en desarrollo; en
producción debe publicarse detrás de HTTPS mediante un reverse proxy.
"""
import json
import logging
import os
import unicodedata
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VALID_USES = frozenset({"juegos", "edicion", "ofimatica"})
GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
USER_AGENT = "BUILDPC3D/1.0"
DEFAULT_MODEL = "openai/gpt-oss-20b"
STRICT_MODELS = frozenset({"openai/gpt-oss-20b", "openai/gpt-oss-120b"})
ENV_FILE = Path(__file__).resolve().parent / ".env"
LOGGER = logging.getLogger("buildpc3d.backend")
USE_ALIASES = {
    "juegos": "juegos", "juego": "juegos", "gaming": "juegos",
    "gamer": "juegos", "videojuegos": "juegos",
    "edicion": "edicion", "editar": "edicion", "render": "edicion",
    "renderizado": "edicion", "desarrollo": "edicion", "programacion": "edicion",
    "diseno": "edicion", "diseno grafico": "edicion",
    "ofimatica": "ofimatica", "oficina": "ofimatica", "office": "ofimatica",
    "estudio": "ofimatica", "estudiar": "ofimatica",
}


class ClassificationError(Exception):
    """Error con diagnóstico limitado: nunca incorpora datos del proveedor."""

    SAFE_CATEGORIES = frozenset({
        "sin_clave", "http_proveedor", "red", "tiempo_agotado",
        "respuesta_invalida", "proveedor_no_disponible",
    })

    def __init__(self, message, category="proveedor_no_disponible", http_status=None):
        super().__init__(message)
        self.category = category if category in self.SAFE_CATEGORIES else "proveedor_no_disponible"
        self.http_status = http_status if isinstance(http_status, int) and 100 <= http_status <= 599 else None

    def safe_diagnostic(self):
        return self.category + (f" (HTTP {self.http_status})" if self.http_status is not None else "")


def load_env_file(path=ENV_FILE):
    """Lee solo ajustes conocidos, sin ejecutar código ni sobrescribir el entorno.

    El archivo es opcional y se carga una vez al arrancar el proceso; no se
    imprimen valores ni se expone su contenido en las respuestas.
    """
    path = Path(path)
    if not path.exists():
        return
    allowed = {"GROQ_API_KEY", "GROQ_MODEL", "GROQ_JSON_MODE", "HOST", "PORT"}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if key not in allowed:
            continue
        if len(value) >= 2 and value[0] in ("'", '"') and value[-1] == value[0]:
            value = value[1:-1]
        os.environ.setdefault(key, value)


def parse_model_response(content):
    """Rechaza categorías ajenas y JSON inesperado en lugar de inventar usos."""
    try:
        result = json.loads(content)
    except (TypeError, ValueError) as exc:
        raise ClassificationError("La IA devolvió JSON inválido", "respuesta_invalida") from exc
    if not isinstance(result, dict):
        raise ClassificationError("La IA no devolvió un objeto", "respuesta_invalida")
    use = result.get("uso")
    if not isinstance(use, str):
        raise ClassificationError("Falta el campo uso", "respuesta_invalida")
    use = "".join(c for c in unicodedata.normalize("NFKD", use.lower().strip())
                  if not unicodedata.combining(c))
    use = USE_ALIASES.get(" ".join(use.split()), "")
    if use not in VALID_USES:
        raise ClassificationError("Uso no reconocido", "respuesta_invalida")
    return {"uso": use}


def classify(text):
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Debes enviar una frase no vacía")
    if len(text) > 2000:
        raise ValueError("La frase es demasiado larga")
    api_key = os.environ.get("GROQ_API_KEY", "").strip()
    if not api_key:
        raise ClassificationError("Groq no está configurado; usa selección manual", "sin_clave")
    model = os.environ.get("GROQ_MODEL", "").strip() or DEFAULT_MODEL
    mode = os.environ.get("GROQ_JSON_MODE", "").strip().lower()
    use_schema = mode == "schema" or (not mode and model in STRICT_MODELS)
    response_format = {"type": "json_object"}
    if use_schema:
        response_format = {"type": "json_schema", "json_schema": {
            "name": "perfil_buildpc3d", "strict": True,
            "schema": {
                "type": "object", "additionalProperties": False,
                "properties": {"uso": {"type": "string", "enum": ["juegos", "edicion", "ofimatica"]}},
                "required": ["uso"],
            },
        }}
    body = {
        "model": model,
        "temperature": 0,
        "max_completion_tokens": 1024,
        "response_format": response_format,
        "messages": [
            {"role": "system", "content": (
                "Eres un clasificador para configurar computadores. Responde SOLO "
                "con un JSON válido con la clave 'uso' cuyo valor debe ser exactamente "
                "uno de: juegos, edicion, ofimatica. "
                "juegos: gaming y videojuegos; edicion: video, animación, "
                "fotografía, diseño, programación y desarrollo de software; "
                "ofimatica: oficina, estudio, "
                "navegación y tareas básicas. Si hay usos mezclados, prioriza "
                "edicion, luego juegos, luego ofimatica. No añadas texto extra."
            )},
            {"role": "user", "content": text.strip()},
        ],
    }
    req = urllib.request.Request(
        GROQ_ENDPOINT,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            groq_response = json.load(response)
    except urllib.error.HTTPError as exc:
        raise ClassificationError("Groq rechazó la solicitud", "http_proveedor", exc.code) from None
    except TimeoutError:
        raise ClassificationError("Se agotó el tiempo de respuesta", "tiempo_agotado") from None
    except (urllib.error.URLError, OSError):
        raise ClassificationError("No se pudo conectar con Groq", "red") from None
    except ValueError:
        raise ClassificationError("Groq devolvió datos inválidos", "respuesta_invalida") from None
    try:
        content = groq_response["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ClassificationError("Respuesta de Groq incompleta", "respuesta_invalida") from exc
    return parse_model_response(content)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, _format, *args):
        # No registrar texto, cabeceras, URL ni datos de respuestas del proveedor.
        return

    def respond(self, code, data):
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/health":
            self.respond(200, {"status": "ok", "groq_configurado": bool(os.environ.get("GROQ_API_KEY"))})
        else:
            self.respond(404, {"error": "Ruta no encontrada"})

    def do_POST(self):
        if self.path != "/interpretar":
            self.respond(404, {"error": "Ruta no encontrada"})
            return
        LOGGER.info("POST /interpretar recibido")
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size < 1 or size > 8192:
                self.respond(400, {"error": "Cuerpo vacío o demasiado grande"})
                LOGGER.info("POST /interpretar HTTP 400: solicitud no válida")
                return
            params = json.loads(self.rfile.read(size))
            if not isinstance(params, dict):
                raise ValueError("Se esperaba un objeto JSON")
            result = classify(params.get("texto", ""))
            self.respond(200, {**result, "fuente": "groq"})
            LOGGER.info("POST /interpretar HTTP 200: fuente=groq")
        except (ValueError, json.JSONDecodeError):
            self.respond(400, {"error": "Solicitud no válida", "seleccion_manual": True})
            LOGGER.info("POST /interpretar HTTP 400: solicitud no válida")
        except ClassificationError as exc:
            LOGGER.warning("POST /interpretar HTTP 503: %s", exc.safe_diagnostic())
            self.respond(503, {"error": "Servicio temporalmente no disponible", "seleccion_manual": True})


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    load_env_file()
    port = int(os.environ.get("PORT", "8000"))
    host = os.environ.get("HOST", "127.0.0.1")
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"BUILDPC3D - IA escuchando en {host}:{port}")
    server.serve_forever()
