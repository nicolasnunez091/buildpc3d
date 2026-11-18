extends Node
class_name PCController

signal ia_resuelta(ok: bool, mensaje: String, uso: String)

const FilterScript = preload("res://scripts/model/UseFilter.gd")
const RecommenderScript = preload("res://scripts/model/Recommender.gd")
const DemandAnalyzerScript = preload("res://scripts/model/DemandAnalyzer.gd")

const KEYWORDS = {
    "juegos": ["juego", "juegos", "jugar", "gaming", "gamer", "videojuego", "videojuegos", "valorant", "fortnite", "minecraft", "warzone", "gta", "steam", "counter strike", "fifa", "e sports", "roblox", "god of war"],
    "edicion": ["editar", "edicion", "render", "renderizar", "renderizado", "blender", "premiere", "photoshop", "autocad", "animacion", "modelado", "diseno", "disenar", "disenador", "disenadora", "video", "videos", "programar", "programacion", "programador", "programadora", "codigo", "compilar", "desarrollo", "software", "ingenieria", "after effects", "android studio", "emuladores"],
    "ofimatica": ["oficina", "ofimatica", "office", "word", "excel", "powerpoint", "estudio", "estudios", "estudiar", "estudiante", "clases", "documentos", "navegar", "navegacion", "correo", "internet", "tareas", "contabilidad", "teletrabajo", "universidad"]
}

var _filter = FilterScript.new()
var _recommender = RecommenderScript.new()
var _catalog: Dictionary = {}
var _equipment: Dictionary = {}
var _current_use: String = "juegos"
var _last_text: String = ""
var _busy: bool = false
var _http: HTTPRequest
var _last_source: String = ""
var _health_http: HTTPRequest
var _post_url: String = ""
var _equipment_demand: Dictionary = {}
var _equipment_use: String = ""
var _remote_details: Dictionary = {}

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 18.0
    _http.max_redirects = 0
    add_child(_http)
    _http.request_completed.connect(_on_ai_completed)
    _health_http = HTTPRequest.new()
    _health_http.timeout = 90.0
    _health_http.max_redirects = 0
    add_child(_health_http)
    _health_http.request_completed.connect(_on_health_completed)

func establecer_catalogo(catalog: Dictionary) -> void:
    _catalog = catalog.duplicate(true)

func _normalize(value: String) -> String:
    var s = value.to_lower().strip_edges()
    for a in ["á", "à", "ä"]:
        s = s.replace(a, "a")
    for a in ["é", "è", "ë"]:
        s = s.replace(a, "e")
    for a in ["í", "ì", "ï"]:
        s = s.replace(a, "i")
    for a in ["ó", "ò", "ö"]:
        s = s.replace(a, "o")
    for a in ["ú", "ù", "ü"]:
        s = s.replace(a, "u")
    s = s.replace("ñ", "n")
    for char in [".", ",", ";", ":", "!", "¡", "?", "¿", "(", ")", "/", "-", "_", "\n", "\t"]:
        s = s.replace(char, " ")
    return " ".join(s.split(" ", false))

func _normalize_use(value: String) -> String:
    var s = _normalize(value)
    if s in ["juegos", "juego", "gaming", "gamer", "videojuegos"]: return "juegos"
    if s in ["edicion", "editar", "render", "renderizado", "desarrollo", "programacion", "diseno", "diseno grafico"]: return "edicion"
    if s in ["ofimatica", "oficina", "office", "estudio", "estudiar"]: return "ofimatica"
    return ""

func establecer_uso_manual(uso: String) -> bool:
    var value = _normalize_use(uso)
    if not _filter.uso_valido(value):
        return false
    _current_use = value
    return true

func procesar_respuesta_ia(response: Dictionary) -> bool:
    return typeof(response.get("uso")) == TYPE_STRING and establecer_uso_manual(response["uso"])

func clasificar_texto_local(texto: String) -> String:
    var normalized = " " + _normalize(texto) + " "
    # Misma prioridad que el servicio Groq para solicitudes mixtas.
    for profile in ["edicion", "juegos", "ofimatica"]:
        for keyword in KEYWORDS[profile]:
            if normalized.contains(" " + keyword + " "):
                return profile
    return ""

func _profile_message(profile: String) -> String:
    var names = {"juegos": "Juegos", "edicion": "Diseño / Edición", "ofimatica": "Ofimática"}
    return "Perfil recomendado: " + str(names.get(profile, profile))

func _local_fallback(reason: String) -> void:
    # Solo códigos internos: nunca registrar la petición, URL, cabeceras o cuerpo.
    var allowed = ["url_ausente", "url_no_permitida", "inicio_http", "respuesta_http", "json_invalido", "perfil_invalido", "health_no_disponible"]
    var safe_reason = reason if reason in allowed else "desconocido"
    var profile = clasificar_texto_local(_last_text)
    if not profile.is_empty() and establecer_uso_manual(profile):
        _last_source = "local"
        print("BUILDPC3D IA: fuente=local; motivo=", safe_reason, "; perfil=", profile)
        ia_resuelta.emit(true, _profile_message(profile) + " · Interpretación local (IA remota no disponible).", profile)
    else:
        _last_source = "ninguno"
        print("BUILDPC3D IA: fuente=ninguno; motivo=", safe_reason)
        ia_resuelta.emit(false, "No identificamos el uso. Elige una categoría manualmente para continuar.", "")

