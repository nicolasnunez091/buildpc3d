"""Verifica por REST público y solo lectura el catálogo y su versión."""
import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

from seed_firestore import COLLECTIONS, read_catalog


def decode(value):
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return value["booleanValue"]
    if "nullValue" in value:
        return None
    if "arrayValue" in value:
        return [decode(item) for item in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return {key: decode(item) for key, item in value["mapValue"].get("fields", {}).items()}
    raise ValueError("Tipo de campo Firestore no admitido")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "BUILDPC3D/1.0"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)


def list_documents(base, collection):
    documents = {}
    token = ""
    seen_tokens = set()
    while True:
        url = base + collection + "?pageSize=100"
        if token:
            url += "&pageToken=" + urllib.parse.quote(token, safe="")
        page = fetch(url)
        for doc in page.get("documents", []):
            name = doc.get("name", "").rsplit("/", 1)[-1]
            if not name or name in documents:
                raise ValueError("Documento duplicado o sin identificador")
            documents[name] = {key: decode(value) for key, value in doc.get("fields", {}).items()}
        token = page.get("nextPageToken", "")
        if not token:
            return documents
        if token in seen_tokens or len(seen_tokens) >= 100:
            raise ValueError("Paginación remota inválida")
        seen_tokens.add(token)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project_id):
        parser.error("ID de proyecto no válido.")
    data = read_catalog()
    base = f"https://firestore.googleapis.com/v1/projects/{args.project_id}/databases/(default)/documents/"
    try:
        metadata = fetch(base + "meta/catalog")
        version = decode(metadata.get("fields", {}).get("version", {}))
        ok = version == data["version"]
        print("meta/catalog: versión", version, "OK" if ok else "DISTINTA")
        total = 0
        for category, collection in COLLECTIONS.items():
            actual = list_documents(base, collection)
            expected = {part["id"]: part for part in data["catalog"][category]}
            missing = set(expected) - set(actual)
            extra = set(actual) - set(expected)
            differing = [key for key in set(actual) & set(expected) if actual[key] != expected[key]]
            category_ok = not missing and not extra and not differing
            print(f"{collection}: {len(actual)} documentos, faltantes={len(missing)}, "
                  f"adicionales={len(extra)}, campos distintos={len(differing)} "
                  + ("OK" if category_ok else "DIFERENCIAS"))
            total += len(actual)
            ok = ok and category_ok
        print("Total remoto:", total, "| solo lectura")
        return 0 if ok and total == sum(len(parts) for parts in data["catalog"].values()) else 1
    except urllib.error.HTTPError as exc:
        print(f"No se pudo leer Firestore: HTTP {exc.code}. No se realizó ninguna escritura.", file=sys.stderr)
    except (urllib.error.URLError, OSError, ValueError, TypeError, KeyError):
        print("No se pudo verificar la respuesta de Firestore. No se realizó ninguna escritura.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
