extends SceneTree

const DAO = preload("res://scripts/model/CatalogDAO.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + label)
    if not ok: failures += 1

func _initialize() -> void:
    var dao = DAO.new()
    var original = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"]
    var base = dao._with_local_ssd(original)
    var result = dao._with_local_extensions(original)
    var count = 0
    for category in result:
        count += result[category].size()
    check("Extensión vacía conserva los 52", count == 52 and result == base)
    var fixture = base.cpu[0].duplicate(true)
    fixture.id = "cpu_fixture_no_product"
    var extension = {"schema_version":1,"catalog":{"cpu":[fixture]}}
    var merged = dao._merge_components_extension(base, extension)
    check("Combina una pieza de prueba sin mutar base", merged.cpu.size() == base.cpu.size() + 1 and base.cpu[0].id != fixture.id)
    check("Migración idéntica no duplica", dao._merge_components_extension(merged, extension) == merged)
    var conflict = fixture.duplicate(true)
    conflict.name = "datos en conflicto"
    check("ID idéntico con datos distintos se rechaza", dao._merge_components_extension(merged, {"schema_version":1,"catalog":{"cpu":[conflict]}}).is_empty())
    check("Categoría desconocida rechazada", dao._merge_components_extension(base, {"schema_version":1,"catalog":{"cooler":[]}}).is_empty())
    var invalid = fixture.duplicate(true)
    invalid.erase("socket")
    check("Esquema incompleto rechazado", dao._merge_components_extension(base, {"schema_version":1,"catalog":{"cpu":[invalid]}}).is_empty())
    dao.free()
    print("EXTENSIONES LOCALES: ", failures, " fallos")
    quit(1 if failures else 0)
