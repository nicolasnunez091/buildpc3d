"""Servidor Firestore REST simulado para pruebas del DAO, sin modificar Firebase."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "godot/data/catalog.json").read_text(encoding="utf-8"))["catalog"]
COLLECTIONS = {
    "procesadores": "cpu", "tarjetas_madre": "motherboard", "memorias_ram": "ram",
    "tarjetas_video": "gpu", "fuentes_poder": "psu", "chasis": "case",
}


def encode(value):
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [encode(item) for item in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {key: encode(item) for key, item in value.items()}}}
    return {"nullValue": None}


class Fixture(BaseHTTPRequestHandler):
    meta_requests = 0

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.strip("/")
        if path == "meta/catalog":
            Fixture.meta_requests += 1
            version = 1 if Fixture.meta_requests <= 2 else 2
            data = {"fields": {"version": encode(version)}}
        elif path in COLLECTIONS:
            rows = CATALOG[COLLECTIONS[path]]
            page = parse_qs(parsed.query).get("pageToken", [""])[0]
            if path == "procesadores":
                rows = rows[4:] if page else rows[:4]
            data = {"documents": [{"fields": {key: encode(value) for key, value in item.items()}} for item in rows]}
            if path == "procesadores" and not page:
                data["nextPageToken"] = "segunda"
        else:
            self.send_error(404)
            return
        payload = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    with HTTPServer(("127.0.0.1", 18938), Fixture) as server:
        server.timeout = 30
        print("Fixture Firestore listo: 127.0.0.1:18938", flush=True)
        for _ in range(10):
            server.handle_request()
