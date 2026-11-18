extends SceneTree

const MockDAO = preload("res://tests/MockCatalogDAO.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func _run() -> void:
    var dao = MockDAO.new()
    root.add_child(dao)
    dao._project_id = "proyecto-falso"
    dao._origin = "firebase"
    dao._version = 1
    dao._cache_path = "user://buildpc3d-firestore-test-" + str(Time.get_ticks_usec()) + ".json"
    dao._catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"]
    # Dos consultas sin cambios: se consulta metadata, no se descargan colecciones.
    for i in range(2):
        dao.obtener_catalogo()
        await dao._http.request_completed
    check("CP023 sin descarga si versión no cambia", dao.requested_urls.size() == 2 and dao._version == 1)
    # La tercera metadata anuncia versión 2; CPU lleva dos páginas.
    dao.obtener_catalogo()
    for i in range(8):
        await dao._http.request_completed
    await process_frame
    var saved = JSON.parse_string(FileAccess.get_file_as_string(dao._cache_path))
    check("CP024 cambio de versión y paginación", dao.requested_urls.size() == 10 and dao._version == 2 and dao._catalog["cpu"].size() == 8)
    check("CP024 caché Firebase persistida", typeof(saved) == TYPE_DICTIONARY and saved.get("version", 0) == 2 and saved.get("source", "") == "firebase")
    dao.free()
    print("INTEGRACIÓN FIRESTORE SIMULADA: ", failures, " fallos")
    quit(1 if failures else 0)
