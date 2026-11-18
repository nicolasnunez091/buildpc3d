extends SceneTree

const CONTROLLER = preload("res://scripts/controller/PCController.gd")
var failures = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller = CONTROLLER.new()
	root.add_child(controller)
	for route in ["ok", "badhealth", "failpost"]:
		controller.solicitar_uso("Necesito editar videos", "http://127.0.0.1:18949/" + route + "/interpretar", true)
		var result = await controller.ia_resuelta
		var source = "groq" if route == "ok" else "local"
		var good = result[0] and result[2] == "edicion" and controller._last_source == source
		if route != "ok":
			good = good and "Interpretación local" in result[1]
		print(("OK " if good else "FAIL ") + "calentamiento " + route)
		if not good:
			failures += 1
		await process_frame
	controller.free()
	quit(1 if failures else 0)
