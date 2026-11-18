extends Node
class_name CatalogDAO

signal catalogo_cargado(catalogo: Dictionary, origen: String)
signal error_catalogo(mensaje: String)

const LOCAL_FILE = "res://data/catalog.json"
const SSD_FILE = "res://data/ssd_extension.json"
const COMPONENTS_FILE = "res://data/components_extension.json"
const CACHE_FILE = "user://catalog_cache.json"
const COLLECTIONS = {
    "cpu": "procesadores", "motherboard": "tarjetas_madre", "ram": "memorias_ram",
    "gpu": "tarjetas_video", "psu": "fuentes_poder", "case": "chasis"
}
const TYPES = ["cpu", "motherboard", "ram", "gpu", "psu", "case"]

var _catalog: Dictionary = {}
var _version: int = -1
var _origin: String = "demo"
var _project_id: String = ""
var _catalog_document: String = "catalog"
var _http: HTTPRequest
var _step: String = ""
var _collection_index: int = 0
var _page_token: String = ""
var _remote_catalog: Dictionary = {}
var _incoming_version: int = 0
var _cache_path: String = CACHE_FILE

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 10.0
    add_child(_http)
    _http.request_completed.connect(_on_http_completed)
    _load_settings()

func _load_settings() -> void:
    if not FileAccess.file_exists("res://config/app_config.json"):
        return
    var settings = _parse_json(FileAccess.get_file_as_string("res://config/app_config.json"))
    if typeof(settings) != TYPE_DICTIONARY:
        return
    _project_id = str(settings.get("firebase_project_id", "")).strip_edges()
    _catalog_document = str(settings.get("catalog_document", "catalog"))

func obtener_catalogo() -> Dictionary:
    if _catalog.is_empty():
        _load_local_catalog()
    call_deferred("_notify_loaded")
    if not _project_id.is_empty():
        call_deferred("actualizar_si_cambia_version")
    return _catalog.duplicate(true)

func _notify_loaded() -> void:
    catalogo_cargado.emit(_catalog.duplicate(true), _origin)

func _load_local_catalog() -> void:
    var local_data = _parse_json(FileAccess.get_file_as_string(LOCAL_FILE))
    var data = local_data
    if FileAccess.file_exists(_cache_path):
        var cached = _parse_json(FileAccess.get_file_as_string(_cache_path))
        if typeof(cached) == TYPE_DICTIONARY and typeof(local_data) == TYPE_DICTIONARY \
                and not _project_id.is_empty() and str(cached.get("project_id", "")) == _project_id \
                and _catalog_is_valid(cached.get("catalog", {})):
            if int(cached.get("version", -1)) >= int(local_data.get("version", 0)):
                data = cached
    if typeof(data) != TYPE_DICTIONARY or not _catalog_is_valid(data.get("catalog", {})):
        error_catalogo.emit("No fue posible abrir el catálogo local.")
        return
    var combined = _with_local_extensions(data.get("catalog", {}))
    # Un caché migrado o conflictivo no debe impedir el respaldo integrado.
    if combined.is_empty() and data != local_data:
        data = local_data
        combined = _with_local_extensions(data.get("catalog", {}))
    if combined.is_empty():
        error_catalogo.emit("Las extensiones locales o el catálogo no son válidos.")
        return
    _catalog = combined
    _version = int(data.get("version", 0))
    _origin = str(data.get("source", "demo"))

func actualizar_si_cambia_version() -> void:
    if _project_id.is_empty() or _step != "":
        return
    _step = "meta"
    var url = _document_url("meta/" + _catalog_document)
    _request(url)

func _document_url(part: String) -> String:
    return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [_project_id, part]

func _request(url: String) -> void:
    var err = _http.request(url)
    if err != OK:
        _fail("No se pudo conectar a Firebase (código " + str(err) + ").")

