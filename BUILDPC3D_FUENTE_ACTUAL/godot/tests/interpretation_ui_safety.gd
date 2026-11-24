extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
var failures = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, ok: bool) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	app._dao._project_id = ""
	await process_frame
	app._choose_manual_use("juegos")
	app._generate()
	var before = app._equipment.duplicate(true)
	_check("Equipo base y visor 3D", not before.is_empty() and app._viewer._assembly_root.get_child_count() > 0)
	app._description.text = "Quiero comer pizza"
	app._generate()
	_check("Inválido no modifica equipo", app._equipment == before and "solicitud válida" in app._home_status.text)
	app._description.text = "Quiero comprar un PC"
	app._generate()
	_check("Incompleto no modifica equipo", app._equipment == before and "Cuéntanos" in app._home_status.text)
	app._description.text = "Necesito un PC para estudiar"
	app._request_text = "Necesito un PC para juegos"
	app._pending_generation = true
	app._on_ia_resuelta(true, "respuesta antigua", "juegos")
	_check("Respuesta antigua no cambia el equipo", app._equipment == before and "cambió" in app._home_status.text and not app._generate_button.disabled)
	app._manual_use = ""
	app._choose_use("")
	app._request_text = app._description.text
	app._on_ia_resuelta(false, "No aplica", "")
	_check("Rechazo no genera ni conserva perfil automático", app._equipment == before and app._current_use.is_empty())
	app._controller._last_source = "rechazado"
	app._request_text = app._description.text
	app._on_ia_resuelta(false, "No aplica", "")
	app._choose_manual_use("juegos")
	app._generate()
	_check("No aplica bloquea generación incluso con selección previa", app._equipment == before and "rechazada" in app._home_status.text)
	app.queue_free()
	await process_frame
	await process_frame
	print("INTERFAZ SEGURA: ", failures, " fallos")
	quit(1 if failures else 0)
