"""API WSGI pública, sin autenticación; no carga archivos .env."""
import hashlib
import ipaddress
import json
import logging
import os
import secrets

from flask import Flask, jsonify, request
from redis import Redis
from redis.exceptions import RedisError
from werkzeug.exceptions import RequestEntityTooLarge
from werkzeug.middleware.proxy_fix import ProxyFix

from app import ClassificationError, classify

LOGGER = logging.getLogger("buildpc3d.production")

# Todo ocurre atómicamente en Redis, incluso entre procesos Gunicorn.
# El reloj de Redis determina el día UTC; los rechazos no consumen cuota.
_RESERVE_SCRIPT = """
local now = tonumber(redis.call('TIME')[1])
local daily_key = 'bpc:public:day:' .. math.floor(now / 86400)
redis.call('ZREMRANGEBYSCORE', KEYS[2], '-inf', now)
if tonumber(redis.call('GET', KEYS[1]) or '0') >= tonumber(ARGV[1]) then return 0 end
if tonumber(redis.call('GET', daily_key) or '0') >= tonumber(ARGV[2]) then return 0 end
if redis.call('ZCARD', KEYS[2]) >= tonumber(ARGV[3]) then return 0 end
local ip_count = redis.call('INCR', KEYS[1])
if ip_count == 1 then redis.call('EXPIRE', KEYS[1], 3600) end
local global_count = redis.call('INCR', daily_key)
if global_count == 1 then redis.call('EXPIRE', daily_key, 86400 - (now % 86400)) end
redis.call('ZADD', KEYS[2], now + tonumber(ARGV[4]), ARGV[5])
redis.call('EXPIRE', KEYS[2], tonumber(ARGV[4]) + 10)
return 1
"""
_RELEASE_SCRIPT = "return redis.call('ZREM', KEYS[1], ARGV[1])"


def _positive_env(name, default):
    value = int(os.environ.get(name, str(default)))
    if value <= 0:
        raise ValueError(f"{name} debe ser positivo")
    return value


def _enabled_env():
    value = os.environ.get("GROQ_ENABLED", "false").strip().lower()
    if value not in ("true", "false"):
        raise ValueError("GROQ_ENABLED debe ser true o false")
    return value == "true"


class Quotas:
    def __init__(self, redis_client):
        self.client = redis_client
        self.ip_hour = _positive_env("IP_PER_HOUR", 10)
        self.daily = _positive_env("GLOBAL_PER_DAY", 100)
        self.concurrent = _positive_env("MAX_CONCURRENT", 2)
        # Recupera reservas huérfanas; no es un plazo total de la llamada.
        self.lease_seconds = 120

    def reserve(self, ip, lease):
        ip_hash = hashlib.sha256(ip.encode("utf-8")).hexdigest()
        return self.client.eval(
            _RESERVE_SCRIPT, 2, "bpc:public:ip:" + ip_hash, "bpc:public:active",
            self.ip_hour, self.daily, self.concurrent, self.lease_seconds, lease,
        ) == 1

    def release(self, lease):
        self.client.eval(_RELEASE_SCRIPT, 1, "bpc:public:active", lease)


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Campo duplicado")
        result[key] = value
    return result


def create_app(quotas=None):
    enabled = _enabled_env()
    if enabled and not os.environ.get("GROQ_API_KEY", "").strip():
        raise RuntimeError("Falta GROQ_API_KEY")
    if quotas is None:
        redis_url = os.environ.get("REDIS_URL", "").strip()
        if not redis_url:
            raise RuntimeError("Falta REDIS_URL")
        quotas = Quotas(Redis.from_url(redis_url, socket_connect_timeout=2, socket_timeout=2))

    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 8192
    # Solo detrás del nginx suministrado que sustituye X-Forwarded-For.
    # Gunicorn debe escuchar únicamente en su socket Unix privado.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1)

    def error(code, text):
        return jsonify(error=text), code

    @app.after_request
    def no_store(response):
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(RequestEntityTooLarge)
    def too_large(_exc):
        return error(413, "Solicitud demasiado grande")

    @app.post("/interpretar")
    def interpret():
        if not enabled:
            return error(503, "Servicio temporalmente desactivado")
        try:
            ip = str(ipaddress.ip_address(request.remote_addr or ""))
        except ValueError:
            return error(400, "Origen no válido")
        if request.mimetype != "application/json":
            return error(415, "Se requiere JSON")
        try:
            raw = request.get_data(cache=False)
            data = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object)
        except (ValueError, UnicodeDecodeError):
            return error(400, "Solicitud no válida")
        if not isinstance(data, dict) or set(data) != {"texto"}:
            return error(400, "Solicitud no válida")
        text = data["texto"]
        if not isinstance(text, str) or not text.strip() or len(text) > 2000:
            return error(400, "Solicitud no válida")
        try:
            text.encode("utf-8")
        except UnicodeEncodeError:
            return error(400, "Solicitud no válida")
        lease = secrets.token_hex(16)
        try:
            if not quotas.reserve(ip, lease):
                return error(429, "Límite de solicitudes")
        except RedisError:
            LOGGER.warning("Cuotas no disponibles")
            return error(503, "Servicio temporalmente no disponible")
        try:
            return jsonify(**classify(text), fuente="groq")
        except (ClassificationError, ValueError):
            LOGGER.warning("Proveedor no disponible o respuesta inválida")
            return error(503, "Servicio temporalmente no disponible")
        except Exception:
            LOGGER.error("Error interno de clasificación")
            return error(503, "Servicio temporalmente no disponible")
        finally:
            try:
                quotas.release(lease)
            except RedisError:
                LOGGER.warning("No se pudo liberar una reserva de concurrencia")

    return app