func _on_http_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
        _fail("Firebase no respondió correctamente; se usa el catálogo local. HTTP " + str(status))
        return
    var data = _parse_json(body.get_string_from_utf8())
    if typeof(data) != TYPE_DICTIONARY:
        _fail("Firebase devolvió datos no válidos.")
        return
    if _step == "meta":
        var fields = data.get("fields", {})
        if typeof(fields) != TYPE_DICTIONARY or typeof(fields.get("version")) != TYPE_DICTIONARY:
            _fail("Falta la versión del catálogo remoto.")
            return
        _incoming_version = int(_decode_value(fields.get("version", {})))
        if _incoming_version < 1:
            _fail("Versión del catálogo remoto no válida.")
            return
        if _origin == "firebase" and _incoming_version == _version:
            _step = ""
            return
        _remote_catalog.clear()
        for category in TYPES:
            _remote_catalog[category] = []
        _collection_index = 0
        _page_token = ""
        _step = "collection"
        _download_collection_page()
    elif _step == "collection":
        var category = TYPES[_collection_index]
        var documents = data.get("documents", [])
        if typeof(documents) != TYPE_ARRAY:
            _fail("La colección remota no es válida.")
            return
        for doc in documents:
            if typeof(doc) != TYPE_DICTIONARY:
                _fail("Un documento remoto no es válido.")
                return
            var decoded = _decode_document(doc, category)
            if decoded.is_empty():
                _fail("Un documento remoto está incompleto.")
                return
            _remote_catalog[category].append(decoded)
        var next_page = str(data.get("nextPageToken", ""))
        if not next_page.is_empty():
            _page_token = next_page
            _download_collection_page()
            return
        _collection_index += 1
        _page_token = ""
        if _collection_index < TYPES.size():
            _download_collection_page()
        else:
            _finish_download()

func _download_collection_page() -> void:
    var category = TYPES[_collection_index]
    var url = _document_url(COLLECTIONS[category]) + "?pageSize=100"
    if not _page_token.is_empty():
        url += "&pageToken=" + _page_token.uri_encode()
    _request(url)

func _decode_document(doc: Dictionary, category: String) -> Dictionary:
    var fields = doc.get("fields", {})
    if typeof(fields) != TYPE_DICTIONARY or fields.is_empty():
        return {}
    var result: Dictionary = {}
    for field_name in fields:
        if typeof(fields[field_name]) != TYPE_DICTIONARY:
            return {}
        result[field_name] = _decode_value(fields[field_name])
    if not result.has("id"):
        result["id"] = str(doc.get("name", "")).get_file()
    result["type"] = category
    return result

func _decode_value(value: Dictionary):
    if value.has("stringValue"): return str(value["stringValue"])
    if value.has("integerValue"): return int(value["integerValue"])
    if value.has("doubleValue"): return float(value["doubleValue"])
    if value.has("booleanValue"): return bool(value["booleanValue"])
    if value.has("arrayValue"):
        var values: Array = []
        for value_item in value["arrayValue"].get("values", []):
            values.append(_decode_value(value_item))
        return values
    if value.has("mapValue"):
        var mapped: Dictionary = {}
        for field in value["mapValue"].get("fields", {}):
            mapped[field] = _decode_value(value["mapValue"]["fields"][field])
        return mapped
    return null

func _finish_download() -> void:
    _step = ""
    if not _catalog_is_valid(_remote_catalog):
        error_catalogo.emit("El catálogo remoto está incompleto. Se conserva el catálogo local.")
        return
    var combined = _with_local_extensions(_remote_catalog)
    if combined.is_empty():
        error_catalogo.emit("Las extensiones locales tienen datos inválidos o IDs en conflicto.")
        return
    _catalog = combined
    _version = _incoming_version
    _origin = "firebase"
    var save_data = {"source": "firebase", "project_id": _project_id, "version": _version, "catalog": _remote_catalog}
    var file = FileAccess.open(_cache_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(save_data))
    catalogo_cargado.emit(_catalog.duplicate(true), _origin)

