extends SceneTree

# Solo lectura. --expect-fallback verifica el escenario sin metadatos/red.
const DAO = preload("res://scripts/model/CatalogDAO.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(message: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + message)
    if not ok:
        failures += 1

func count_items(catalog: Dictionary) -> int:
    var count = 0
    for category in DAO.TYPES:
        count += catalog.get(category, []).size()
    count += catalog.get("ssd", []).size()
    return count

func _run() -> void:
    var dao = DAO.new()
    root.add_child(dao)
    dao._cache_path = "user://firestore-real-test-" + str(Time.get_ticks_usec()) + ".json"
    var state = {"firebase": false, "error": false}
    dao.catalogo_cargado.connect(func(_catalog, source):
        if source == "firebase":
            state["firebase"] = true
    )
    dao.error_catalogo.connect(func(_message): state["error"] = true)
    var local = dao.obtener_catalogo()
    check("Proyecto configurado", dao._project_id == "buildpc3d")
    check("Catálogo local disponible de inmediato", count_items(local) == 52)
    var deadline = Time.get_ticks_msec() + 25000
    while not state["firebase"] and not state["error"] and Time.get_ticks_msec() < deadline:
        await create_timer(0.1).timeout
    if "--expect-fallback" in OS.get_cmdline_user_args():
        check("Fallo remoto conserva catálogo local", state["error"] and count_items(dao._catalog) == 52 and dao._origin != "firebase")
    else:
        var expected = {}
        var actual = {}
        for category in DAO.TYPES:
            for part in local.get(category, []):
                expected[part["id"]] = true
            for part in dao._catalog.get(category, []):
                actual[part["id"]] = true
        check("DAO lee catálogo real", state["firebase"] and dao._origin == "firebase")
        check("42 IDs remotos coinciden y 10 SSD locales", count_items(dao._catalog) == 52 and actual == expected and dao._catalog.get("ssd", []).size() == 10)
        check("Versión remota válida", dao.version_catalogo() > 0)
    dao.free()
    print("FIRESTORE REAL SOLO LECTURA: ", failures, " fallos")
    quit(1 if failures else 0)
