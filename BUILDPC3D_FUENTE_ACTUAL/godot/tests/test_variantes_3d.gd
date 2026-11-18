extends SceneTree

const Viewer = preload("res://scripts/view/PCViewer.gd")
const Recommender = preload("res://scripts/model/Recommender.gd")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(message: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + message)
    if not ok:
        failures += 1

func _run() -> void:
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"]
    var equipment: Dictionary = Recommender.new().generar_equipo_inicial("juegos", catalog)["equipo"]
    var viewer = Viewer.new()
    root.add_child(viewer)
    await process_frame
    check("Mapa explícito de 42 productos", viewer._product_variants.size() == 42)
    for category in Viewer.BODIES:
        var valid = true
        var count = 0
        var signatures = {}
        for part in catalog[category]:
            var variant: Dictionary = viewer._product_variants.get(part["id"], {})
            if variant.is_empty() or variant.get("categoria") != category or not ResourceLoader.exists(str(variant.get("modelo", ""))):
                valid = false
                continue
            var body = viewer._part_body(category, true)
            if not viewer._load_detailed(part, body, category):
                valid = false
            else:
                count += 1
                signatures[str(variant.get("acabado")) + "-" + str(variant.get("variante"))] = true
                if category == "gpu":
                    var expected = int(variant["ventiladores"])
                    for fan in range(1, 4):
                        var mesh = body.find_child("Fan %d blades" % fan, true, false) as MeshInstance3D
                        if mesh == null or mesh.visible != (fan <= expected):
                            valid = false
                    var socket = body.find_child("Power sockets (8-pin)", true, false) as MeshInstance3D
                    if socket == null or socket.visible != (int(part["tdp_w"]) > 75):
                        valid = false
                if category == "case":
                    var bars = 0
                    for child in body.get_children():
                        if str(child.name).begins_with("Detalle_frontal_"):
                            bars += 1
                    if bars != 1 + int(variant["variante"]):
                        valid = false
            body.queue_free()
            await process_frame
        check(category + ": " + str(count) + " variantes instanciadas y diferenciadas", valid and count == catalog[category].size() and signatures.size() == count)
    viewer.mostrar_equipo(equipment)
    await physics_frame
    var chassis = viewer._assembly_root.get_node("Pieza_case")
    var expected_target: Vector3 = chassis.position + viewer._local_bounds(chassis).get_center()
    check("Cámara encuadra el chasis", viewer._camera_target.distance_to(expected_target) < 0.1 and viewer._distance >= 4.3)
    viewer._distance = 5.5
    var slot = viewer._assembly_root.get_node("Pieza_motherboard").find_child("PCIe x16 slot 1", true, false) as MeshInstance3D
    var gpu_aligned = true
    for part in catalog["gpu"]:
        equipment["gpu"] = part
        viewer.mostrar_equipo(equipment)
        var contacts = viewer._assembly_root.get_node("Pieza_gpu").find_child("Gold-finger contacts (x16)", true, false) as MeshInstance3D
        slot = viewer._assembly_root.get_node("Pieza_motherboard").find_child("PCIe x16 slot 1", true, false) as MeshInstance3D
        if contacts == null or slot == null or not (slot.global_transform * slot.get_aabb()).grow(0.01).intersects(contacts.global_transform * contacts.get_aabb()):
            gpu_aligned = false
    check("Contactos de las ocho GPU alcanzan PCIe", gpu_aligned)
    check("Cambio de GPU conserva el zoom elegido", is_equal_approx(viewer._distance, 5.5))
    equipment["gpu"] = catalog["gpu"][0]
    viewer.mostrar_equipo(equipment)
    check("GPU de bajo consumo sin cable auxiliar ilustrativo", viewer._assembly_root.get_node_or_null("Cableado_GPU_referencial") == null)
    viewer.free()
    print("VARIANTES 3D: ", failures, " fallos")
    quit(1 if failures else 0)
