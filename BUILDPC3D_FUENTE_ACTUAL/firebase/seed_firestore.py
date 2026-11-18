"""Vista previa y carga inicial segura del catálogo en Firestore.

Sin --apply solo muestra el plan y no usa credenciales ni accede a Firebase.
Con --apply crea los documentos y la versión en una única operación atómica;
si alguno ya existe, la operación falla sin sobrescribirlo.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_FILE = ROOT / "godot" / "data" / "catalog.json"
COLLECTIONS = {
    "cpu": "procesadores", "motherboard": "tarjetas_madre", "ram": "memorias_ram",
    "gpu": "tarjetas_video", "psu": "fuentes_poder", "case": "chasis",
}
REQUIRED = {
    "cpu": ("socket", "ram_types", "cores", "tdp_w"),
    "motherboard": ("socket", "ram_type", "form_factor", "power_w"),
    "ram": ("ram_type", "capacity_gb", "power_w"),
    "gpu": ("length_mm", "vram_gb", "tdp_w"),
    "psu": ("watts",),
    "case": ("max_gpu_mm", "form_factors"),
}
NUMERIC = {"cores", "tdp_w", "power_w", "capacity_gb", "length_mm", "vram_gb", "watts", "max_gpu_mm"}
ARRAYS = {"ram_types", "form_factors"}
READ_TIMEOUT_SECONDS = 30
COMMIT_TIMEOUT_SECONDS = 90
MAX_COMMIT_ATTEMPTS = 3


def read_catalog(path=CATALOG_FILE):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or type(data.get("version")) is not int or data["version"] < 1:
        raise ValueError("El catálogo debe tener una versión entera positiva.")
    catalog = data.get("catalog")
    if not isinstance(catalog, dict) or set(catalog) != set(COLLECTIONS):
        raise ValueError("El catálogo debe contener exactamente las seis categorías esperadas.")
    ids = set()
    for category, parts in catalog.items():
        if not isinstance(parts, list) or not parts:
            raise ValueError(f"Categoría vacía o inválida: {category}")
        for part in parts:
            if not isinstance(part, dict):
                raise ValueError(f"Componente inválido en {category}")
            part_id = part.get("id")
            if not isinstance(part_id, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,150}", part_id) or part_id in ids:
                raise ValueError(f"ID inválido o duplicado en {category}")
            ids.add(part_id)
            if part.get("type") != category or not isinstance(part.get("name"), str) or not part["name"].strip():
                raise ValueError(f"Tipo o nombre inválido: {part_id}")
            if type(part.get("price_cop")) not in (int, float) or part["price_cop"] <= 0:
                raise ValueError(f"Precio inválido: {part_id}")
            for key in REQUIRED[category]:
                value = part.get(key)
                if key in NUMERIC:
                    valid = type(value) in (int, float) and value > 0
                elif key in ARRAYS:
                    valid = isinstance(value, list) and bool(value) and all(isinstance(x, str) and x.strip() for x in value)
                else:
                    valid = isinstance(value, str) and bool(value.strip())
                if not valid:
                    raise ValueError(f"Campo técnico incompleto ({key}): {part_id}")
    return data


def plan_digest(project_id, data):
    payload = json.dumps({"project_id": project_id, "database": "(default)", "data": data},
                         sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def show_plan(project_id, data):
    print(f"Proyecto: {project_id} | Base de datos: (default)")
    print(f"Versión: {data['version']} | Operación: crear sin sobrescribir; no elimina documentos")
    total = 0
    for category, collection in COLLECTIONS.items():
        parts = data["catalog"][category]
        print(f"\n{collection}: {len(parts)} documentos")
        for part in parts:
            print(f"  {collection}/{part['id']}")
            total += 1
    print(f"\nmeta/catalog: 1 documento con campo version={data['version']}")
    print(f"Total: {total} componentes + 1 versión = {total + 1} documentos.")
    print("Huella SHA-256 del plan:", plan_digest(project_id, data))
    return total


def check_credentials_outside_project(path):
    if path and Path(path).expanduser().resolve().is_relative_to(ROOT.resolve()):
        raise ValueError("La credencial administrativa debe estar fuera de la carpeta del proyecto.")


class SafeLoadError(Exception):
    """Fallo controlado sin datos privados ni respuestas del proveedor."""


def planned_documents(database, data):
    documents = []
    for category, collection in COLLECTIONS.items():
        for part in data["catalog"][category]:
            documents.append((database.collection(collection).document(part["id"]), part))
    documents.append((database.collection("meta").document("catalog"), {"version": data["version"]}))
    return documents


def read_plan_state(database, documents):
    """Lee todos los documentos; nunca interpreta una lectura incompleta como vacío."""
    expected = {reference.path: fields for reference, fields in documents}
    if len(expected) != len(documents):
        raise SafeLoadError("El plan contiene rutas duplicadas.")
    try:
        snapshots = list(database.get_all([reference for reference, _ in documents],
                                          retry=None, timeout=READ_TIMEOUT_SECONDS))
        found = {}
        for snapshot in snapshots:
            path = snapshot.reference.path
            if path not in expected or path in found:
                raise SafeLoadError("La lectura administrativa contiene rutas inesperadas.")
            found[path] = snapshot
        if set(found) != set(expected):
            raise SafeLoadError("La lectura administrativa está incompleta; no se escribirá.")
        present = [snapshot for snapshot in found.values() if snapshot.exists]
        if not present:
            return "empty"
        if len(present) == len(expected) and all(
                snapshot.to_dict() == expected[path] for path, snapshot in found.items()):
            return "matching"
        return "conflict"
    except SafeLoadError:
        raise
    except Exception as exc:
        raise SafeLoadError(
            f"No se pudo completar la lectura administrativa ({type(exc).__name__}); no se reintentará la escritura."
        ) from None


def apply_atomic_create(database, data, retryable_errors, max_attempts=MAX_COMMIT_ATTEMPTS,
                        pause=time.sleep):
    """Crea el plan completo o se detiene; reconcilia antes de cada reintento."""
    if max_attempts < 1 or max_attempts > MAX_COMMIT_ATTEMPTS:
        raise SafeLoadError("Cantidad de intentos fuera del límite permitido.")
    documents = planned_documents(database, data)
    state = read_plan_state(database, documents)
    if state == "matching":
        print("Los documentos ya existen y coinciden con el plan; no se escribe.")
        return "already_present"
    if state != "empty":
        raise SafeLoadError("Hay documentos existentes o distintos; no se escribirá ni sobrescribirá.")
    print(f"Lectura administrativa: {len(documents)} documentos ausentes.")
    for attempt in range(1, max_attempts + 1):
        batch = database.batch()
        for reference, fields in documents:
            batch.create(reference, fields)
        try:
            # Sin reintentos automáticos del SDK: cada resultado incierto debe
            # reconciliarse leyendo los 43 documentos antes de volver a enviar.
            batch.commit(retry=None, timeout=COMMIT_TIMEOUT_SECONDS)
        except Exception as exc:
            error_type = type(exc).__name__
            print(f"Intento {attempt}: resultado no confirmado ({error_type}); comprobando documentos.")
            state = read_plan_state(database, documents)
            if state == "matching":
                print("Los 43 documentos coinciden; no se vuelve a escribir.")
                return "reconciled"
            if state != "empty":
                raise SafeLoadError("Hay documentos presentes o diferentes; se detiene la operación.") from None
            if not isinstance(exc, retryable_errors) or attempt == max_attempts:
                raise SafeLoadError(f"Carga no confirmada ({error_type}); no se volverá a intentar.") from None
            print("Todos siguen ausentes; se realizará un reintento limitado.")
            pause(float(attempt))
            continue
        state = read_plan_state(database, documents)
        if state != "matching":
            raise SafeLoadError("El servidor confirmó el lote, pero la verificación no coincide; no se repetirá.")
        print("Lote confirmado y 43 documentos verificados.")
        return "created"
    raise SafeLoadError("Se agotaron los intentos permitidos.")


def create_catalog(project_id, data, credential_path=None):
    check_credentials_outside_project(credential_path)
    if not credential_path:
        check_credentials_outside_project(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"))
    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.api_core import exceptions as google_exceptions

    credential = credentials.Certificate(credential_path) if credential_path else credentials.ApplicationDefault()
    app = firebase_admin.initialize_app(credential, {"projectId": project_id})
    try:
        database = firestore.client(app=app)
        if database.project != project_id:
            raise SafeLoadError("El proyecto de la conexión no coincide con el destino confirmado.")
        return apply_atomic_create(
            database, data,
            retryable_errors=(google_exceptions.DeadlineExceeded, google_exceptions.ServiceUnavailable,
                              google_exceptions.InternalServerError, google_exceptions.Aborted),
        )
    finally:
        firebase_admin.delete_app(app)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", required=True, help="ID exacto del proyecto Firebase")
    parser.add_argument("--credentials", help="JSON de cuenta de servicio fuera del proyecto; opcional si hay ADC")
    parser.add_argument("--apply", action="store_true", help="Ejecutar la carga real; sin esta opción solo se muestra el plan")
    parser.add_argument("--confirm-project", help="Repetir el ID para confirmar el destino de una carga real")
    parser.add_argument("--confirm-plan", help="Huella SHA-256 mostrada en la vista previa aprobada")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project_id):
        parser.error("ID de proyecto no válido.")
    if args.apply and args.confirm_project != args.project_id:
        parser.error("Para escribir, --confirm-project debe coincidir con --project-id.")
    if args.apply and not args.confirm_plan:
        parser.error("Para escribir, copia la huella de la vista previa en --confirm-plan.")
    if not args.apply and (args.confirm_project or args.confirm_plan):
        parser.error("Las confirmaciones solo se usan junto con --apply.")
    try:
        data = read_catalog()
        total = show_plan(args.project_id, data)
        if total + 1 > 500:
            raise ValueError("El plan excede el límite de seguridad de 500 escrituras por lote.")
        if not args.apply:
            print("\nVista previa solamente: no se ha conectado ni escrito en Firebase.")
            return 0
        if args.confirm_plan != plan_digest(args.project_id, data):
            raise ValueError("La huella del plan cambió; revisa y autoriza una nueva vista previa.")
        create_catalog(args.project_id, data, args.credentials)
        print("\nEstado del catálogo comprobado. Ejecuta la verificación pública de solo lectura.")
        return 0
    except ImportError:
        print("Falta firebase-admin. Instálalo antes de la carga real.", file=sys.stderr)
    except SafeLoadError as exc:
        print(str(exc), file=sys.stderr)
    except (ValueError, OSError):
        # No imprimir excepciones que pudieran contener rutas o credenciales.
        print("No se pudo validar el plan o leer la credencial. "
              "Comprueba el catálogo, la huella y que la credencial esté fuera del proyecto.", file=sys.stderr)
    except Exception as exc:
        print(f"No se pudo confirmar la carga ({type(exc).__name__}). "
              "Antes de reintentar, comprueba si los documentos existen; no se mostraron secretos.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
