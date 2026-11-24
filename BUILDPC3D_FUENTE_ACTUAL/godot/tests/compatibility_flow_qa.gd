extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
var failures := 0

func check(name: String, ok: bool) -> void:
	print(("OK | " if ok else "FAIL | ") + name)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	app._dao._project_id = ""
	await process_frame
	app._choose_manual_use("juegos")
	app._generate()
	var rec = app._controller._recommender
	check("Generación inicial", app._equipment.size() == 7)
	check("Avisos visibles de BIOS y conectores", app._compatibility_status.visible and "BIOS" in app._compatibility_status.text and "Conectores" in app._compatibility_status.text)
	var alternatives = app._controller.obtener_alternativas("gpu")
	check("Existe alternativa GPU para fixture", not alternatives.is_empty())
	if not alternatives.is_empty():
		var bad = alternatives[0]
		var old = app._equipment.duplicate(true)
		var old_total = app._total.text
		var old_node = app._viewer._assembly_root.get_node_or_null("Pieza_gpu")
		rec._spec_loaded = true
		rec._spec_cache = {"gpu": {str(bad.id): {"pcie_8pin_required": 3}}, "psu": {str(old.psu.id): {"pcie_8pin_available": 1}}}
		check("Fixture GPU incompatible", rec.evaluar_adicional(bad, old.psu).estado == "incompatible")
		var options = app._controller.obtener_alternativas("gpu")
		check("Alternativas excluyen GPU incompatible", not options.any(func(p): return p.id == bad.id))
		app._open_catalog("gpu")
		app._select_candidate(bad)
		app._replace()
		check("Reemplazo incompatible rechazado", app._equipment == old and app._controller.equipo_actual() == old)
		check("Precio conservado tras rechazo", app._total.text == old_total and app._controller.calcular_total() == rec.calcular_valor_total(old))
		check("Visor conserva nodo anterior", app._viewer._assembly_root.get_node_or_null("Pieza_gpu") == old_node)
		check("UI informa rechazo", "válida" in app._catalog_status.text)
		rec._spec_cache = {}
		var regenerated = app._controller.generar_inicial("juegos")
		check("Recomendación con datos pendientes", regenerated.get("ok", false) and not rec.advertencias_compatibilidad(regenerated.equipo).is_empty())
		var specs = {"gpu": {}, "psu": {}}
		for gpu in app._catalog.gpu: specs.gpu[str(gpu.id)] = {"pcie_8pin_required": 3}
		for psu in app._catalog.psu: specs.psu[str(psu.id)] = {"pcie_8pin_available": 0}
		rec._spec_cache = specs
		var before = app._controller.equipo_actual()
		var blocked = app._controller.generar_inicial("juegos")
		check("Generación rechaza todas las combinaciones incompatibles", not blocked.get("ok", false))
		check("Generación fallida conserva equipo", app._controller.equipo_actual() == before)
		check("Generación fallida informa causa controlada", not str(blocked.get("mensaje", "")).is_empty())
	app.queue_free()
	await process_frame
	print("COMPATIBILIDAD FLUJO | fallos=", failures)
	quit(1 if failures else 0)
