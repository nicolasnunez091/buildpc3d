extends SceneTree

const Viewer = preload("res://scripts/view/PCViewer.gd")
const DAO = preload("res://scripts/model/CatalogDAO.gd")
const Rec = preload("res://scripts/model/Recommender.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + label)
    if not ok: failures += 1

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dao = DAO.new()
    var catalog = dao._with_local_ssd(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"])
    var team = Rec.new().generar_equipo_inicial("juegos", catalog).equipo
    var viewer = Viewer.new()
    root.add_child(viewer)
    await process_frame
    var start = Time.get_ticks_msec()
    var all_unique = true
    var light = true
    for ssd in catalog.ssd:
        team["ssd"] = ssd
        viewer.mostrar_equipo(team)
        var body = viewer._assembly_root.get_node_or_null("Pieza_ssd")
        var matches = viewer._assembly_root.find_children("Pieza_ssd", "StaticBody3D", true, false)
        all_unique = all_unique and body != null and matches.size() == 1 and body.get_meta("product_id") == ssd.id
        light = light and body.find_children("*", "MeshInstance3D", true, false).size() <= 7
    var elapsed = Time.get_ticks_msec() - start
    check("Diez modelos seleccionables sin duplicados", all_unique)
    check("Geometría ligera: máximo siete mallas por SSD", light)
    check("Sustituciones terminan sin bloqueo", elapsed < 30000)
    print("Tiempo de diez reconstrucciones en este equipo: ", elapsed, " ms (no mide FPS Android)")
    var old_target = viewer._camera_target
    var old_distance = viewer._distance
    viewer.enfocar_ssd(true)
    var body = viewer._assembly_root.get_node("Pieza_ssd")
    check("Inspección aísla y enfoca SSD", body.visible and not viewer._assembly_root.get_node("Pieza_case").visible and viewer._camera_target == body.position)
    var initial_angle = viewer._angle
    viewer._orbit(Vector2(60, 20))
    check("Giro disponible al inspeccionar", viewer._angle != initial_angle)
    var wheel = InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    var distance = viewer._distance
    viewer._gui_input(wheel)
    check("Zoom disponible al inspeccionar", viewer._distance < distance)
    team.ssd = catalog.ssd[0]
    viewer.mostrar_equipo(team)
    check("Reemplazo durante inspección conserva aislamiento", viewer._assembly_root.get_node("Pieza_ssd").get_meta("product_id") == team.ssd.id and not viewer._assembly_root.get_node("Pieza_case").visible)
    var tray = viewer._assembly_root.get_node_or_null("Bandeja_SSD_SATA_ilustrativa")
    var sata_body = viewer._assembly_root.get_node("Pieza_ssd")
    var sata_shape = (sata_body.get_child(0) as CollisionShape3D).shape as BoxShape3D
    check("Bandeja SATA oculta en inspección", tray != null and not tray.visible)
    check("Proporción y tamaño SATA", sata_shape.size.x < 0.3 and sata_shape.size.y < 0.4 and absf(sata_shape.size.x / sata_shape.size.y - 0.70) < 0.05)
    viewer.enfocar_ssd(false)
    check("Regreso restaura ensamblaje y cámara", viewer._assembly_root.get_node("Pieza_case").visible and viewer._camera_target == old_target and viewer._distance == old_distance)
    check("SATA apoyado en bandeja visible", tray.visible and tray.position == sata_body.position and absf(sata_body.position.z - (-0.37)) < 0.001)
    team.ssd = catalog.ssd[1]
    viewer.mostrar_equipo(team)
    check("NVMe elimina bandeja SATA", viewer._assembly_root.get_node_or_null("Bandeja_SSD_SATA_ilustrativa") == null and viewer._assembly_root.get_node("Pieza_ssd").get_meta("product_id") == team.ssd.id)
    viewer.free()
    dao.free()
    print("VISOR SSD: ", failures, " fallos")
    quit(1 if failures else 0)
