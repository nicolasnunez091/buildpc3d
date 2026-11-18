extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
var failures = 0

func _initialize() -> void:
	call_deferred("_run")

func check(message: String, condition: bool) -> void:
	print(("OK " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	await process_frame
	check("Sin campo de presupuesto", app.find_children("*", "SpinBox", true, false).is_empty())
	check("Inicio sin uso manual", app._manual_use.is_empty() and app._current_use.is_empty())
	app._description.text = "Necesito editar videos"
	app._on_ia_resuelta(true, "Recomendación anterior", "edicion")
	app._choose_manual_use("juegos")
	check("Selección manual independiente", app._manual_use == "juegos" and app._recommended_use == "edicion")
	app._clear_use_button.emit_signal("pressed")
	check("Quitar restaura recomendación y conserva texto", app._manual_use.is_empty() and app._current_use == "edicion" and app._description.text == "Necesito editar videos")
	app._choose_manual_use("ofimatica")
	app._choose_manual_use("ofimatica")
	check("Segundo toque deselecciona", app._manual_use.is_empty() and app._current_use == "edicion")
	app._description.text = "Quiero jugar Roblox"
	app._on_ia_resuelta(true, "Recomendación", "juegos")
	app._generate_selected()
	var basic_equipment = app._equipment.duplicate(true)
	app._description.text = "Quiero jugar God of War Ragnarök a 1440p"
	app._on_ia_resuelta(true, "Recomendación", "juegos")
	app._generate_selected()
	check("Interpretación influye en GPU y RAM", int(app._equipment.get("gpu", {}).get("vram_gb", 0)) > int(basic_equipment.get("gpu", {}).get("vram_gb", 0)) and int(app._equipment.get("ram", {}).get("capacity_gb", 0)) > int(basic_equipment.get("ram", {}).get("capacity_gb", 0)))
	check("Explicación de exigencia visible", "Exigencia estimada" in app._assembly_status.text)
	app._description.text = ""
	app._clear_manual_use()
	app._generate()
	check("Sin uso no selecciona automáticamente", app._current_use.is_empty())
	app._choose_manual_use("juegos")
	app._generate()
	check("Generación sin dinero", app._equipment.size() == 7 and app._controller._recommender.es_equipo_compatible(app._equipment))
	var drives = app._controller.obtener_alternativas("ssd")
	check("Alternativas SSD disponibles", drives.size() >= 2)
	if not drives.is_empty():
		var old_price = int(app._equipment.ssd.price_cop)
		var old_total = app._controller.calcular_total()
		app._open_catalog("ssd")
		app._select_candidate(drives[0])
		app._replace()
		var expected_ssd_total = old_total - old_price + int(drives[0].price_cop)
		check("Cambio SSD actualiza total", app._controller.calcular_total() == expected_ssd_total and app._total.text == app._money(expected_ssd_total))
		app._show_dashboard()
		check("Dashboard incluye SSD", "Almacenamiento SSD" in app._dashboard.dialog_text and app._money(expected_ssd_total) in app._dashboard.dialog_text)
	check("Total visible", app._total.text == app._money(app._controller.calcular_total()) and "COP" in app._total.text)
	check("Visor tiene ensamblaje", app._viewer._assembly_root.get_child_count() > 0)
	var found = false
	for category in ["cpu", "motherboard", "ram", "gpu", "psu", "case"]:
		var alternatives = app._controller.obtener_alternativas(category)
		for option in alternatives:
			if int(option.price_cop) > int(app._equipment[category].price_cop):
				var original = app._equipment.duplicate(true)
				var old_total = app._controller.calcular_total()
				app._open_catalog(category)
				app._select_candidate(option)
				app._cancel_candidate()
				check("Cancelar no cambia equipo", app._equipment == original and app._selected_candidate.is_empty())
				app._open_catalog(category)
				app._select_candidate(option)
				app._replace()
				var expected = old_total - int(original[category].price_cop) + int(option.price_cop)
				check("Alternativa más costosa admitida y total actualizado", app._controller.calcular_total() == expected and app._total.text == app._money(expected))
				app._show_dashboard()
				check("Dashboard muestra total", app._money(expected) in app._dashboard.dialog_text)
				found = true
				break
		if found:
			break
	check("Existe alternativa más costosa compatible", found)
	var before_laptop = app._equipment.duplicate(true)
	app._description.text = "Quiero un portátil"
	app._generate()
	check("Portátil se rechaza sin modificar equipo", app._equipment == before_laptop and "no portátiles" in app._home_status.text)
	app.free()
	print("SIN PRESUPUESTO Y SELECCIÓN: ", failures, " fallos")
	quit(1 if failures else 0)