func _with_local_ssd(base: Dictionary) -> Dictionary:
    var extension = _parse_json(FileAccess.get_file_as_string(SSD_FILE))
    if typeof(extension) != TYPE_DICTIONARY or typeof(extension.get("ssd")) != TYPE_ARRAY:
        return {}
    var result = base.duplicate(true)
    var ids = {}
    for category in TYPES:
        for part in result.get(category, []):
            ids[str(part.get("id", ""))] = true
    result["ssd"] = []
    for part in extension["ssd"]:
        if typeof(part) != TYPE_DICTIONARY or str(part.get("id", "")).is_empty() \
                or ids.has(str(part.get("id", ""))) or part.get("type") != "ssd" \
                or int(part.get("price_cop", 0)) <= 0 or int(part.get("capacity_gb", 0)) <= 0 \
                or str(part.get("name", "")).is_empty() \
                or [part.get("interface"), part.get("form_factor")] not in [["sata", "2.5"], ["nvme_pcie", "m2_2280"]]:
            return {}
        ids[str(part["id"])] = true
        result["ssd"].append(part.duplicate(true))
    return result if not result["ssd"].is_empty() else {}

func _with_local_extensions(base: Dictionary) -> Dictionary:
    var combined = _with_local_ssd(base)
    if combined.is_empty():
        return {}
    var extension = _parse_json(FileAccess.get_file_as_string(COMPONENTS_FILE))
    return _merge_components_extension(combined, extension)

func _merge_components_extension(base: Dictionary, extension) -> Dictionary:
    if typeof(extension) != TYPE_DICTIONARY or int(extension.get("schema_version", 0)) != 1 \
            or typeof(extension.get("catalog")) != TYPE_DICTIONARY:
        return {}
    var result = base.duplicate(true)
    var ids = {}
    for category in TYPES + ["ssd"]:
        for part in result.get(category, []):
            var id = str(part.get("id", ""))
            if id.is_empty() or ids.has(id):
                return {}
            ids[id] = {"category": category, "part": part}
    for category in extension["catalog"]:
        if category not in TYPES or typeof(extension["catalog"][category]) != TYPE_ARRAY:
            return {}
        for part in extension["catalog"][category]:
            if typeof(part) != TYPE_DICTIONARY:
                return {}
            var id = str(part.get("id", ""))
            if id.is_empty() or str(part.get("type", "")) != category:
                return {}
            if ids.has(id):
                # Migración futura: solo deduplicar registros idénticos.
                if ids[id]["category"] != category or ids[id]["part"] != part:
                    return {}
                continue
            ids[id] = {"category": category, "part": part}
            result[category].append(part.duplicate(true))
    return result if _catalog_is_valid(result) else {}

func _catalog_is_valid(data) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    var ids = {}
    for category in TYPES:
        var parts = data.get(category)
        if typeof(parts) != TYPE_ARRAY or parts.is_empty():
            return false
        for part in parts:
            if typeof(part) != TYPE_DICTIONARY or str(part.get("id", "")).is_empty() \
                    or str(part.get("name", "")).is_empty() or int(part.get("price_cop", 0)) <= 0:
                return false
            if ids.has(part["id"]) or str(part.get("type", category)) != category:
                return false
            ids[part["id"]] = true
            match category:
                "cpu":
                    if str(part.get("socket", "")).is_empty() or int(part.get("cores", 0)) <= 0 \
                            or int(part.get("tdp_w", 0)) <= 0 or typeof(part.get("ram_types")) != TYPE_ARRAY \
                            or part["ram_types"].is_empty():
                        return false
                "motherboard":
                    if str(part.get("socket", "")).is_empty() or str(part.get("ram_type", "")).is_empty() \
                            or str(part.get("form_factor", "")).is_empty() or int(part.get("power_w", 0)) <= 0:
                        return false
                "ram":
                    if str(part.get("ram_type", "")).is_empty() or int(part.get("capacity_gb", 0)) <= 0 \
                            or int(part.get("power_w", 0)) <= 0:
                        return false
                "gpu":
                    if int(part.get("length_mm", 0)) <= 0 or int(part.get("vram_gb", 0)) <= 0 \
                            or int(part.get("tdp_w", 0)) <= 0:
                        return false
                "psu":
                    if int(part.get("watts", 0)) <= 0:
                        return false
                "case":
                    if int(part.get("max_gpu_mm", 0)) <= 0 or typeof(part.get("form_factors")) != TYPE_ARRAY \
                            or part["form_factors"].is_empty():
                        return false
    return true

func _fail(message: String) -> void:
    _step = ""
    error_catalogo.emit(message)

func _parse_json(text: String):
    var parser = JSON.new()
    return parser.data if parser.parse(text) == OK else null

func version_catalogo() -> int:
    return _version