func _http_result_name(result: int) -> String:
    match result:
        HTTPRequest.RESULT_SUCCESS: return "correcto"
        HTTPRequest.RESULT_CANT_CONNECT: return "no_conecta"
        HTTPRequest.RESULT_CANT_RESOLVE: return "no_resuelve"
        HTTPRequest.RESULT_CONNECTION_ERROR: return "conexion_interrumpida"
        HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "error_tls"
        HTTPRequest.RESULT_TIMEOUT: return "tiempo_agotado"
        _: return "otro_error"

func solicitar_uso(text_input: String, service_url: String, warm_up: bool = false) -> void:
    if _busy:
        ia_resuelta.emit(false, "Estamos analizando tu petición. Espera un momento.", "")
        return
    _last_text = text_input.strip_edges()
    if _last_text.is_empty():
        ia_resuelta.emit(false, "Escribe una petición antes de interpretarla.", "")
        return
    if DemandAnalyzerScript.new().analyze(_last_text)["portatil"]:
        ia_resuelta.emit(false, "BUILDPC3D configura computadores de escritorio, no portátiles.", "")
        return
    if _last_text.length() > 2000:
        ia_resuelta.emit(false, "La petición supera los 2000 caracteres.", "")
        return
    _last_source = ""
    _remote_details.clear()
    var url = service_url.strip_edges()
    if url.is_empty():
        _local_fallback("url_ausente")
        return
    if not url.begins_with("https://"):
        var host_port = url.trim_prefix("http://").get_slice("/", 0)
        var fields = host_port.split(":")
        var local_development = url.begins_with("http://") and not OS.has_feature("android") \
            and fields.size() == 2 and fields[0] in ["127.0.0.1", "localhost"] \
            and fields[1].is_valid_int() and int(fields[1]) > 0 and int(fields[1]) <= 65535
        if not local_development:
            _local_fallback("url_no_permitida")
            return
    _post_url = url
    if warm_up:
        if not url.ends_with("/interpretar"):
            _local_fallback("url_no_permitida")
            return
        var health_url = url.trim_suffix("/interpretar") + "/health"
        var health_err = _health_http.request(health_url)
        if health_err != OK:
            _local_fallback("health_no_disponible")
            return
        _busy = true
        print("BUILDPC3D IA: esperando disponibilidad del servidor.")
        return
    _start_post()

func _start_post() -> void:
    var err = _http.request(_post_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"texto": _last_text}))
    if err != OK:
        _busy = false
        print("BUILDPC3D IA: no se pudo iniciar HTTP; código=", err)
        _local_fallback("inicio_http")
        return
    _busy = true
    print("BUILDPC3D IA: solicitud HTTP iniciada.")

func _on_health_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var response = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
    if typeof(response) != TYPE_DICTIONARY or response.get("status") != "ok":
        _busy = false
        _local_fallback("health_no_disponible")
        return
    _start_post()

func _on_ai_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _busy = false
    print("BUILDPC3D IA: resultado=", _http_result_name(result), "; código_resultado=", result, "; HTTP=", code)
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        _local_fallback("respuesta_http")
        return
    var json = JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK:
        _local_fallback("json_invalido")
        return
    var response = json.data
    if typeof(response) != TYPE_DICTIONARY or not procesar_respuesta_ia(response):
        _local_fallback("perfil_invalido")
        return
    var source = str(response.get("fuente", ""))
    _last_source = source if source in ["groq", "local"] else "externo"
    if _last_source == "groq":
        _remote_details = _validated_details(response)
    print("BUILDPC3D IA: fuente_informada=", _last_source, "; perfil=", _current_use)
    ia_resuelta.emit(true, _profile_message(_current_use), _current_use)

func _validated_details(response: Dictionary) -> Dictionary:
    var level = response.get("nivel_exigencia")
    var activity = response.get("actividad")
    var resolution = response.get("resolucion")
    if typeof(level) != TYPE_STRING or typeof(activity) != TYPE_STRING or typeof(resolution) != TYPE_STRING:
        return {}
    if level not in ["basico", "intermedio", "alto", "extremo"] \
            or activity not in ["juegos", "desarrollo", "edicion_render", "oficina", "general"] \
            or resolution not in ["no_especificada", "1080p", "1440p", "4k"]:
        return {}
    return {"nivel_exigencia": level, "actividad": activity, "resolucion": resolution}

func generar_inicial(uso: String, demanda: Dictionary = {}) -> Dictionary:
    if _catalog.is_empty() or not establecer_uso_manual(uso):
        return {"ok": false, "mensaje": "No hay catálogo disponible o el uso no es válido."}
    var result: Dictionary = _recommender.generar_equipo_inicial(_current_use, _catalog, demanda)
    if result.get("ok", false):
        _equipment = result["equipo"].duplicate(true)
        _equipment_demand = demanda.duplicate(true)
        _equipment_use = _current_use
    return result

func obtener_alternativas(component_type: String) -> Array:
    if _equipment.is_empty(): return []
    var filtered = _filter.filtrar_por_uso(_equipment_use, _catalog, _equipment_demand)
    return _recommender.obtener_alternativas(_equipment, component_type, filtered)

func reemplazar(component_type: String, candidate: Dictionary) -> Dictionary:
    var filtered = _filter.filtrar_por_uso(_equipment_use, _catalog, _equipment_demand)
    var result: Dictionary = _recommender.reemplazar_pieza(_equipment, component_type, candidate, filtered)
    if result.get("ok", false):
        _equipment = result["equipo"].duplicate(true)
    return result

func calcular_total() -> int:
    return _recommender.calcular_valor_total(_equipment)

func equipo_actual() -> Dictionary:
    return _equipment.duplicate(true)
