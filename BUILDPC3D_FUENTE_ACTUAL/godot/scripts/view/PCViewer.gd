extends SubViewportContainer
class_name PCViewer

signal pieza_seleccionada(tipo: String)
signal estado_visual_cambiado(mensaje: String)

const BODIES = ["case", "motherboard", "cpu", "ram", "gpu", "psu"]
const GPU_CC0 = "res://assets/models/cc0/graphics-card-light.glb"
const DETAILED_MODELS = {
    "case": "res://assets/models/realismo_cc0/gabinete.glb",
    "motherboard": "res://assets/models/realismo_cc0/placa.glb",
    "gpu": "res://assets/models/realismo_cc0/gpu.glb",
    "ram": "res://assets/models/realismo_cc0/ram.glb",
    "psu": "res://assets/models/realismo_cc0/fuente.glb",
    "cpu": "res://assets/models/realismo_cc0/cpu_refrigerador.glb",
}
# El kit externo está modelado en metros. La misma escala se aplica a todas
# sus piezas; los anclajes colocan los contactos sobre los conectores.
const DETAIL_SCALE = 5.0
const DETAIL_POSITIONS = {
    "case": Vector3(0.0, 1.34, -0.04),
    "motherboard": Vector3(-0.50, 1.72, -0.33),
    "cpu": Vector3(-0.63, 2.14, -0.33),
    "ram": Vector3(-0.30, 2.04, -0.27),
    "gpu": Vector3(-0.34, 1.45, -0.08),
    "psu": Vector3(-0.74, 0.43, -0.05),
}
const SLOTS = {
    "case": {"position": Vector3(0.0, 1.34, -0.04), "size": Vector3(2.28, 2.62, 1.72)},
    "motherboard": {"position": Vector3(-0.28, 1.53, -0.51), "size": Vector3(1.26, 1.58, 0.28)},
    "cpu": {"position": Vector3(-0.51, 1.80, -0.36), "size": Vector3(0.31, 0.31, 0.12)},
    "ram": {"position": Vector3(0.01, 1.83, -0.34), "size": Vector3(0.16, 0.75, 0.24)},
    "gpu": {"position": Vector3(-0.25, 1.34, -0.26), "size": Vector3(1.26, 0.24, 0.46)},
    "psu": {"position": Vector3(-0.24, 0.46, 0.06), "size": Vector3(0.70, 0.47, 0.53)},
    "ssd": {"position": Vector3(0.10, 1.05, -0.30), "size": Vector3(0.50, 0.58, 0.10)}
}
const COLORS = {
    "case": Color("303945"), "motherboard": Color("264a3d"),
    "cpu": Color("b1a6a0"), "ram": Color("b93866"),
    "gpu": Color("2c3540"), "psu": Color("333a42")
}

var _viewport: SubViewport
var _scene: Node3D
var _assembly_root: Node3D
var _camera: Camera3D
var _highlights: Dictionary = {}
var _selected: String = ""
var _angle: float = 0.40
var _pitch: float = 0.14
var _distance: float = 4.75
var _camera_target: Vector3 = Vector3(0.0, 1.31, 0.0)
var _framed_case: String = ""
var _dragging: bool = false
var _did_drag: bool = false
var _last_pointer: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_distance: float = 0.0
var _equipment: Dictionary = {}
var _generic_gpu: bool = false
var _detailed_models: bool = true
var _using_detailed: bool = false
var _detailed_resources: Dictionary = {}
var _product_variants: Dictionary = {}
var _ssd_focus: bool = false
var _saved_camera: Dictionary = {}

