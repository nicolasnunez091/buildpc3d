import concurrent.futures
import os
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fakeredis
from redis.exceptions import ConnectionError as RedisConnectionError
from production import Quotas, create_app


class ProductionTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {"GROQ_ENABLED": "true", "GROQ_API_KEY": "fake"}, clear=True)
        self.env.start()
        self.redis = fakeredis.FakeRedis()
        self.quotas = Quotas(self.redis)
        self.app = create_app(quotas=self.quotas)
        self.client = self.app.test_client()

    def tearDown(self):
        self.env.stop()

    def post(self, client=None, **kwargs):
        kwargs.setdefault("json", {"texto": "render"})
        return (client or self.client).post("/interpretar", **kwargs)

    def test_public_success_without_credentials(self):
        with patch("production.classify", return_value={"uso": "edicion"}) as classifier:
            response = self.post()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"uso": "edicion", "fuente": "groq"})
        classifier.assert_called_once_with("render")
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_disabled_by_default_without_key_or_redis_access(self):
        with patch.dict(os.environ, {}, clear=True):
            app = create_app(quotas=self.quotas)
        self.redis.connection_pool.disconnect()
        with patch.object(self.quotas, "reserve", side_effect=AssertionError):
            self.assertEqual(app.test_client().post("/interpretar", json={"texto": "a"}).status_code, 503)

    def test_invalid_enable_flag_and_missing_key_fail_closed(self):
        with patch.dict(os.environ, {"GROQ_ENABLED": "invalid"}, clear=True), self.assertRaises(ValueError):
            create_app(quotas=self.quotas)
        with patch.dict(os.environ, {"GROQ_ENABLED": "true"}, clear=True), self.assertRaises(RuntimeError):
            create_app(quotas=self.quotas)

    def test_strict_input_and_size(self):
        bad_bodies = [
            b'{"texto":"a","texto":"b"}', b'{"texto":""}', b'{"texto":1}',
            b'{"texto":"a","extra":1}', b'[]', b'{', b'{"texto":"\\ud800"}',
        ]
        with patch("production.classify") as classifier:
            for body in bad_bodies:
                response = self.client.post("/interpretar", data=body, content_type="application/json")
                self.assertEqual(response.status_code, 400, body)
            self.assertEqual(self.post(json={"texto": "x" * 2001}).status_code, 400)
            self.assertEqual(self.client.post("/interpretar", data="x" * 9000, content_type="application/json").status_code, 413)
            self.assertEqual(self.client.post("/interpretar", data="{}", content_type="text/plain").status_code, 415)
            # Surrogates must not reach the classifier either.
            classifier.assert_not_called()

    def test_ip_hour_limit_and_separate_ip(self):
        with patch("production.classify", return_value={"uso": "edicion"}) as classifier:
            for _ in range(10):
                self.assertEqual(self.post().status_code, 200)
            self.assertEqual(self.post().status_code, 429)
            self.assertEqual(self.post(headers={"X-Forwarded-For": "198.51.100.9"}).status_code, 200)
            self.assertEqual(classifier.call_count, 11)

    def test_global_limit_across_ips(self):
        with patch.dict(os.environ, {"GLOBAL_PER_DAY": "3"}):
            app = create_app(quotas=Quotas(self.redis))
        with patch("production.classify", return_value={"uso": "juegos"}) as classifier:
            for i in range(4):
                response = app.test_client().post("/interpretar", json={"texto": "a"},
                    headers={"X-Forwarded-For": f"198.51.100.{i+1}"})
                self.assertEqual(response.status_code, 200 if i < 3 else 429)
            self.assertEqual(classifier.call_count, 3)

    def test_simultaneous_ip_quota_is_atomic(self):
        with patch.dict(os.environ, {"MAX_CONCURRENT": "30"}):
            app = create_app(quotas=Quotas(self.redis))
        barrier = threading.Barrier(20)
        def call(_):
            barrier.wait(timeout=10)
            return self.post(client=app.test_client()).status_code
        with patch("production.classify", return_value={"uso": "edicion"}):
            with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
                results = list(pool.map(call, range(20)))
        self.assertEqual(results.count(200), 10)
        self.assertEqual(results.count(429), 10)

    def test_default_global_100_per_day(self):
        with patch("production.classify", return_value={"uso": "juegos"}):
            for i in range(101):
                result = self.post(headers={"X-Forwarded-For": f"198.51.100.{i+1}"})
                self.assertEqual(result.status_code, 200 if i < 100 else 429)

    def test_atomic_simultaneous_limit(self):
        started = threading.Barrier(3)
        finish = threading.Event()
        def classify_wait(_):
            started.wait(timeout=5)
            if not finish.wait(10):
                raise RuntimeError()
            return {"uso": "edicion"}
        def call(ip):
            return self.post(client=self.app.test_client(),
                headers={"X-Forwarded-For": ip}).status_code
        with patch("production.classify", side_effect=classify_wait):
            with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
                one = pool.submit(call, "198.51.100.1")
                two = pool.submit(call, "198.51.100.2")
                try:
                    started.wait(timeout=5)
                    self.assertEqual(call("198.51.100.3"), 429)
                finally:
                    finish.set()
                self.assertEqual([one.result(), two.result()], [200, 200])
        self.assertEqual(self.redis.zcard("bpc:public:active"), 0)

    def test_orphaned_reservation_expires_and_denial_does_not_charge(self):
        self.quotas.concurrent = 1
        self.assertTrue(self.quotas.reserve("127.0.0.1", "first"))
        self.assertFalse(self.quotas.reserve("127.0.0.2", "denied"))
        self.redis.zadd("bpc:public:active", {"first": 1})
        self.assertTrue(self.quotas.reserve("127.0.0.2", "second"))
        self.quotas.release("second")

    def test_redis_failure_and_release_failure(self):
        with patch.object(self.quotas, "reserve", side_effect=RedisConnectionError()), \
                patch("production.classify") as classifier:
            self.assertEqual(self.post().status_code, 503)
            classifier.assert_not_called()
        with patch.object(self.quotas, "release", side_effect=RedisConnectionError()), \
                patch("production.classify", return_value={"uso": "edicion"}):
            self.assertEqual(self.post().status_code, 200)

    def test_provider_failure_releases_and_does_not_log_private_text(self):
        with patch("production.classify", side_effect=RuntimeError("SECRET")), \
                self.assertLogs("buildpc3d.production", level="ERROR") as logs:
            response = self.post(json={"texto": "PRIVATE_REQUEST"})
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("SECRET", str(logs.output))
        self.assertNotIn("PRIVATE_REQUEST", str(logs.output))
        self.assertEqual(self.redis.zcard("bpc:public:active"), 0)

    def test_proxy_fix_uses_nearest_value(self):
        with patch.object(self.quotas, "reserve", return_value=False) as reserve:
            self.post(headers={"X-Forwarded-For": "192.0.2.3, 198.51.100.2"})
        self.assertEqual(reserve.call_args.args[0], "198.51.100.2")


if __name__ == "__main__":
    unittest.main()
