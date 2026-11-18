extends SceneTree

# Ejecutar con el renderer gráfico, no --headless. No necesita claves externas.
const MAIN = preload("res://scenes/Main.tscn")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func wait_frames(count: int = 5) -> void:
    for i in range(count):
        await process_frame

func capture(name: String) -> void:
    var path = ProjectSettings.globalize_path("user://buildpc3d_" + name + ".png")
    var err = root.get_texture().get_image().save_png(path)
    check("Captura " + name + " (" + path + ")", err == OK)

func touch(viewer: Control, index: int, position: Vector2, pressed: bool) -> void:
    var event = InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    viewer._gui_input(event)

func _run() -> void:
    root.size = Vector2i(540, 960)
    var app = MAIN.instantiate()
    root.add_child(app)
    await wait_frames()
    capture("configurador")
    check("Catálogo local cargado", not app._catalog.is_empty())
    check("Sin selección manual inicial", app._manual_use.is_empty())
    app._description.text = "Quiero un PC para diseño"
    app._generate()
    # La clasificación ahora es asíncrona, incluso cuando el servidor no existe.
    for i in range(200):
        if not app._controller._busy:
            break
        await create_timer(0.1).timeout
    await wait_frames(12)
    check("Analizar y generar reconoce diseño", app._current_use == "edicion" and app._equipment.size() == 6)
    check("Perfil claro sin detalles técnicos", "Diseño / Edición" in app._assembly_status.text and "Groq" not in app._assembly_status.text)
    check("Precio reflejado", app._total.text == app._money(app._controller.calcular_total()))
    check("Pantalla torre", app._pages[1].visible)
    if app._equipment.is_empty():
        app.free()
        print("PRUEBA GRÁFICA: ", failures, " fallos; no se generó equipo")
        quit(1)
        return
    capture("torre")
    var initial_angle: float = app._viewer._angle
    app._viewer._angle = 0.52
    app._viewer._update_camera()
    await wait_frames(8)
    capture("torre_angulo_lateral")
    app._viewer._angle = initial_angle
    app._viewer._pitch = -0.08
    app._viewer._update_camera()
    await wait_frames(8)
    capture("torre_angulo_bajo")
    app._viewer._pitch = 0.14
    app._viewer._update_camera()

    var viewer = app._viewer
    var original_id = app._equipment["gpu"]["id"]
    app._detailed_view_toggle.button_pressed = false
    await wait_frames(8)
    var original_board = viewer._assembly_root.get_node("Pieza_motherboard").get_child(-1)
    check("Vista original seleccionable sin cambiar equipo", original_board.scene_file_path == str(app._equipment["motherboard"]["model3d_path"]) and app._equipment["gpu"]["id"] == original_id)
    capture("torre_modelos_originales")
    app._detailed_view_toggle.button_pressed = true
    await wait_frames(8)
    app._generic_gpu_toggle.button_pressed = true
    await wait_frames(12)
    var gpu_body = viewer._assembly_root.get_node("Pieza_gpu")
    var gpu_visual = gpu_body.get_child(gpu_body.get_child_count() - 1)
    check("GPU CC0 instanciada", gpu_visual.scene_file_path == viewer.GPU_CC0)
    check("Vista CC0 no cambia selección", app._equipment["gpu"]["id"] == original_id)
    capture("torre_gpu_cc0")
    app._generic_gpu_toggle.button_pressed = false
    await physics_frame

    # Simula pellizco y comprueba que no abre el catálogo.
    var before_zoom: float = viewer._distance
    touch(viewer, 0, Vector2(110, 120), true)
    touch(viewer, 1, Vector2(210, 120), true)
    var drag = InputEventScreenDrag.new()
    drag.index = 1
    drag.position = Vector2(255, 120)
    drag.relative = Vector2(45, 0)
    viewer._gui_input(drag)
    touch(viewer, 1, drag.position, false)
    touch(viewer, 0, Vector2(110, 120), false)
    check("Pellizco cambia zoom sin seleccionar", viewer._distance < before_zoom and app._pages[1].visible)
    viewer._distance = before_zoom
    viewer._update_camera()
    var before_angle: float = viewer._angle
    touch(viewer, 0, Vector2(110, 120), true)
    drag.index = 0
    drag.position = Vector2(145, 130)
    drag.relative = Vector2(35, 10)
    viewer._gui_input(drag)
    touch(viewer, 0, drag.position, false)
    check("Arrastrar gira sin seleccionar", viewer._angle != before_angle and app._pages[1].visible)
    viewer._angle = before_angle
    viewer._pitch = 0.14
    viewer._update_camera()
    await physics_frame

    # Pulsa el centro proyectado del collider de la GPU usando eventos táctiles.
    gpu_body = viewer._assembly_root.get_node("Pieza_gpu")
    var projected = viewer._camera.unproject_position(gpu_body.global_position)
    var local_point = projected * viewer.size / Vector2(viewer._viewport.size)
    touch(viewer, 0, local_point, true)
    touch(viewer, 0, local_point, false)
    await wait_frames()
    check("Toque selecciona GPU y abre catálogo", app._pages[2].visible and app._selected_part == "gpu")
    capture("catalogo")
    var back_event = InputEventAction.new()
    back_event.action = "ui_cancel"
    back_event.pressed = true
    app._unhandled_input(back_event)
    check("Atrás regresa a la torre", app._pages[1].visible)
    var case_body = viewer._assembly_root.get_node("Pieza_case")
    var frame_x = -1.14 if viewer._detailed_models else -0.95
    var frame_point = viewer._camera.unproject_position(case_body.global_position + Vector3(frame_x, 0.5, 0.5))
    frame_point = frame_point * viewer.size / Vector2(viewer._viewport.size)
    touch(viewer, 0, frame_point, true)
    touch(viewer, 0, frame_point, false)
    await wait_frames()
    check("Marco del chasis seleccionable", app._pages[2].visible and app._selected_part == "case")
    app._set_page(1)
    for kind in ["cpu", "ram", "motherboard", "psu"]:
        var part_body = viewer._assembly_root.get_node("Pieza_" + kind)
        var part_point = viewer._camera.unproject_position(part_body.global_position)
        part_point = part_point * viewer.size / Vector2(viewer._viewport.size)
        touch(viewer, 0, part_point, true)
        touch(viewer, 0, part_point, false)
        await wait_frames()
        check("Selección táctil " + kind, app._pages[2].visible and app._selected_part == kind)
        app._set_page(1)
    app._open_catalog("gpu")
    var alternatives = app._controller.obtener_alternativas("gpu")
    check("Hay alternativas compatibles", not alternatives.is_empty())
    if not alternatives.is_empty():
        var old_total: int = app._controller.calcular_total()
        var expected_total: int = old_total - int(app._equipment["gpu"]["price_cop"]) + int(alternatives[0]["price_cop"])
        app._select_candidate(alternatives[0])
        app._replace()
        await wait_frames()
        check("Reemplazo actualiza selección y precio", app._equipment["gpu"]["id"] == alternatives[0]["id"] and app._controller.calcular_total() == expected_total and app._total.text == app._money(expected_total))
        check("Regreso a torre tras reemplazo", app._pages[1].visible)
        app._show_dashboard()
        check("Dashboard incluye precio y componentes", app._dashboard.visible and "TOTAL:" in app._dashboard.dialog_text and str(alternatives[0]["name"]) in app._dashboard.dialog_text)
        app._dashboard.hide()

    root.size = Vector2i(360, 780)
    app._set_page(0)
    await wait_frames()
    capture("configurador_estrecho")
    check("Interfaz estrecha con desplazamiento", app._pages[0].visible and app._pages[0] is ScrollContainer)
    app.free()
    print("PRUEBA GRÁFICA: ", failures, " fallos")
    quit(1 if failures else 0)