func _ready() -> void:
    var variants = JSON.parse_string(FileAccess.get_file_as_string("res://data/variantes_3d.json"))
    if typeof(variants) == TYPE_DICTIONARY and typeof(variants.get("productos")) == TYPE_DICTIONARY:
        _product_variants = variants["productos"]
    stretch = true
    custom_minimum_size.y = maxf(custom_minimum_size.y, 360.0)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _viewport = SubViewport.new()
    _viewport.size = Vector2i(840, 720)
    _viewport.own_world_3d = true
    # La selección se hace al soltar, no al presionar: arrastrar no abre el catálogo.
    _viewport.physics_object_picking = false
    _viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    _viewport.msaa_3d = Viewport.MSAA_2X
    add_child(_viewport)
    _scene = Node3D.new()
    _viewport.add_child(_scene)
    _assembly_root = Node3D.new()
    _scene.add_child(_assembly_root)
    _camera = Camera3D.new()
    _camera.current = true
    _camera.fov = 36.0
    _scene.add_child(_camera)
    _update_camera()

    var key_light = DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-38, -32, 0)
    key_light.light_energy = 1.05
    key_light.shadow_enabled = true
    key_light.shadow_blur = 1.2
    _scene.add_child(key_light)
    var fill = OmniLight3D.new()
    fill.position = Vector3(-1.8, 2.8, 3.0)
    fill.light_color = Color("dce5ff")
    fill.light_energy = 0.75
    fill.omni_range = 7.0
    _scene.add_child(fill)
    var colored = OmniLight3D.new()
    colored.position = Vector3(2.0, 2.1, -1.2)
    colored.light_color = Color("e75b9a")
    colored.light_energy = 0.55
    colored.omni_range = 6.0
    _scene.add_child(colored)
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("0e1019")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b4c1d9")
    env.ambient_light_energy = 0.46
    var sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("555b70")
    sky_material.sky_horizon_color = Color("a3acba")
    sky_material.ground_bottom_color = Color("171a25")
    sky_material.ground_horizon_color = Color("4b4d5a")
    var sky = Sky.new()
    sky.sky_material = sky_material
    env.sky = sky
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 0.95
    var world = WorldEnvironment.new()
    world.environment = env
    _scene.add_child(world)
    _create_display_stage()
    _build_assembly({})

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        accept_event()
        if event.pressed:
            _touches[event.index] = event.position
            if _touches.size() == 1:
                _press_position = event.position
                _did_drag = false
            else:
                _did_drag = true
                _pinch_distance = _touch_distance()
        else:
            if _touches.has(event.index) and _touches.size() == 1 and not _did_drag:
                _pick_at(event.position)
            _touches.erase(event.index)
            _pinch_distance = _touch_distance()
    elif event is InputEventScreenDrag:
        if not _touches.has(event.index):
            return
        accept_event()
        _touches[event.index] = event.position
        if _touches.size() >= 2:
            var next_distance = _touch_distance()
            if _pinch_distance > 1.0 and next_distance > 1.0:
                _distance = clampf(_distance * _pinch_distance / next_distance, 0.45 if _ssd_focus else 3.5, 2.4 if _ssd_focus else 7.5)
                _update_camera()
            _pinch_distance = next_distance
            _did_drag = true
        elif event.position.distance_to(_press_position) > 8.0 or _did_drag:
            _did_drag = true
            _orbit(event.relative)
    elif event is InputEventMouseButton:
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _dragging = true
                _did_drag = false
                _press_position = event.position
                _last_pointer = event.position
            else:
                if _dragging and not _did_drag:
                    _pick_at(event.position)
                _dragging = false
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _distance = maxf(0.45 if _ssd_focus else 3.5, _distance - (0.12 if _ssd_focus else 0.3))
            _update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _distance = minf(2.4 if _ssd_focus else 7.5, _distance + (0.12 if _ssd_focus else 0.3))
            _update_camera()
    elif event is InputEventMouseMotion and _dragging and event.device != InputEvent.DEVICE_ID_EMULATION:
        var movement = event.position - _last_pointer
        _last_pointer = event.position
        if event.position.distance_to(_press_position) > 8.0 or _did_drag:
            _did_drag = true
            _orbit(movement)

func _touch_distance() -> float:
    if _touches.size() < 2:
        return 0.0
    var points = _touches.values()
    return points[0].distance_to(points[1])

func _orbit(movement: Vector2) -> void:
    _angle = _angle - movement.x * 0.008 if _ssd_focus else clampf(_angle - movement.x * 0.008, -0.95, 0.95)
    _pitch = clampf(_pitch + movement.y * 0.006, -1.3 if _ssd_focus else -0.45, 1.3 if _ssd_focus else 0.52)
    _update_camera()

func _pick_at(point: Vector2) -> void:
    # Los cuerpos ocultos conservan su colisión; no seleccionar piezas invisibles.
    if _ssd_focus:
        return
    if size.x <= 0 or size.y <= 0 or _camera == null:
        return
    var viewport_point = point * Vector2(_viewport.size) / size
    var origin = _camera.project_ray_origin(viewport_point)
    var end = origin + _camera.project_ray_normal(viewport_point) * 50.0
    var query = PhysicsRayQueryParameters3D.create(origin, end)
    var world = _camera.get_world_3d()
    if world == null:
        return
    var hit = world.direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var body = hit["collider"]
        if body.has_meta("category"):
            seleccionar(str(body.get_meta("category")))

func _update_camera() -> void:
    if _camera == null: return
    _camera.position = _camera_target + Vector3(sin(_angle) * cos(_pitch), sin(_pitch), cos(_angle) * cos(_pitch)) * _distance
    _camera.look_at(_camera_target, Vector3.UP)

func _frame_case(part: Dictionary) -> void:
    var key = str(part.get("id", "")) + "|" + str(_using_detailed)
    if part.is_empty() or key == _framed_case:
        return
    var body = _assembly_root.get_node_or_null("Pieza_case") as Node3D
    if body == null:
        return
    var bounds = _local_bounds(body)
    if bounds.size.length() < 0.01:
        return
    _framed_case = key
    _camera_target = body.position + bounds.get_center() + Vector3(0, 0.04, 0)
    var aspect = maxf(0.5, float(_viewport.size.x) / float(maxi(_viewport.size.y, 1)))
    var extent = maxf(bounds.size.y, bounds.size.x / aspect)
    var framed_distance = extent / (2.0 * tan(deg_to_rad(_camera.fov) * 0.5)) + bounds.size.z * 0.4
    # Margen para la profundidad del chasis y su proyección en perspectiva
    # cuando la cámara no mira perpendicularmente al lateral.
    _distance = clampf(framed_distance * 1.20, 5.10, 7.5)
    _update_camera()

