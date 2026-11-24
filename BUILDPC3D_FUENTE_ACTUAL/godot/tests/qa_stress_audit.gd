extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
const DAO = preload("res://scripts/model/CatalogDAO.gd")
const REC = preload("res://scripts/model/Recommender.gd")
var passed = 0
var failed = 0

func _initialize() -> void:
	call_deferred("_run")

func check(label: String, ok: bool) -> void:
	print(("OK | " if ok else "FAIL | ") + label)
	if ok: passed += 1
	else: failed += 1

func _run() -> void:
	var dao = DAO.new()
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var catalog = dao._with_local_extensions(raw.catalog)
	var rec = REC.new()
	var ids = {}
	var count = 0
	for category in catalog:
		for item in catalog[category]:
			count += 1
			ids[item.id] = true
	check("Catálogo: siete categorías", catalog.size() == 7)
	check("Catálogo: 42 originales", raw.catalog.values().reduce(func(n, parts): return n + parts.size(), 0) == 42)
	check("Catálogo: 10 SSD", catalog.ssd.size() == 10)
	check("Catálogo: 52 IDs únicos", count == 52 and ids.size() == 52)
	check("Catálogo: extensión sin duplicados", dao._with_local_extensions(raw.catalog) == catalog)
	var invalid_catalog = raw.catalog.duplicate(true)
	invalid_catalog.gpu.clear()
	check("Catálogo: rechaza colección remota vacía", not dao._catalog_is_valid(invalid_catalog))
	invalid_catalog = raw.catalog.duplicate(true)
	invalid_catalog.gpu[0].erase("length_mm")
	check("Catálogo: rechaza GPU sin longitud", not dao._catalog_is_valid(invalid_catalog))
	var app = MAIN.instantiate()
	root.add_child(app)
	app._dao._project_id = ""
	await process_frame
	check("Inicio: catálogo local disponible", app._catalog.size() == 7)
	check("Inicio: sin equipo", app._equipment.is_empty())
	check("Inicio: tres pantallas", app._pages.size() == 3)
	check("Inicio: teclado habilitado", app._description.virtual_keyboard_enabled)
	var exhaustive_claim = false
	for label in app.find_children("*", "Label", true, false):
		if "Compatibilidad real" in label.text:
			exhaustive_claim = true
	check("Interfaz: no afirma compatibilidad exhaustiva", not exhaustive_claim)
	app._choose_manual_use("juegos")
	app._generate()
	check("Generación: siete piezas", app._equipment.size() == 7)
	check("Generación: compatibilidad vigente", rec.es_equipo_compatible(app._equipment))
	var sum = 0
	for category in REC.REQUIRED:
		sum += int(app._equipment[category].price_cop)
	check("Precio: suma independiente", sum == app._controller.calcular_total())
	check("Precio: visible COP", app._total.text == app._money(sum) and "COP" in app._total.text)
	check("Precio: equipo incompleto no compatible", not rec.es_equipo_compatible({}))
	check("Precio: negativo no reduce el total", rec.calcular_valor_total({"cpu":{"price_cop":-500}}) == 0)
	check("Precio: texto malformado ignorado", rec.calcular_valor_total({"cpu":{"price_cop":"sin dato"}}) == 0)
	check("Precio: pieza ausente cuenta cero", rec.calcular_valor_total({}) == 0)
	check("Precio: NaN ignorado", rec.calcular_valor_total({"cpu":{"price_cop":NAN}}) == 0)
	check("Precio: infinito ignorado", rec.calcular_valor_total({"cpu":{"price_cop":INF}}) == 0)
	check("Precio: fracción inválida ignorada", rec.calcular_valor_total({"cpu":{"price_cop":1.5}}) == 0)
	check("Precio: componente malformado no falla", rec.calcular_valor_total({"cpu":"error"}) == 0)
	check("Compatibilidad: DDR distinta rechazada", not rec.son_compatibles({"type":"ram","ram_type":"DDR4"}, {"type":"motherboard","ram_type":"DDR5"}))
	check("Compatibilidad: sockets distintos rechazados", not rec.son_compatibles({"type":"cpu","socket":"AM4","ram_types":["DDR4"]}, {"type":"motherboard","socket":"AM5","ram_type":"DDR5"}))
	check("Compatibilidad: GPU larga rechazada", not rec.son_compatibles({"type":"gpu","length_mm":400}, {"type":"case","max_gpu_mm":300}))
	check("Compatibilidad: dimensiones faltantes rechazadas", not rec.son_compatibles({"type":"gpu"}, {"type":"case","max_gpu_mm":300}))
	check("Compatibilidad: placa SSD desconocida rechazada", not rec.son_compatibles({"type":"motherboard","id":"unknown"}, catalog.ssd[1]))
	check("Compatibilidad: SATA sin bahía rechazada", not rec.son_compatibles({"type":"case","id":"unknown"}, catalog.ssd[0]))
	check("Compatibilidad: placa y chasis incompatibles", not rec.son_compatibles({"type":"motherboard","form_factor":"ATX"}, {"type":"case","form_factors":["mATX"]}))
	check("Compatibilidad: GPU sin datos de conectores no verificada", not rec.son_compatibles({"type":"gpu","id":"fixture_gpu"}, {"type":"psu","id":"fixture_psu","watts":1000}))
	check("Compatibilidad: fuente sin datos de formato no verificada", not rec.son_compatibles({"type":"psu","id":"fixture_psu"}, {"type":"case","id":"fixture_case"}))
	var controller = preload("res://scripts/controller/PCController.gd").new()
	var events: Array = []
	controller.ia_resuelta.connect(func(ok, message, use): events.append([ok, message, use]))
	controller._last_text = "Necesito un PC para estudiar"
	for status in [400, 429, 500, 503]:
		controller._on_ai_completed(HTTPRequest.RESULT_SUCCESS, status, PackedStringArray(), PackedByteArray())
		check("Red: HTTP " + str(status) + " usa respaldo", events.back()[0] and events.back()[2] == "ofimatica")
	controller._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "no json".to_utf8_buffer())
	check("Red: JSON inválido usa respaldo", events.back()[0] and events.back()[2] == "ofimatica")
	controller._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	check("Red: respuesta vacía usa respaldo", events.back()[0] and events.back()[2] == "ofimatica")
	controller._on_ai_completed(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	check("Red: timeout devuelve resultado", events.back()[0] and events.back()[2] == "ofimatica")
	controller.free()
	var before = app._equipment.duplicate(true)
	app._description.text = "Quiero comer pizza"
	app._generate()
	check("IA: petición inválida conserva equipo", app._equipment == before)
	app._description.text = "Quiero comprar un PC"
	app._generate()
	check("IA: petición incompleta conserva equipo", app._equipment == before)
	app._description.text = ""
	app._clear_manual_use()
	check("Interfaz: quitar selección conserva equipo", app._equipment == before and app._manual_use.is_empty())
	app._choose_manual_use("juegos")
	for category in REC.REQUIRED:
		var options = app._controller.obtener_alternativas(category)
		var all_valid = true
		for item in options:
			var trial = app._equipment.duplicate(true)
			trial[category] = item
			if not rec.es_equipo_compatible(trial): all_valid = false
		check("Alternativas " + category + ": respetan validación vigente", all_valid)
		if not options.is_empty():
			var saved = app._equipment.duplicate(true)
			app._open_catalog(category)
			app._select_candidate(options[0])
			app._cancel_candidate()
			check("Cancelar " + category + ": conserva equipo", app._equipment == saved)
			app._open_catalog(category)
			app._select_candidate(options[0])
			app._replace()
			var expected = rec.calcular_valor_total(app._equipment)
			check("Reemplazar " + category + ": actualiza total", app._total.text == app._money(expected) and rec.es_equipo_compatible(app._equipment))
	check("Visor: SSD presente una vez", app._viewer._assembly_root.find_children("Pieza_ssd", "StaticBody3D", true, false).size() == 1)
	for category in ["case", "motherboard", "cpu", "ram", "gpu", "psu"]:
		check("Visor: componente " + category, app._viewer._assembly_root.get_node_or_null("Pieza_" + category) != null)
	var memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	var start = Time.get_ticks_msec()
	for i in range(100):
		app._set_page(i % 3)
	check("Estrés: 100 navegaciones terminan", app._pages[0].visible)
	for i in range(100):
		app._viewer._orbit(Vector2(17, -3))
		app._viewer.reset_camera()
	check("Estrés: 100 giros y reinicios cámara", is_finite(app._viewer._distance) and is_finite(app._viewer._angle))
	var wheel_in = InputEventMouseButton.new()
	wheel_in.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_in.pressed = true
	var wheel_out = InputEventMouseButton.new()
	wheel_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_out.pressed = true
	for i in range(100):
		app._viewer._gui_input(wheel_in if i % 2 == 0 else wheel_out)
	check("Estrés: 100 zooms dentro de límites", app._viewer._distance >= 3.5 and app._viewer._distance <= 7.5)
	var changed = 0
	for i in range(100):
		var options = app._controller.obtener_alternativas("ssd")
		if options.is_empty(): break
		app._open_catalog("ssd")
		app._select_candidate(options[i % options.size()])
		app._replace()
		changed += 1
	check("Estrés: 100 reemplazos SSD", changed == 100)
	check("Estrés: no duplica SSD", app._viewer._assembly_root.find_children("Pieza_ssd", "StaticBody3D", true, false).size() == 1)
	check("Estrés: precio final correcto", app._total.text == app._money(rec.calcular_valor_total(app._equipment)))
	for i in range(50):
		app._generate_selected()
	check("Estrés: 50 generaciones", app._equipment.size() == 7 and rec.es_equipo_compatible(app._equipment))
	await process_frame
	var memory_after = Performance.get_monitor(Performance.MEMORY_STATIC)
	print("MÉTRICAS | duración_ms=", Time.get_ticks_msec() - start, " | memoria_estatica_antes=", memory_before, " | memoria_estatica_despues=", memory_after, " | renderer=headless")
	app.queue_free()
	await process_frame
	dao.free()
	print("QA ESTRÉS | aprobados=", passed, " | fallos=", failed)
	quit(1 if failed else 0)
