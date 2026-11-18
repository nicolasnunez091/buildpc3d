extends SceneTree

const Cooling = preload("res://scripts/model/CpuCoolingInfo.gd")
const MAIN = preload("res://scenes/Main.tscn")
var failures = 0

func check(label: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + label)
    if not ok: failures += 1

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var info = Cooling.new()
    for id in ["cpu_amd_ryzen_5_5600g", "cpu_amd_ryzen_5_5600", "cpu_amd_ryzen_5_7600", "cpu_intel_core_i3_12100f", "cpu_intel_core_i5_12400f"]:
        var msg = info.message({"id":id, "presentation":"boxed"})
        check(id + " incluido", "incluye" in msg and "no garantiza" in msg.to_lower())
    for id in ["cpu_amd_ryzen_7_5700x", "cpu_amd_ryzen_7_7800x3d", "cpu_intel_core_i7_14700k"]:
        var msg = info.message({"id":id, "presentation":"boxed"})
        check(id + " requiere disipador", "no incluye disipador" in msg and "precio no la incluye" in msg)
    check("CPU desconocida", "No se ha confirmado" in info.message({"id":"cpu_no_verificada"}))
    check("Tray no hereda boxed", "No se ha confirmado" in info.message({"id":"cpu_amd_ryzen_5_5600","presentation":"tray"}))
    check("Presentación desconocida es condicional", "no está confirmada" in info.message({"id":"cpu_amd_ryzen_5_5600"}))
    var app = MAIN.instantiate()
    root.add_child(app)
    await process_frame
    app._choose_manual_use("ofimatica")
    app._generate()
    var text = app._cooling_status.text
    check("Advertencia visible tras generación", not text.is_empty())
    app._show_dashboard()
    check("Dashboard conserva advertencia", text.trim_prefix("REFRIGERACIÓN: ") in app._dashboard.dialog_text)
    var candidates = app._controller.obtener_alternativas("cpu")
    if not candidates.is_empty():
        var selected = candidates[0]
        for candidate in candidates:
            if ("no incluye disipador" in info.message(candidate)) != ("no incluye disipador" in info.message(app._equipment.cpu)):
                selected = candidate
                break
        app._open_catalog("cpu")
        app._select_candidate(selected)
        app._replace()
        check("Cambio CPU actualiza advertencia", app._cooling_status.text == "REFRIGERACIÓN: " + info.message(app._equipment.cpu))
        var saved = app._cooling_status.text
        var options = app._controller.obtener_alternativas("ssd")
        if not options.is_empty():
            app._open_catalog("ssd")
            app._select_candidate(options[0])
            app._replace()
            check("Cambio SSD conserva advertencia", app._cooling_status.text == saved)
    else:
        check("Existe alternativa CPU para comprobar interfaz", false)
    app.free()
    print("AVISO REFRIGERACIÓN CPU: ", failures, " fallos")
    quit(1 if failures else 0)