func _create_display_stage() -> void:
    var podium_mesh = CylinderMesh.new()
    podium_mesh.top_radius = 1.52
    podium_mesh.bottom_radius = 1.56
    podium_mesh.height = 0.10
    podium_mesh.radial_segments = 64
    var podium_material = StandardMaterial3D.new()
    podium_material.albedo_color = Color("20222d")
    podium_material.metallic = 0.38
    podium_material.roughness = 0.58
    var podium = MeshInstance3D.new()
    podium.mesh = podium_mesh
    podium.material_override = podium_material
    podium.position = Vector3(0, 0.06, 0)
    _scene.add_child(podium)
    var ring_mesh = TorusMesh.new()
    ring_mesh.inner_radius = 1.49
    ring_mesh.outer_radius = 1.50
    ring_mesh.rings = 64
    ring_mesh.ring_segments = 8
    var ring_material = StandardMaterial3D.new()
    ring_material.albedo_color = Color("7f244a")
    ring_material.emission_enabled = true
    ring_material.emission = Color("9d2259")
    ring_material.emission_energy_multiplier = 0.28
    ring_material.metallic = 0.3
    ring_material.roughness = 0.4
    var ring = MeshInstance3D.new()
    ring.mesh = ring_mesh
    ring.material_override = ring_material
    ring.position.y = 0.112
    _scene.add_child(ring)

func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var shape = BoxMesh.new()
    shape.size = size
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.08
    material.roughness = 0.72
    var item = MeshInstance3D.new()
    item.mesh = shape
    item.material_override = material
    item.position = position
    parent.add_child(item)
    return item

func _part_body(category: String, detailed: bool = false) -> StaticBody3D:
    var layout: Dictionary = SLOTS[category]
    var body = StaticBody3D.new()
    body.name = "Pieza_" + category
    body.set_meta("category", category)
    body.position = DETAIL_POSITIONS[category] if detailed and DETAIL_POSITIONS.has(category) else layout["position"]
    _assembly_root.add_child(body)
    var collider = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = layout["size"]
    collider.shape = shape
    body.add_child(collider)
    if category == "case":
        # El volumen entero taparía todas las piezas. Solo se recoge el marco.
        collider.disabled = true
        var frame_x = 1.14 if detailed else 0.95
        for x in [-frame_x, frame_x]:
            _case_frame_collider(body, Vector3(x, 0, 0), Vector3(0.15, 2.40, 1.40))
        for y in [-1.16, 1.16]:
            _case_frame_collider(body, Vector3(0, y, 0), Vector3(2.40 if detailed else 2.00, 0.14, 1.40))
    var highlighter = _box(body, Vector3.ZERO, layout["size"] * 1.015, Color(1.0, 0.13, 0.49, 0.085))
    var mat = highlighter.material_override as StandardMaterial3D
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    highlighter.visible = false
    _highlights[category] = highlighter
    return body

func _case_frame_collider(body: StaticBody3D, position: Vector3, size: Vector3) -> void:
    var frame = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    frame.shape = shape
    frame.position = position
    body.add_child(frame)

func _local_bounds(visual: Node3D) -> AABB:
    var first = true
    var result = AABB()
    var meshes = visual.find_children("*", "MeshInstance3D", true, false)
    if visual is MeshInstance3D:
        meshes.append(visual)
    for item in meshes:
        var mesh_instance = item as MeshInstance3D
        if mesh_instance.mesh == null or not mesh_instance.visible: continue
        var aabb = mesh_instance.get_aabb()
        var transform_to_root = visual.global_transform.affine_inverse() * mesh_instance.global_transform
        for ix in [0.0, 1.0]:
            for iy in [0.0, 1.0]:
                for iz in [0.0, 1.0]:
                    var corner = aabb.position + aabb.size * Vector3(ix, iy, iz)
                    var p = transform_to_root * corner
                    if first:
                        result = AABB(p, Vector3.ZERO)
                        first = false
                    else:
                        result = result.expand(p)
    return result

func _restore_vertex_colors(visual: Node3D, original_prototype: bool) -> void:
    # Trimesh exportó COLOR_0 sin material glTF; el importador crea un material
    # blanco que no activa vertex_color_use_as_albedo. No tocar texturas ni
    # compartir las modificaciones con los recursos originales.
    var meshes = visual.find_children("*", "MeshInstance3D", true, false)
    if visual is MeshInstance3D:
        meshes.append(visual)
    var material_cache: Dictionary = {}
    for item in meshes:
        var mesh_instance = item as MeshInstance3D
        if mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var colors = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
            if colors == null or colors.is_empty():
                continue
            var original = mesh_instance.get_active_material(surface)
            if original != null and not original is StandardMaterial3D:
                continue
            if original is StandardMaterial3D and original.vertex_color_use_as_albedo:
                continue
            var key = original.get_instance_id() if original != null else 0
            if not material_cache.has(key):
                var material: StandardMaterial3D = original.duplicate() if original != null else StandardMaterial3D.new()
                material.vertex_color_use_as_albedo = true
                if original == null or (original_prototype and material.albedo_texture == null):
                    material.metallic = 0.08
                    material.roughness = 0.72
                material_cache[key] = material
            mesh_instance.set_surface_override_material(surface, material_cache[key])

