extends SceneTree

# Ejecutar con ventana gráfica. Los cambios se confirman por la interfaz real.
const MAIN = preload("res://scenes/Main.tscn")
var failures = 0
var output = ""

func _initialize() -> void:
    call_deferred("_run")

func check(message: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + message)
    if not ok:
        failures += 1

func wait_frames(count: int = 8) -> void:
    for i in range(count):
        await process_frame

func capture(name: String) -> void:
    var path = output.path_join(name + ".png")
    check("Captura " + name, root.get_texture().get_image().save_png(path) == OK)

func changed_pixels(before: Image, after: Image) -> int:
    var changed = 0
    for y in range(0, mini(before.get_height(), after.get_height()), 4):
        for x in range(0, mini(before.get_width(), after.get_width()), 4):
            var a = before.get_pixel(x, y)
            var b = after.get_pixel(x, y)
            if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
                changed += 1
    return changed

func _run() -> void:
    output = ProjectSettings.globalize_path("res://../docs/evidencias_finales").simplify_path()
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(540, 960)
    var app = MAIN.instantiate()
    root.add_child(app)
    await wait_frames()
    app._choose_use("juegos")
    app._generate_selected()
    await wait_frames()
    # Preparación: un chasis amplio facilita comparar GPU de dos y tres fans.
    var cases = app._controller.obtener_alternativas("case")
    for candidate in cases:
        if int(candidate.get("max_gpu_mm", 0)) >= 335:
            app._open_catalog("case")
            app._select_candidate(candidate)
            app._replace()
            await wait_frames()
            break
    capture("01_inicial")
    var sequence = ["gpu", "ram", "motherboard", "psu", "case", "cpu"]
    for category in sequence:
        var alternatives = app._controller.obtener_alternativas(category)
        if alternatives.is_empty():
            check("Alternativa compatible " + category, false)
            continue
        var chosen: Dictionary = alternatives.back() if category == "gpu" else alternatives[0]
        var before_image = app._viewer._viewport.get_texture().get_image()
        var previous_id = str(app._equipment[category]["id"])
        var previous_total = app._controller.calcular_total()
        var expected_total = previous_total - int(app._equipment[category]["price_cop"]) + int(chosen["price_cop"])
        capture("antes_" + category)
        app._open_catalog(category)
        app._select_candidate(chosen)
        app._replace()
        await wait_frames(12)
        var after_image = app._viewer._viewport.get_texture().get_image()
        var pixel_count = changed_pixels(before_image, after_image)
        capture("despues_" + category)
        check("Reemplazo y precio " + category, app._pages[1].visible and str(app._equipment[category]["id"]) != previous_id and app._controller.calcular_total() == expected_total)
        check("Diferencia visible " + category + " (muestras " + str(pixel_count) + ")", pixel_count > 25)
    app._viewer._angle = 0.70
    app._viewer._pitch = -0.18
    app._viewer._update_camera()
    await wait_frames()
    capture("angulo_alternativo")
    app.free()
    print("EVIDENCIA VARIANTES: ", failures, " fallos")
    quit(1 if failures else 0)
