extends SceneTree

const DAO = preload("res://scripts/model/CatalogDAO.gd")
const REC = preload("res://scripts/model/Recommender.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + label)
    if not ok: failures += 1

func _initialize() -> void:
    var dao = DAO.new()
    var base = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"]
    var full = dao._with_local_ssd(base)
    var ids = {}
    var count = 0
    for category in full:
        for part in full[category]:
            ids[part.id] = true
            count += 1
    check("42 originales y diez SSD únicos", base.size() == 6 and full.size() == 7 and count == 52 and ids.size() == 52 and full.ssd.size() == 10)
    var twice = dao._with_local_ssd(full)
    check("Extensión idempotente sin duplicados", twice == full)
    var rec = REC.new()
    var board_count = 0
    for board in full.motherboard:
        if rec.son_compatibles(board, full.ssd[1]): board_count += 1
    check("Ocho placas con M.2 NVMe 2280", board_count == 8)
    check("Placa desconocida rechazada", not rec.son_compatibles({"type":"motherboard","id":"desconocida"}, full.ssd[1]))
    check("SATA sin bahía verificada rechazado", not rec.son_compatibles({"type":"case","id":"desconocido"}, full.ssd[0]))
    check("SATA con bahía Corsair verificada", rec.son_compatibles({"type":"case","id":"case_chasis_corsair_4000d_airflow_mid_tower"}, full.ssd[0]))
    var generated = rec.generar_equipo_inicial("juegos", full)
    check("Generación con SSD", generated.get("ok", false) and generated.get("equipo", {}).has("ssd"))
    # Simula descarga de seis categorías y posterior lectura del caché v4.
    dao._project_id = "ssd-test"
    dao._cache_path = "user://ssd-test-" + str(Time.get_ticks_usec()) + ".json"
    dao._remote_catalog = base.duplicate(true)
    dao._incoming_version = 4
    dao._finish_download()
    var cached = JSON.parse_string(FileAccess.get_file_as_string(dao._cache_path))
    check("Caché conserva solo seis categorías remotas", cached.catalog.size() == 6 and not cached.catalog.has("ssd") and dao._catalog.ssd.size() == 10)
    var reload = DAO.new()
    reload._project_id = dao._project_id
    reload._cache_path = dao._cache_path
    reload._load_local_catalog()
    check("Caché v4 recupera SSD locales", reload._origin == "firebase" and reload._catalog == full and reload._version == 4)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(dao._cache_path))
    reload.free()
    dao.free()
    print("SSD: ", failures, " fallos")
    quit(1 if failures else 0)