func _load_model(part: Dictionary, body: StaticBody3D, category: String) -> bool:
    var path = str(part.get("model3d_path", ""))
    if not path.begins_with("res://assets/models/") or not path.ends_with(".glb"):
        return false
    if not ResourceLoader.exists(path): return false
    var resource = load(path)
    if not (resource is PackedScene): return false
    var instance = (resource as PackedScene).instantiate()
    if not (instance is Node3D):
        instance.free()
        return false
    body.add_child(instance)
    var visual = instance as Node3D
    var source = str(part.get("model3d_source", ""))
    var original_prototype = source.is_empty() or source.begins_with("modelo_referencial_original_")
    _restore_vertex_colors(visual, original_prototype)
    var bounds = _local_bounds(visual)
    if bounds.size.length() < 0.001:
        visual.queue_free()
        return false
    var target: Vector3 = SLOTS[category]["size"] * 0.94
    # Los GLB propios miran al frente (+Z). Para modelos ajenos se permite
    # definir la orientación específica mediante model3d_rotation_deg.
    var angles: Array = part.get("model3d_rotation_deg", [0.0, 0.0, 0.0])
    if angles.size() != 3: angles = [0.0, 0.0, 0.0]
    var rotation_deg = Vector3(float(angles[0]), float(angles[1]), float(angles[2]))
    # Geometría propia: RAM vertical y conectores hacia la placa; GPU
    # perpendicular a la placa, con los ventiladores mirando hacia abajo.
    # Los recursos externos conservan exclusivamente su rotación declarada.
    if original_prototype:
        if category == "ram": rotation_deg += Vector3(0, 90, 90)
        if category == "gpu": rotation_deg.x += 90.0
    var rotation_basis = Basis.from_euler(Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z)))
    var rotated_bounds = AABB()
    var first = true
    for ix in [0.0, 1.0]:
        for iy in [0.0, 1.0]:
            for iz in [0.0, 1.0]:
                var corner = bounds.position + bounds.size * Vector3(ix, iy, iz)
                var oriented = rotation_basis * corner
                if first:
                    rotated_bounds = AABB(oriented, Vector3.ZERO)
                    first = false
                else:
                    rotated_bounds = rotated_bounds.expand(oriented)
    var dimension = rotated_bounds.size
    var factor = minf(target.x / maxf(dimension.x, 0.001), minf(target.y / maxf(dimension.y, 0.001), target.z / maxf(dimension.z, 0.001)))
    visual.rotation_degrees = rotation_deg
    visual.scale = Vector3.ONE * factor
    var adjustment: Array = part.get("model3d_offset", [0.0, 0.0, 0.0])
    if adjustment.size() != 3: adjustment = [0.0, 0.0, 0.0]
    var offset = Vector3(clampf(float(adjustment[0]), -0.15, 0.15), clampf(float(adjustment[1]), -0.15, 0.15), clampf(float(adjustment[2]), -0.15, 0.15))
    visual.position = -(visual.basis * bounds.get_center()) + offset
    if category == "gpu" and original_prototype:
        # Alinear el bracket trasero de las tarjetas cortas y largas; mantener
        # el collider sobre la malla, no sobre el hueco que deja una GPU corta.
        var width = dimension.x * factor
        var shift = (width - target.x) * 0.5
        visual.position.x += shift
        var collider = body.get_child(0) as CollisionShape3D
        var shape = collider.shape as BoxShape3D
        shape.size.x = width + 0.04
        collider.position.x = shift + offset.x
        var highlight: MeshInstance3D = _highlights[category]
        highlight.position.x = collider.position.x
        highlight.scale.x = shape.size.x / float(SLOTS[category]["size"].x)
    return true

func _detail_instance(body: StaticBody3D, path: String, basis: Basis, origin: Vector3,
        hidden_names: Array = [], only_cpu: bool = false) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    if not _detailed_resources.has(path):
        _detailed_resources[path] = load(path)
    var packed = _detailed_resources[path]
    if not packed is PackedScene:
        return null
    var visual = packed.instantiate()
    if not visual is Node3D:
        visual.free()
        return null
    body.add_child(visual)
    visual.transform = Transform3D(basis, origin - body.position)
    for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
        var node_name = str(mesh_node.name).to_lower()
        var is_cpu = "processor package" in node_name or "integrated heat spreader" in node_name
        if only_cpu and not is_cpu:
            mesh_node.visible = false
        elif not only_cpu:
            for hidden_name in hidden_names:
                if str(hidden_name) in node_name:
                    mesh_node.visible = false
                    break
    _restore_vertex_colors(visual, false)
    return visual

