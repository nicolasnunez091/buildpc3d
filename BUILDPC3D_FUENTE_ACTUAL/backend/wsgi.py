"""Entrada Gunicorn; no usar el servidor HTTP local en producción."""
from production import create_app

app = create_app()
