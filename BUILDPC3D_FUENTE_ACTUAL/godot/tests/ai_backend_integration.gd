extends SceneTree

# Requiere tests/backend_groq_fixture.py; NO llama al proveedor real.
const Controller = preload("res://scripts/controller/PCController.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = Controller.new()
    root.add_child(controller)
    var examples = [
        ["Quiero un computador para diseño gráfico", "edicion", "groq"],
        ["Necesito una PC para jugar Valorant", "juegos", "groq"],
        ["Quiero una computadora para programar", "edicion", "groq"],
        ["Necesito editar videos y hacer renders", "edicion", "groq"],
        ["Busco algo económico para Word y Excel", "ofimatica", "groq"],
        ["Quiero jugar y editar videos", "edicion", "groq"],
        ["Quiero jugar con respuesta inválida", "juegos", "local"],
        ["Quiero jugar con servicio desconectado", "juegos", "local"],
    ]
    for example in examples:
        controller.solicitar_uso(example[0], "http://127.0.0.1:18939/interpretar")
        var result = await controller.ia_resuelta
        var ok = result[0] and result[2] == example[1] and controller._last_source == example[2]
        ok = ok and "Groq" not in result[1] and "LOCAL" not in result[1]
        print(("OK " if ok else "FAIL ") + "Backend + proveedor simulado: " + example[0])
        if not ok:
            failures += 1
    await process_frame
    controller.free()
    print("GODOT → PYTHON → GROQ SIMULADO: ", failures, " fallos")
    quit(1 if failures else 0)