func _detail_collider(body: StaticBody3D, visuals: Array) -> void:
    var first = true
    var combined = AABB()
    for visual in visuals:
        if visual == null:
            continue
        var bounds: AABB = visual.transform * _local_bounds(visual)
        if bounds.size.length() < 0.001:
            continue
        combined = bounds if first else combined.merge(bounds)
        first = false
    if first:
        return
    var collider = body.get_child(0) as CollisionShape3D
    var shape = collider.shape as BoxShape3D
    var new_size = combined.size + Vector3(0.035, 0.035, 0.035)
    # La RAM es fina; se amplía ligeramente el área para tocarla en móvil.
    new_size.x = maxf(new_size.x, 0.10)
    shape.size = new_size
    collider.position = combined.get_center()
    var highlight: MeshInstance3D = _highlights[str(body.get_meta("category"))]
    highlight.position = collider.position
    highlight.scale = shape.size / Vector3(SLOTS[str(body.get_meta("category"))]["size"])

func _apply_variant(visual: Node3D, category: String, variant: Dictionary) -> void:
    if visual == null or variant.is_empty():
        return
    var tint = Color(str(variant.get("acabado", "ffffff")))
    var painted_names = {
        "case": ["steel chassis", "front bezel"],
        "motherboard": ["printed circuit board", "vrm heatsink", "chipset and m.2 heatsink", "rear i/o cover"],
        "gpu": ["backplate", "brushed aluminium accents", "shroud"],
        "ram": ["heat spreaders"],
        "psu": ["steel housing"],
        "cpu": ["fan shroud"],
    }
    var count = int(variant.get("ventiladores", 3))
    for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
        var lower = str(mesh_node.name).to_lower()
        if category == "case" and lower.begins_with("front fan "):
            var fan_num = int(lower.trim_prefix("front fan ").left(1))
            if fan_num > int(variant.get("ventiladores_frontales", 3)):
                mesh_node.visible = false
        if category == "ram" and not bool(variant.get("iluminacion", false)) and "rgb light-bar diffuser" in lower:
            mesh_node.visible = false
        if category == "gpu" and count < 3:
            # Para variantes de uno/dos ventiladores se sustituye únicamente
            # la carcasa de tres huecos; las aspas y el disipador siguen siendo PBR.
            if lower == "shroud" or lower == "brushed aluminium accents" or lower == "rgb light strip":
                mesh_node.visible = false
            for fan_num in range(1, 4):
                if lower.begins_with("fan " + str(fan_num) + " "):
                    if fan_num > count:
                        mesh_node.visible = false
                    else:
                        var current_x = [0.061, 0.156, 0.251][fan_num - 1]
                        var desired_x = 0.156 if count == 1 else [0.090, 0.222][fan_num - 1]
                        mesh_node.position.x += desired_x - current_x
        for target in painted_names.get(category, []):
            if str(target) in lower:
                for surface in range(mesh_node.mesh.get_surface_count()):
                    var original = mesh_node.get_active_material(surface)
                    if original is StandardMaterial3D:
                        var material: StandardMaterial3D = original.duplicate()
                        material.albedo_color *= tint
                        mesh_node.set_surface_override_material(surface, material)
                break
    if category == "gpu" and count < 3:
        # Base discreta debajo de las aspas existentes, sin logotipos.
        var housing = _box(visual, Vector3(0.158, 0.027, -0.043), Vector3(0.29, 0.014, 0.115), Color("262a30") * tint)
        housing.name = "Carcasa_generica_%d_ventiladores" % count
    if category == "ram":
        # Ranuras decorativas distintas, sin nombres ni marcas sobre el modelo.
        for rib in range(2 + int(variant.get("variante", 0)) % 3):
            var stripe = _box(visual, Vector3(0.018 + 0.013 * rib, 0.0064, -0.025),
                Vector3(0.003, 0.0006, 0.018), Color("83909e") * tint)
            stripe.name = "Detalle_disipador_%d" % rib
    if category == "motherboard":
        # Acento del protector de E/S: geometría genérica, no una marca.
        var cover = _box(visual, Vector3(0.245, 0.039, -0.229),
            Vector3(0.10, 0.0015, 0.022), Color("777f8c") * tint)
        cover.name = "Acento_disipador_generico"
        for i in range(1 + int(variant.get("variante", 0)) % 4):
            var groove = _box(visual, Vector3(0.205 + i * 0.018, 0.040, -0.229),
                Vector3(0.004, 0.001, 0.020), Color("323845"))
            groove.name = "Ranura_disipador_%d" % i
    visual.set_meta("variante_producto", str(variant.get("variante", "")))

