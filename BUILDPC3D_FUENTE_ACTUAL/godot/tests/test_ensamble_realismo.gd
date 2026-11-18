extends SceneTree

const ViewerScript = preload("res://scripts/view/PCViewer.gd")
const RecommenderScript = preload("res://scripts/model/Recommender.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func bounds_of(body: Node3D, viewer: PCViewer) -> AABB:
    var bounds = AABB()
    var first = true
    for child in body.get_children():
        if child is Node3D and not child.scene_file_path.is_empty():
            var local: AABB = child.transform * viewer._local_bounds(child)
            local.position += body.position
            bounds = local if first else bounds.merge(local)
            first = false
    return bounds

func mesh_bounds(mesh: MeshInstance3D) -> AABB:
    return mesh.global_transform * mesh.get_aabb()

func _run() -> void:
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
    var dao = preload("res://scripts/model/CatalogDAO.gd").new()
    var catalog: Dictionary = dao._with_local_ssd(data["catalog"])
    dao.free()
    var recommendation = RecommenderScript.new().generar_equipo_inicial("juegos", catalog)
    var equipment: Dictionary = recommendation["equipo"]
    var viewer = ViewerScript.new()
    root.add_child(viewer)
    await process_frame
    viewer.mostrar_equipo(equipment)
    await physics_frame
    var bodies: Dictionary = {}
    var bounds: Dictionary = {}
    for kind in ViewerScript.BODIES:
        bodies[kind] = viewer._assembly_root.get_node("Pieza_" + kind)
        bounds[kind] = bounds_of(bodies[kind], viewer)
        check("Modelo detallado " + kind, bounds[kind].size.length() > 0.01)
    for kind in ["motherboard", "cpu", "ram", "gpu", "psu"]:
        var inside = true
        for axis in range(3):
            if bounds[kind].position[axis] < bounds["case"].position[axis] - 0.015 \
                    or bounds[kind].end[axis] > bounds["case"].end[axis] + 0.015:
                inside = false
        check(kind + " dentro de la torre", inside)
    for pair in [["cpu", "ram"], ["cpu", "gpu"], ["ram", "gpu"], ["gpu", "psu"]]:
        check("Sin intersección " + pair[0] + "/" + pair[1], not bounds[pair[0]].intersects(bounds[pair[1]]))
    var standoffs = bodies["case"].find_child("Motherboard standoffs (ATX pattern)", true, false) as MeshInstance3D
    var pcb = bodies["motherboard"].find_child("Printed circuit board", true, false) as MeshInstance3D
    check("Placa sobre separadores", standoffs != null and pcb != null and mesh_bounds(standoffs).grow(0.01).intersects(mesh_bounds(pcb)))
    var slot = bodies["motherboard"].find_child("PCIe x16 slot 1", true, false) as MeshInstance3D
    var contacts = bodies["gpu"].find_child("Gold-finger contacts (x16)", true, false) as MeshInstance3D
    check("GPU conectada al PCIe", slot != null and contacts != null and mesh_bounds(slot).grow(0.01).intersects(mesh_bounds(contacts)))
    var memory_slot = bodies["motherboard"].find_child("DIMM slot A2", true, false) as MeshInstance3D
    var memory_contacts = bodies["ram"].find_child("Gold-finger contacts (288)", true, false) as MeshInstance3D
    check("RAM conectada al DIMM", memory_slot != null and memory_contacts != null and mesh_bounds(memory_slot).grow(0.01).intersects(mesh_bounds(memory_contacts)))
    var cabling = viewer._assembly_root.get_node_or_null("Cableado_GPU_referencial")
    var sockets = bodies["gpu"].find_child("Power sockets (8-pin)", true, false) as MeshInstance3D
    var cable_plug = cabling.get_child(0) as MeshInstance3D if cabling != null else null
    check("Cable de GPU en conector", sockets != null and cable_plug != null and mesh_bounds(sockets).intersects(mesh_bounds(cable_plug)))
    check("Fuente apoyada en el compartimento", absf(bounds["psu"].position.y - 0.208) < 0.01)
    var glass = bodies["case"].find_child("Tempered glass side panel", true, false) as MeshInstance3D
    check("Vista de corte sin lateral opaco", glass != null and not glass.visible)
    var fan_visible = false
    for fan in bodies["cpu"].find_children("Fan shroud", "MeshInstance3D", true, false):
        if fan.visible:
            fan_visible = true
    check("Disipador visible sobre CPU", fan_visible)
    var found_correct_watts = false
    for child in bodies["psu"].get_children():
        if child is Label3D and str(int(equipment["psu"]["watts"])) in child.text:
            found_correct_watts = true
    check("Fuente rotulada con el vataje elegido", found_correct_watts)
    var ram_instances = 0
    for child in bodies["ram"].get_children():
        if child.scene_file_path == ViewerScript.DETAILED_MODELS["ram"]:
            ram_instances += 1
    check("Kit RAM con dos módulos", ram_instances == 2)
    var one_stick: Dictionary = equipment.duplicate(true)
    one_stick["ram"] = catalog["ram"][0]
    viewer.mostrar_equipo(one_stick)
    var single_count = 0
    for child in viewer._assembly_root.get_node("Pieza_ram").get_children():
        if child.scene_file_path == ViewerScript.DETAILED_MODELS["ram"]:
            single_count += 1
    check("RAM individual con un módulo", single_count == 1)
    viewer.usar_modelos_detallados(false)
    var originals_intact = true
    for kind in ViewerScript.BODIES:
        var original = viewer._assembly_root.get_node("Pieza_" + kind).get_child(-1)
        if original.scene_file_path != str(one_stick[kind]["model3d_path"]):
            originals_intact = false
    check("Vista original reversible", originals_intact)
    viewer.usar_modelos_detallados(true)
    check("Equipo intacto al cambiar vista", viewer._equipment["gpu"]["id"] == equipment["gpu"]["id"])
    var imported = equipment.duplicate(true)
    imported["cpu"]["model3d_source"] = "archivo_importado_por_usuario"
    viewer.mostrar_equipo(imported)
    var preserved = viewer._assembly_root.get_node("Pieza_motherboard").get_child(-1)
    check("Modelo importado conserva anclajes originales", not viewer._using_detailed and preserved.scene_file_path == str(imported["motherboard"]["model3d_path"]))
    viewer.free()
    print("ENSAMBLE DETALLADO: ", failures, " fallos")
    quit(1 if failures else 0)
