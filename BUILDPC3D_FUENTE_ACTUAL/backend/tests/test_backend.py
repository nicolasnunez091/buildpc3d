import json
import os
import sys
import threading
import tempfile
import urllib.error
import urllib.request
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import ClassificationError, Handler, classify, load_env_file, parse_model_response  # noqa: E402
from http.server import ThreadingHTTPServer


class Response:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def fake_response(value):
    return Response(value)


class ClassifierTests(unittest.TestCase):
    def test_valid_response(self):
        self.assertEqual(parse_model_response('{"uso":"juegos"}'), {"uso": "juegos"})

    def test_usage_aliases_and_accents(self):
        for value, expected in [
            ("Gaming", "juegos"), ("EDICIÓN", "edicion"),
            ("diseño gráfico", "edicion"), ("programación", "edicion"),
            ("OFIMÁTICA", "ofimatica"), ("estudio", "ofimatica"),
        ]:
            with self.subTest(value=value):
                self.assertEqual(parse_model_response(json.dumps({"uso": value})), {"uso": expected})

    def test_invalid_usage(self):
        with self.assertRaises(ClassificationError):
            parse_model_response('{"uso":"xyz"}')

    def test_malformed_json(self):
        with self.assertRaises(ClassificationError):
            parse_model_response("no json")

    def test_empty_phrase(self):
        with self.assertRaises(ValueError):
            classify("")

    def test_long_phrase_rejected(self):
        with self.assertRaises(ValueError):
            classify("a" * 2001)

    def test_missing_api_key(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": ""}):
            with self.assertRaises(ClassificationError):
                classify("jugar juegos")

    def test_groq_json_structure(self):
        response = {"choices": [{"message": {"content": '{"uso":"edicion"}'}}]}
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY"}, clear=True):
            with patch("urllib.request.urlopen", return_value=fake_response(None)) as mock_open:
                with patch("json.load", return_value=response):
                    self.assertEqual(classify("edición de video"), {"uso": "edicion"})
                request = mock_open.call_args.args[0]
                payload = json.loads(request.data)
                self.assertEqual(payload["model"], "openai/gpt-oss-20b")
                schema = payload["response_format"]["json_schema"]
                self.assertTrue(schema["strict"])
                self.assertEqual(schema["schema"]["required"], ["uso"])
                self.assertEqual(schema["schema"]["properties"]["uso"]["enum"], ["juegos", "edicion", "ofimatica", "no_aplica"])
                self.assertEqual(request.get_header("Authorization"), "Bearer FAKE_TEST_KEY")
                self.assertEqual(request.get_header("User-agent"), "BUILDPC3D/1.0")

    def test_custom_model_can_use_json_object(self):
        response = {"choices": [{"message": {"content": '{"uso":"juegos"}'}}]}
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY", "GROQ_MODEL": "otro-modelo"}, clear=True):
            with patch("urllib.request.urlopen", return_value=fake_response(None)) as mock_open:
                with patch("json.load", return_value=response):
                    self.assertEqual(classify("jugar"), {"uso": "juegos"})
                self.assertEqual(json.loads(mock_open.call_args.args[0].data)["response_format"], {"type": "json_object"})

    def test_env_file_loads_without_overriding_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / ".env"
            file.write_text('# ejemplo\nGROQ_API_KEY="FAKE_FILE_KEY"\nGROQ_MODEL=modelo\nOTHER=ignored\n', encoding="utf-8")
            with patch.dict(os.environ, {"GROQ_MODEL": "precedencia"}, clear=True):
                load_env_file(file)
                self.assertEqual(os.environ["GROQ_API_KEY"], "FAKE_FILE_KEY")
                self.assertEqual(os.environ["GROQ_MODEL"], "precedencia")
                self.assertNotIn("OTHER", os.environ)

    def test_groq_connection_error(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY"}):
            with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("offline")):
                with self.assertRaises(ClassificationError):
                    classify("diseño")

    def test_http_error_has_safe_diagnostic_without_provider_content(self):
        error = urllib.error.HTTPError("https://example.invalid/FAKE_SECRET", 403, "FAKE_SECRET", {}, None)
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY"}):
            with patch("urllib.request.urlopen", side_effect=error):
                with self.assertRaises(ClassificationError) as caught:
                    classify("diseño")
        self.assertEqual(caught.exception.safe_diagnostic(), "http_proveedor (HTTP 403)")
        self.assertNotIn("FAKE_SECRET", caught.exception.safe_diagnostic())

    def test_groq_incomplete_response(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY"}):
            with patch("urllib.request.urlopen", return_value=fake_response(None)):
                with patch("json.load", return_value={"choices": []}):
                    with self.assertRaises(ClassificationError):
                        classify("render")

    def test_groq_invalid_json(self):
        response = {"choices": [{"message": {"content": "not json"}}]}
        with patch.dict(os.environ, {"GROQ_API_KEY": "FAKE_TEST_KEY"}):
            with patch("urllib.request.urlopen", return_value=fake_response(None)):
                with patch("json.load", return_value=response):
                    with self.assertRaises(ClassificationError):
                        classify("videojuegos")


class HTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)

    def test_health(self):
        with urllib.request.urlopen(self.base + "/health", timeout=2) as res:
            self.assertEqual(res.status, 200)
            self.assertEqual(json.load(res)["status"], "ok")

    def test_request_missing_key_fallback(self):
        req = urllib.request.Request(
            self.base + "/interpretar",
            data=b'{"texto":"me gusta jugar videojuegos"}',
            headers={"Content-Type": "application/json"}, method="POST",
        )
        with patch.dict(os.environ, {"GROQ_API_KEY": ""}):
            with self.assertRaises(urllib.error.HTTPError) as err:
                urllib.request.urlopen(req, timeout=2)
            self.assertEqual(err.exception.code, 503)
            self.assertTrue(json.loads(err.exception.read())["seleccion_manual"])
            err.exception.close()

    def test_http_success_identifies_groq(self):
        req = urllib.request.Request(
            self.base + "/interpretar", data=json.dumps({"texto": "diseño"}).encode("utf-8"),
            headers={"Content-Type": "application/json"}, method="POST",
        )
        with patch("app.classify", return_value={"uso": "edicion"}):
            with self.assertLogs("buildpc3d.backend", level="INFO") as logs:
                with urllib.request.urlopen(req, timeout=2) as res:
                    self.assertEqual(json.load(res), {"uso": "edicion", "fuente": "groq"})
            output = " ".join(logs.output)
            self.assertIn("HTTP 200: fuente=groq", output)
            self.assertNotIn("diseño", output)
            self.assertNotIn("Authorization", output)

    def test_invalid_json_returns_400(self):
        req = urllib.request.Request(self.base + "/interpretar", data=b"{bad", method="POST")
        with self.assertRaises(urllib.error.HTTPError) as err:
            urllib.request.urlopen(req, timeout=2)
        self.assertEqual(err.exception.code, 400)
        err.exception.close()

    def test_provider_error_does_not_leak_secret(self):
        req = urllib.request.Request(
            self.base + "/interpretar", data=b'{"texto":"jugar"}', method="POST",
        )
        with patch("app.classify", side_effect=ClassificationError("FAKE_SECRET_SHOULD_NOT_APPEAR")):
            with self.assertLogs("buildpc3d.backend", level="WARNING") as logs:
                with self.assertRaises(urllib.error.HTTPError) as err:
                    urllib.request.urlopen(req, timeout=2)
            self.assertNotIn(b"FAKE_SECRET_SHOULD_NOT_APPEAR", err.exception.read())
            err.exception.close()
            self.assertNotIn("FAKE_SECRET_SHOULD_NOT_APPEAR", str(logs.output))


if __name__ == "__main__":
    unittest.main()