func _load_detailed(part: Dictionary, body: StaticBody3D, category: String) -> bool:
    var variant: Dictionary = _product_variants.get(str(part.get("id", "")), {})
    var model_path = str(variant.get("modelo", DETAILED_MODELS[category]))
    var board_basis = Basis(Vector3.UP, Vector3(0, 0, 1), Vector3.RIGHT).scaled(Vector3.ONE * DETAIL_SCALE)
    var visuals: Array = []
    match category:
        "case":
            var case_basis = Basis(Vector3.UP, deg_to_rad(90)).scaled(Vector3.ONE * DETAIL_SCALE)
            # Lateral y cubierta retirados de forma reversible para una vista de corte.
            visuals.append(_detail_instance(body, model_path, case_basis,
                Vector3(0.0145, 0.111, -0.044), ["tempered glass", "glass frit", "psu shroud"]))
        "motherboard":
            visuals.append(_detail_instance(body, model_path, board_basis,
                Vector3(0.12, 0.96, -0.44), ["socket protective cap"]))
        "cpu":
            var chip_basis = Basis(Vector3.RIGHT, deg_to_rad(90)).scaled(Vector3.ONE * DETAIL_SCALE)
            var socket = Vector3(-0.63, 2.14, -0.36)
            var chip_center = Vector3(-0.058, 0.010, 0.022)
            visuals.append(_detail_instance(body, model_path, chip_basis,
                socket - chip_basis * chip_center, [], true))
            # El mismo GLB contiene CPU y disipador separados: solo se muestra
            # el cooler de esta segunda instancia, fijado encima del zócalo.
            visuals.append(_detail_instance(body, model_path, chip_basis,
                Vector3(-0.77, 2.11, -0.395), ["processor package", "integrated heat spreader"]))
        "ram":
            var ram_basis = Basis(Vector3.UP, Vector3.RIGHT, Vector3(0, 0, -1)).scaled(Vector3.ONE * DETAIL_SCALE)
            var count = 2 if "2x" in str(part.get("name", "")).to_lower() else 1
            var slots = [-0.345, -0.25]
            for i in range(count):
                visuals.append(_detail_instance(body, model_path, ram_basis,
                    Vector3(slots[i] - 0.015, 1.70, -0.381)))
        "gpu":
            # Refleja el eje vertical para instalar ventiladores hacia abajo
            # manteniendo bracket y contactos en sus posiciones físicas.
            var length_ratio = clampf(float(variant.get("longitud_mm", 306)) / 306.0, 0.50, 1.05)
            var gpu_basis = Basis.from_scale(Vector3(DETAIL_SCALE * length_ratio, -DETAIL_SCALE, DETAIL_SCALE))
            var hidden_gpu = ["power socket"] if int(part.get("tdp_w", 100)) <= 75 else []
            visuals.append(_detail_instance(body, model_path, gpu_basis,
                Vector3(-1.10, 1.60, 0.17), hidden_gpu))
        "psu":
            var psu_basis = Basis(Vector3.UP, deg_to_rad(-90)).scaled(Vector3.ONE * DETAIL_SCALE)
            # El asset dice 750 W: se oculta para no atribuir esa cifra al producto elegido.
            visuals.append(_detail_instance(body, model_path, psu_basis,
                Vector3(-0.72, 0.208, -0.04), ["side label"]))
    if visuals.is_empty():
        return false
    for visual in visuals:
        if visual == null:
            for loaded in visuals:
                if loaded != null:
                    loaded.free()
            return false
        _apply_variant(visual, category, variant)
    if category != "case":
        _detail_collider(body, visuals)
    if category == "psu":
        var panel_colors = ["20252b", "42474d", "3b3231", "51545a", "443943"]
        var side_panel = _box(body, Vector3(-0.72, 0.43, 0.343) - body.position,
            Vector3(0.50, 0.22, 0.008), Color(panel_colors[int(variant.get("variante", 0)) % panel_colors.size()]))
        side_panel.name = "Panel_fuente_generico"
        for i in range(int(variant.get("variante", 0)) % 3):
            var stripe = _box(body, Vector3(-0.93 + 0.035 * i, 0.43, 0.349) - body.position,
                Vector3(0.012, 0.19, 0.003), Color("171b22"))
            stripe.name = "Detalle_fuente_%d" % i
        var caption = Label3D.new()
        caption.text = "PSU  /  " + str(int(part.get("watts", 0))) + " W"
        caption.font_size = 30
        caption.pixel_size = 0.0023
        caption.modulate = Color("9ca6b6")
        caption.position = Vector3(-0.72, 0.43, 0.355) - body.position
        body.add_child(caption)
    if category == "cpu" and not variant.is_empty():
        # El disipador es ilustrativo, no una especificación de la CPU.
        var ring = TorusMesh.new()
        ring.inner_radius = 0.192
        ring.outer_radius = 0.225
        ring.rings = 36
        ring.ring_segments = 6
        var trim = MeshInstance3D.new()
        trim.name = "Aro_refrigeracion_ilustrativo"
        trim.mesh = ring
        trim.rotation_degrees.x = 90
        trim.position = Vector3(-0.63, 2.14, -0.120) - body.position
        var finish = StandardMaterial3D.new()
        var accents = ["8b9aab", "d0d4dd", "869a99", "d2c4b7", "ac8d9b", "7c99ad", "aa9db2", "d1b9a3"]
        finish.albedo_color = Color(accents[int(variant.get("variante", 0)) % accents.size()])
        finish.metallic = 0.55
        finish.roughness = 0.42
        trim.material_override = finish
        body.add_child(trim)
    if category == "case" and not variant.is_empty():
        # Cambia la geometría del frente sin desplazar bandeja ni anclajes.
        var n = 1 + int(variant.get("variante", 0))
        for i in range(n):
            var bar = _box(body, Vector3(1.195, 0.78 + i * 0.22, 0.01) - body.position,
                Vector3(0.03, 0.055, 0.75), Color(str(variant["acabado"])) * Color("939ba8"))
            bar.name = "Detalle_frontal_%d" % i
    return true

