extends SceneTree

const OfflineDAO = preload("res://tests/OfflineCatalogDAO.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func _run() -> void:
    var dao = OfflineDAO.new()
    root.add_child(dao)
    dao._cache_path = "user://firestore-offline-test-" + str(Time.get_ticks_usec()) + ".json"
    var state = {"failed": false}
    dao.error_catalogo.connect(func(_message): state["failed"] = true)
    var catalog: Dictionary = dao.obtener_catalogo()
    var count = 0
    for kind in dao.TYPES:
        count += catalog.get(kind, []).size()
    check("Carga local inmediata", count == 42)
    var deadline = Time.get_ticks_msec() + 15000
    while not state["failed"] and Time.get_ticks_msec() < deadline:
        await create_timer(0.1).timeout
    var kept = 0
    for kind in dao.TYPES:
        kept += dao._catalog.get(kind, []).size()
    check("Desconexión conserva catálogo local", state["failed"] and kept == 42 and dao._origin != "firebase")
    dao.free()
    print("FIRESTORE DESCONECTADO: ", failures, " fallos")
    quit(1 if failures else 0)
