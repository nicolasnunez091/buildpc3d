extends SceneTree

const FilterScript = preload("res://scripts/model/UseFilter.gd")
const RecommenderScript = preload("res://scripts/model/Recommender.gd")
const DAOScript = preload("res://scripts/model/CatalogDAO.gd")
const ControllerScript = preload("res://scripts/controller/PCController.gd")
const ViewerScript = preload("res://scripts/view/PCViewer.gd")

var passed = 0
var failed = 0
var filter = FilterScript.new()
var rec = RecommenderScript.new()
var catalog: Dictionary = {}

func _initialize() -> void:
    call_deferred("run_all")

func check(case_id: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("OK ", case_id)
    else:
        failed += 1
        push_error("FAIL " + case_id)

func run_all() -> void:
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
    var catalog_dao = DAOScript.new()
    catalog = catalog_dao._with_local_ssd(data["catalog"])
    catalog_dao.free()
    check("CP001", filter.obtener_usos().size() == 3)
    check("CP002", filter.uso_valido("juegos"))
    check("CP003", filter.uso_valido("juegos"))
    check("CP004", not filter.uso_valido("xyz"))
    check("CP005", not filter.uso_valido(""))
    var games = filter.filtrar_por_uso("juegos", catalog)
    check("CP006", games.size() == 7 and games["cpu"].size() > 0 and games["gpu"].size() > 0)
    var all_gpu_sufficient = true
    for candidate in games["gpu"]:
        if int(candidate["vram_gb"]) < 8: all_gpu_sufficient = false
    check("CP007", all_gpu_sufficient)
    check("CP008", filter.filtrar_por_uso("no_existe", catalog).is_empty())
    var cpu_am5: Dictionary = {}
    var mb_am4: Dictionary = {}
    var mb_am5: Dictionary = {}
    for cpu in catalog["cpu"]:
        if cpu["socket"] == "AM5":
            cpu_am5 = cpu
            break
    for board in catalog["motherboard"]:
        if board["socket"] == "AM4":
            mb_am4 = board
        if board["socket"] == "AM5":
            mb_am5 = board
    check("CP009", not rec.son_compatibles(cpu_am5, mb_am4))
    check("CP010", rec.son_compatibles(cpu_am5, mb_am5))
    var ddr4_ram: Dictionary = {}
    for stick in catalog["ram"]:
        if stick["ram_type"] == "DDR4":
            ddr4_ram = stick
            break
    check("CP011", not rec.son_compatibles(mb_am5, ddr4_ram))
    check("CP012", not rec.fuente_suficiente({"cpu": {"tdp_w": 250}, "motherboard": {"power_w": 100}, "ram": {"power_w": 10}, "gpu": {"tdp_w": 150}}, {"watts": 450}))
    check("CP013", not rec.son_compatibles({"id": "gpu_large", "length_mm": 340}, {"id": "case_small", "max_gpu_mm": 300}))
    check("Faltan dimensiones: no asumir compatibilidad", not rec.son_compatibles({"id": "gpu_incomplete"}, {"id": "case_small", "max_gpu_mm": 300}))
    check("Falta socket: no asumir compatibilidad", not rec.son_compatibles({"id": "cpu_a", "ram_types": ["DDR4"]}, {"id": "motherboard_a", "ram_type": "DDR4"}))
    check("Falta potencia: no asumir fuente suficiente", not rec.fuente_suficiente({"cpu": {"tdp_w": 65}}, {"watts": 1000}))
    var generated = rec.generar_equipo_inicial("juegos", catalog)
    var team = generated.get("equipo", {})
    check("CP014", generated.get("ok", false) and rec.es_equipo_compatible(team) and team.size() == 7)
    var office = rec.generar_equipo_inicial("ofimatica", catalog)
    check("CP015 equipo compatible sin presupuesto", office.get("ok", false) and rec.es_equipo_compatible(office.get("equipo", {})))
    var without_case = catalog.duplicate(true)
    without_case["case"] = []
    check("CP016", not rec.generar_equipo_inicial("juegos", without_case).get("ok", false))
    var sum_team = {
        "cpu": {"price_cop": 800000}, "motherboard": {"price_cop": 600000}, "ram": {"price_cop": 300000},
        "gpu": {"price_cop": 900000}, "psu": {"price_cop": 250000}, "case": {"price_cop": 200000}
    }
    check("CP017", rec.calcular_valor_total(sum_team) == 3050000)
    sum_team["ram"] = {"price_cop": 350000}
    check("CP018", rec.calcular_valor_total(sum_team) == 3100000)
    var mobo_options = rec.obtener_alternativas(team, "motherboard", catalog)
    var only_motherboards = true
    for part in mobo_options:
        if str(part.get("type", "")) != "motherboard": only_motherboards = false
    check("CP019", only_motherboards)
    var ram_options = rec.obtener_alternativas(team, "ram", catalog)
    var only_right_type = true
    for part in ram_options:
        if str(part["ram_type"]) != str(team["motherboard"]["ram_type"]): only_right_type = false
    check("CP020", only_right_type)
    var replacement_type = "gpu"
    var replacements = rec.obtener_alternativas(team, replacement_type, catalog)
    if replacements.is_empty():
        replacement_type = "psu"
        replacements = rec.obtener_alternativas(team, replacement_type, catalog)
    var replace = {"ok": false}
    if not replacements.is_empty():
        replace = rec.reemplazar_pieza(team, replacement_type, replacements[0], catalog)
    check("CP021", replace.get("ok", false) and rec.es_equipo_compatible(replace.get("equipo", {})) and team[replacement_type]["id"] != replace.get("equipo", {}).get(replacement_type, {}).get("id", ""))
    var invalid = rec.reemplazar_pieza(team, "gpu", {"id": "gpu_invalid"}, catalog)
    check("CP022", not invalid.get("ok", false) and rec.es_equipo_compatible(team))
    # CP023 y CP024 se ejecutan en firestore_http_integration.gd con un
    # servidor REST simulado, sin modificar un proyecto Firebase real.
    var classifier = ControllerScript.new()
    check("Texto juegos", classifier.clasificar_texto_local("Quiero jugar Fortnite y Valorant") == "juegos")
    check("Texto edición", classifier.clasificar_texto_local("Editar videos en Premiere") == "edicion")
    check("Texto oficina", classifier.clasificar_texto_local("Estudiar y usar Excel") == "ofimatica")
    check("Texto desconocido", classifier.clasificar_texto_local("sdnuaidun fscsad") == "")
    for phrase in ["Quiero un PC para diseño", "diseno", "PROGRAMACIÓN", "programacion", "edición", "renderizado"]:
        check("Texto " + phrase, classifier.clasificar_texto_local(phrase) == "edicion")
    for phrase in ["videojuegos", "jugar", "gaming"]:
        check("Texto " + phrase, classifier.clasificar_texto_local(phrase) == "juegos")
    for phrase in ["ofimática", "ofimatica", "estudio"]:
        check("Texto " + phrase, classifier.clasificar_texto_local(phrase) == "ofimatica")
    check("Prioridad usos mixtos", classifier.clasificar_texto_local("estudio videojuegos y diseño") == "edicion")
    check("Alias gaming", classifier.establecer_uso_manual("gaming"))
    check("Alias oficina", classifier.establecer_uso_manual("oficina"))
    check("Alias con tilde", classifier.procesar_respuesta_ia({"uso": "EDICIÓN"}))
    check("Respuesta sin uso", not classifier.procesar_respuesta_ia({"uso": 42}))
    var outcomes: Array = []
    classifier.ia_resuelta.connect(func(ok, message, use): outcomes.append([ok, message, use]))
    classifier._last_text = "quiero un PC para diseño"
    classifier._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"uso":"edición","fuente":"groq"}'.to_utf8_buffer())
    check("HTTP Groq válido", outcomes.back()[0] and outcomes.back()[2] == "edicion" and classifier._last_source == "groq")
    classifier._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"uso":"ofimatica","fuente":"local"}'.to_utf8_buffer())
    check("HTTP identifica respaldo", outcomes.back()[0] and classifier._last_source == "local")
    classifier._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), 'no json'.to_utf8_buffer())
    check("HTTP JSON inválido usa respaldo", outcomes.back()[0] and outcomes.back()[2] == "edicion" and classifier._last_source == "local")
    classifier._on_ai_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
    check("HTTP desconectado usa respaldo", outcomes.back()[0] and outcomes.back()[2] == "edicion" and classifier._last_source == "local")
    classifier._last_text = "sin coincidencias"
    classifier._on_ai_completed(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), PackedByteArray())
    check("HTTP error sin coincidencia solicita selección", not outcomes.back()[0])
    classifier.establecer_catalogo(catalog)
    var edit_team = classifier.generar_inicial("edicion")
    var edit_alternatives = classifier.obtener_alternativas("gpu")
    var profile_kept = true
    for candidate in edit_alternatives:
        if int(candidate.get("vram_gb", 0)) < 8:
            profile_kept = false
    check("Alternativas respetan mínimos del perfil", edit_team.get("ok", false) and not edit_alternatives.is_empty() and profile_kept)
    var low_gpu: Dictionary = {}
    for candidate in catalog["gpu"]:
        if int(candidate.get("vram_gb", 0)) < 8:
            low_gpu = candidate
            break
    check("No permite reemplazo por GPU bajo mínimo", not low_gpu.is_empty() and not classifier.reemplazar("gpu", low_gpu).get("ok", false))
    var valid_models = true
    for group in catalog:
        if group == "ssd": continue
        for item in catalog[group]:
            if not ResourceLoader.exists(str(item.get("model3d_path", ""))):
                valid_models = false
    check("42 GLB importados", valid_models)
    var decode = DAOScript.new()
    check("DAO decode", decode._decode_value({"integerValue": "2"}) == 2 and decode._decode_value({"arrayValue": {"values": [{"stringValue": "ATX"}]}})[0] == "ATX")
    check("DAO acepta catálogo local completo", decode._catalog_is_valid(catalog))
    var broken_catalog = catalog.duplicate(true)
    broken_catalog["gpu"][0].erase("length_mm")
    check("DAO rechaza catálogo incompleto", not decode._catalog_is_valid(broken_catalog))
    decode._catalog = catalog.duplicate(true)
    decode._remote_catalog = broken_catalog
    decode._incoming_version = 99
    decode._finish_download()
    check("DAO conserva catálogo anterior ante datos incompletos", decode._catalog["gpu"][0].has("length_mm") and decode._version != 99)
    var dao_errors: Array = []
    decode.error_catalogo.connect(func(message): dao_errors.append(message))
    decode._step = "meta"
    decode._on_http_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "no json".to_utf8_buffer())
    check("DAO controla JSON remoto inválido", not dao_errors.is_empty() and decode._step.is_empty())
    var valid_combos = 0
    for profile in filter.obtener_usos():
        var built = rec.generar_equipo_inicial(profile, catalog)
        if built.get("ok", false) and rec.es_equipo_compatible(built["equipo"]): valid_combos += 1
    check("Todos los perfiles", valid_combos == 3)
    # Batería complementaria de 30 combinaciones reales de CPU+placa.
    var compat_checks = 0
    var all_correct = true
    for cpu in catalog["cpu"]:
        for board in catalog["motherboard"]:
            var expected = cpu["socket"] == board["socket"] and board["ram_type"] in cpu["ram_types"]
            if rec.son_compatibles(cpu, board) != expected: all_correct = false
            compat_checks += 1
    for gpu in catalog["gpu"]:
        var chassis = catalog["case"][0]
        if rec.son_compatibles(gpu, chassis) != (int(gpu["length_mm"]) <= int(chassis["max_gpu_mm"])):
            all_correct = false
        compat_checks += 1
    check("Batería de compatibilidad", compat_checks >= 30 and all_correct)
    # Instanciar cada GLB en el mismo visor que utiliza la aplicación.
    var viewer = ViewerScript.new()
    root.add_child(viewer)
    await process_frame
    var loaded_count = 0
    var colors_ok = true
    var textures_preserved = 0
    var fit_ok = true
    var aligned_gpu = true
    var world_bounds_by_type: Dictionary = {}
    for group in catalog:
        if group == "ssd": continue
        world_bounds_by_type[group] = []
        for part in catalog[group]:
            var body = viewer._part_body(group)
            if viewer._load_model(part, body, group):
                loaded_count += 1
                var visual: Node3D = body.get_child(body.get_child_count() - 1)
                var bounds: AABB = visual.transform * viewer._local_bounds(visual)
                var target: Vector3 = ViewerScript.SLOTS[group]["size"]
                if bounds.size.x > target.x + 0.001 or bounds.size.y > target.y + 0.001 or bounds.size.z > target.z + 0.001:
                    fit_ok = false
                bounds.position += body.position
                world_bounds_by_type[group].append(bounds)
                if group == "gpu":
                    var expected_left: float = ViewerScript.SLOTS["gpu"]["position"].x - target.x * 0.94 / 2.0
                    if absf(bounds.position.x - expected_left) > 0.001:
                        aligned_gpu = false
                for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
                    for surface in range(mesh_node.mesh.get_surface_count()):
                        var arrays = mesh_node.mesh.surface_get_arrays(surface)
                        var active = mesh_node.get_active_material(surface)
                        if arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty():
                            if not active is StandardMaterial3D or not active.vertex_color_use_as_albedo:
                                colors_ok = false
                        elif active is StandardMaterial3D and active.albedo_texture != null:
                            if mesh_node.get_surface_override_material(surface) == null:
                                textures_preserved += 1
            body.free()
    check("42 GLB instanciados en visor", loaded_count == 42)
    check("Materiales con colores por vértice activos", colors_ok)
    check("Texturas originales conservadas", textures_preserved >= 42)
    check("Geometría contenida en anclajes", fit_ok)
    check("GPU cortas y largas alineadas", aligned_gpu)
    var case_fit = true
    for chassis: AABB in world_bounds_by_type["case"]:
        for group in ["motherboard", "cpu", "ram", "gpu", "psu"]:
            for part_bounds: AABB in world_bounds_by_type[group]:
                for axis in range(3):
                    if part_bounds.position[axis] < chassis.position[axis] - 0.001 or part_bounds.end[axis] > chassis.end[axis] + 0.001:
                        case_fit = false
    check("Piezas dentro de la envolvente de cada gabinete", case_fit)
    var separation_ok = true
    var mounted = ["cpu", "ram", "gpu", "psu"]
    for i in range(mounted.size()):
        for j in range(i + 1, mounted.size()):
            for first: AABB in world_bounds_by_type[mounted[i]]:
                for second: AABB in world_bounds_by_type[mounted[j]]:
                    if first.intersects(second):
                        separation_ok = false
    check("CPU, RAM, GPU y fuente sin intersección de envolventes", separation_ok)
    check("GPU externa CC0 importada", ResourceLoader.exists(ViewerScript.GPU_CC0))
    viewer.free()
    classifier.free()
    decode.free()
    print("RESUMEN: ", passed, " aprobadas, ", failed, " fallidas. CP023/024: prueba HTTP separada.")
    quit(1 if failed > 0 else 0)