func _add_reference_cabling(length_ratio: float) -> void:
    # Cableado ilustrativo: sale de los conectores de GPU y entra en el
    # pasacables del chasis. No es una pieza adicional del catálogo.
    var cabling = Node3D.new()
    cabling.name = "Cableado_GPU_referencial"
    _assembly_root.add_child(cabling)
    var socket_x = -1.10 + 1.1275 * length_ratio
    _box(cabling, Vector3(socket_x, 1.53, 0.15), Vector3(0.19 * length_ratio, 0.07, 0.07), Color("121419"))
    var material = StandardMaterial3D.new()
    material.albedo_color = Color("24262c")
    material.roughness = 0.84
    material.metallic = 0.05
    for strand in range(4):
        var offset = (float(strand) - 1.5) * 0.023
        var curve = Curve3D.new()
        curve.bake_interval = 0.035
        var points = [
            Vector3(socket_x + offset, 1.55, 0.17),
            Vector3(lerpf(socket_x, 0.22, 0.45) + offset, 1.67, 0.17),
            Vector3(0.22 + offset, 1.69, 0.08),
            Vector3(0.23 + offset, 1.63, -0.15),
            Vector3(0.21 + offset, 1.57, -0.46),
        ]
        for i in range(points.size()):
            var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]) * 0.22
            curve.add_point(points[i], -tangent, tangent)
        var samples = curve.get_baked_points()
        var rings: Array = []
        for i in range(samples.size()):
            var tangent = (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
            var reference = Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.95 else Vector3.UP
            var normal = tangent.cross(reference).normalized()
            var binormal = tangent.cross(normal).normalized()
            var ring: Array = []
            for side in range(8):
                var angle = TAU * float(side) / 8.0
                var radial = normal * cos(angle) + binormal * sin(angle)
                ring.append([samples[i] + radial * 0.009, radial])
            rings.append(ring)
        var surface = SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(rings.size() - 1):
            for side in range(8):
                var next = (side + 1) % 8
                for vertex in [rings[i][side], rings[i + 1][side], rings[i + 1][next],
                        rings[i][side], rings[i + 1][next], rings[i][next]]:
                    surface.set_normal(vertex[1])
                    surface.add_vertex(vertex[0])
        var wire = MeshInstance3D.new()
        wire.mesh = surface.commit()
        wire.material_override = material
        cabling.add_child(wire)

func _add_ssd(part: Dictionary) -> void:
    if part.is_empty():
        return
    var body = _part_body("ssd")
    body.set_meta("product_id", str(part.get("id", "")))
    var sata = part.get("interface") == "sata"
    # Anclajes educativos aproximados, no ubicaciones de una placa o chasis específico.
    body.position = Vector3(0.48, 1.04, -0.37) if sata else Vector3(-0.36, 1.08, -0.29)
    if sata:
        # Bandeja educativa apoyada en la pared interior, no una bahía del modelo real.
        # Es hermana del SSD para ocultarla al inspeccionar la unidad aislada.
        var tray = Node3D.new()
        tray.name = "Bandeja_SSD_SATA_ilustrativa"
        tray.position = body.position
        _assembly_root.add_child(tray)
        _box(tray, Vector3(0, 0, -0.042), Vector3(0.26, 0.36, 0.06), Color("252a31"))
        _box(body, Vector3.ZERO, Vector3(0.23, 0.33, 0.024), Color("323942"))
        _box(body, Vector3(0, 0.02, 0.013), Vector3(0.16, 0.18, 0.002), Color("626b76"))
        _box(body, Vector3(0, -0.156, 0), Vector3(0.13, 0.018, 0.02), Color("191c22"))
        var highlight: MeshInstance3D = _highlights["ssd"]
        highlight.scale = Vector3(0.24, 0.34, 0.035) / Vector3(SLOTS["ssd"]["size"])
    else:
        _box(body, Vector3.ZERO, Vector3(0.48, 0.13, 0.024), Color("245342"))
        for x in [-0.10, 0.02, 0.14]:
            _box(body, Vector3(x, 0, 0.016), Vector3(0.075, 0.09, 0.012), Color("20242b"))
        _box(body, Vector3(-0.215, 0, 0.015), Vector3(0.035, 0.10, 0.006), Color("b69a57"))
    var collider = body.get_child(0) as CollisionShape3D
    (collider.shape as BoxShape3D).size = Vector3(0.24, 0.34, 0.04) if sata else Vector3(0.50, 0.15, 0.07)

func enfocar_ssd(enabled: bool) -> void:
    if enabled and not _ssd_focus:
        _saved_camera = {"target": _camera_target, "distance": _distance, "angle": _angle, "pitch": _pitch}
    _ssd_focus = enabled
    _apply_ssd_focus()

func _apply_ssd_focus() -> void:
    if _assembly_root == null:
        return
    var body = _assembly_root.get_node_or_null("Pieza_ssd") as Node3D
    for child in _assembly_root.get_children():
        if child is Node3D:
            child.visible = not _ssd_focus or child == body
    if _ssd_focus and body != null:
        _camera_target = body.position
        _distance = 0.85 if _equipment.get("ssd", {}).get("interface") == "sata" else 1.20
        _angle = 0.0
        _pitch = 0.0
        estado_visual_cambiado.emit("SSD: geometría genérica educativa; montaje aproximado, no reproducción del producto.")
    elif not _ssd_focus and not _saved_camera.is_empty():
        _camera_target = _saved_camera["target"]
        _distance = _saved_camera["distance"]
        _angle = _saved_camera["angle"]
        _pitch = _saved_camera["pitch"]
        _saved_camera.clear()
        estado_visual_cambiado.emit("Ensamblaje educativo: posición SSD aproximada; refrigerador ilustrativo no incluido en el precio.")
    _update_camera()

func _build_assembly(assembly: Dictionary) -> void:
    for child in _assembly_root.get_children():
        child.free()
    _highlights.clear()
    _using_detailed = _detailed_models and not assembly.is_empty()
    var custom_model = false
    for category in BODIES:
        var selected: Dictionary = assembly.get(category, {})
        var selected_source = str(selected.get("model3d_source", ""))
        if selected.is_empty() or (not selected_source.is_empty() and not selected_source.begins_with("modelo_referencial_original_")):
            _using_detailed = false
            if not selected.is_empty():
                custom_model = true
    if custom_model and _detailed_models:
        estado_visual_cambiado.emit("Modelo importado detectado: se conserva la vista original para respetar sus anclajes.")
    elif _using_detailed:
        estado_visual_cambiado.emit("Geometría genérica. El refrigerador ilustrado no se incluye en el precio.")
    elif not assembly.is_empty():
        estado_visual_cambiado.emit("Vista de los modelos del catálogo. Las piezas pueden ser ilustrativas.")
    for category in BODIES:
        var part: Dictionary = assembly.get(category, {}).duplicate(true)
        var detailed = _using_detailed
        var body = _part_body(category, detailed)
        if category == "gpu" and _generic_gpu and not part.is_empty():
            part["model3d_path"] = GPU_CC0
            part["model3d_source"] = "https://grab3d.com/models/electronics/graphics-card/"
            part["model3d_rotation_deg"] = [0.0, 0.0, 0.0]
            part["model3d_offset"] = [0.0, 0.0, 0.0]
            if detailed:
                body.position = Vector3(-0.65, 1.50, -0.17)
        var loaded = false
        if detailed and not (category == "gpu" and _generic_gpu):
            loaded = _load_detailed(part, body, category)
        if not loaded:
            loaded = _load_model(part, body, category)
        if not loaded:
            var size: Vector3 = SLOTS[category]["size"] * 0.85
            if category == "case":
                # Sólo fondo y marcos; el frente queda abierto para mirar el interior.
                _box(body, Vector3(0, 0, -size.z * 0.49), Vector3(size.x, size.y, 0.055), COLORS[category])
                _box(body, Vector3(0, -size.y * 0.49, 0), Vector3(size.x, 0.06, size.z), COLORS[category])
                _box(body, Vector3(0, size.y * 0.49, 0), Vector3(size.x, 0.06, size.z), COLORS[category])
            else:
                _box(body, Vector3.ZERO, size, COLORS[category])
    if _using_detailed and not _generic_gpu and assembly.has("gpu") and assembly.has("case"):
        var gpu_source = str(assembly["gpu"].get("model3d_source", ""))
        var case_source = str(assembly["case"].get("model3d_source", ""))
        if gpu_source.begins_with("modelo_referencial_original_") and case_source.begins_with("modelo_referencial_original_") \
                and int(assembly["gpu"].get("tdp_w", 100)) > 75:
            var variant: Dictionary = _product_variants.get(str(assembly["gpu"].get("id", "")), {})
            _add_reference_cabling(clampf(float(variant.get("longitud_mm", 306)) / 306.0, 0.50, 1.05))
    _add_ssd(assembly.get("ssd", {}))
    if not _ssd_focus:
        _frame_case(assembly.get("case", {}))
    _apply_ssd_focus()

func mostrar_equipo(equipo: Dictionary) -> void:
    _equipment = equipo.duplicate(true)
    _build_assembly(_equipment)
    for category in _highlights:
        var node: MeshInstance3D = _highlights[category]
        node.visible = category == _selected and category != "case"

func usar_gpu_generica(enabled: bool) -> void:
    _generic_gpu = enabled
    if not _equipment.is_empty():
        mostrar_equipo(_equipment)

func usar_modelos_detallados(enabled: bool) -> void:
    _detailed_models = enabled
    if not _equipment.is_empty():
        mostrar_equipo(_equipment)

func seleccionar(category: String) -> void:
    _selected = category
    for key in _highlights:
        var item: MeshInstance3D = _highlights[key]
        item.visible = key == category and key != "case"
    pieza_seleccionada.emit(category)
