extends SceneTree

const PATHS = [
    "res://assets/models/realismo_cc0/gabinete.glb",
    "res://assets/models/realismo_cc0/placa.glb",
    "res://assets/models/realismo_cc0/gpu.glb",
    "res://assets/models/realismo_cc0/ram.glb",
    "res://assets/models/realismo_cc0/fuente.glb",
    "res://assets/models/realismo_cc0/cpu_refrigerador.glb",
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures = 0
    for path in PATHS:
        var packed = load(path)
        if not packed is PackedScene:
            push_error("No se importó " + path)
            failures += 1
            continue
        var model = packed.instantiate()
        root.add_child(model)
        var meshes = model.find_children("*", "MeshInstance3D", true, false)
        var textured = 0
        var normals = 0
        var emissive = 0
        for mesh_node in meshes:
            for surface in range(mesh_node.mesh.get_surface_count()):
                var material = mesh_node.get_active_material(surface)
                if material is BaseMaterial3D:
                    if material.albedo_texture != null: textured += 1
                    if material.normal_enabled and material.normal_texture != null: normals += 1
                    if material.emission_enabled: emissive += 1
            var lower = str(mesh_node.name).to_lower()
            if "glass" in lower or "shroud" in lower or "processor" in lower or "heat_spreader" in lower:
                print("  NODO ", mesh_node.name)
        print(path.get_file(), " mallas=", meshes.size(), " texturas=", textured, " normales=", normals, " emisivos=", emissive)
        if meshes.is_empty() or textured == 0 or normals == 0:
            failures += 1
        model.free()
    print("MODELOS PBR: ", failures, " fallos")
    quit(1 if failures else 0)
