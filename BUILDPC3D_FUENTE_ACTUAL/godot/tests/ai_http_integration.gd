extends SceneTree

const ControllerScript = preload("res://scripts/controller/PCController.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func _run() -> void:
    var controller = ControllerScript.new()
    root.add_child(controller)
    var text = "Quiero un PC para diseño"
    for route in ["good", "invalid", "error", "disconnect"]:
        controller.solicitar_uso(text, "http://127.0.0.1:18937/" + route)
        var response = await controller.ia_resuelta
        var expected_source = "groq" if route == "good" else "local"
        check("HTTP local con proveedor simulado " + route, response[0] and response[2] == "edicion" and controller._last_source == expected_source)
    await process_frame # Evita liberar el controlador mientras emite la señal.
    controller.free()
    print("INTEGRACIÓN HTTP: ", failures, " fallos")
    quit(1 if failures else 0)
