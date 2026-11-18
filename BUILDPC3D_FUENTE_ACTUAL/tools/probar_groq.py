"""Comprobación manual opcional contra Groq real (puede consumir cuota).

Lee backend/.env en el equipo del usuario. Nunca imprime la clave.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
from app import ClassificationError, classify, load_env_file  # noqa: E402

if __name__ == "__main__":
    load_env_file()
    try:
        result = classify("Necesito una computadora para diseño gráfico y edición de video")
        print("Respuesta real de Groq:", result["uso"])
        sys.exit(0 if result["uso"] == "edicion" else 1)
    except ClassificationError as exc:
        print("No fue posible verificar Groq. Revisa la configuración privada, acceso al modelo y conexión.")
        print("Diagnóstico seguro:", exc.safe_diagnostic())
        sys.exit(1)
    except ValueError:
        print("No fue posible verificar Groq: solicitud de prueba no válida.")
        sys.exit(1)
