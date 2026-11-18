extends SceneTree

const Analyzer = preload("res://scripts/model/DemandAnalyzer.gd")
const Recommender = preload("res://scripts/model/Recommender.gd")
const Controller = preload("res://scripts/controller/PCController.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	var dao = preload("res://scripts/model/CatalogDAO.gd").new()
	var catalog = dao._with_local_ssd(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"])
	dao.free()
	var analyzer = Analyzer.new()
	var recommender = Recommender.new()
	var basic = recommender.generar_equipo_inicial("juegos", catalog, analyzer.analyze("Quiero jugar Roblox"))
	var high = recommender.generar_equipo_inicial("juegos", catalog, analyzer.analyze("God of War Ragnarök con buenos gráficos a 1440p"))
	var extreme = recommender.generar_equipo_inicial("juegos", catalog, analyzer.analyze("Quiero jugar GTA 6 con los mejores gráficos"))
	check("Tres niveles producen equipos compatibles", basic.get("ok", false) and high.get("ok", false) and extreme.get("ok", false) and recommender.es_equipo_compatible(basic.get("equipo", {})) and recommender.es_equipo_compatible(high.get("equipo", {})) and recommender.es_equipo_compatible(extreme.get("equipo", {})))
	if basic.get("ok", false) and high.get("ok", false) and extreme.get("ok", false):
		check("Mayor exigencia modifica RAM y GPU", int(basic.equipo.ram.capacity_gb) < int(high.equipo.ram.capacity_gb) and int(basic.equipo.gpu.vram_gb) < int(high.equipo.gpu.vram_gb) and int(high.equipo.gpu.vram_gb) < int(extreme.equipo.gpu.vram_gb))
	var develop = recommender.generar_equipo_inicial("edicion", catalog, analyzer.analyze("Android Studio con varios emuladores"))
	check("Emuladores priorizan núcleos y memoria", develop.get("ok", false) and int(develop.get("equipo", {}).get("ram", {}).get("capacity_gb", 0)) >= 32)
	var blender = recommender.generar_equipo_inicial("edicion", catalog, analyzer.analyze("Blender y renderizado 4K"))
	var office = recommender.generar_equipo_inicial("ofimatica", catalog, analyzer.analyze("Oficina y Excel"))
	check("Oficina genera SSD", office.get("ok", false) and office.equipo.has("ssd"))
	check("Gaming alto prefiere SSD de 1 TB o más", high.get("ok", false) and int(high.equipo.ssd.capacity_gb) >= 1000)
	check("Gaming extremo prefiere SSD de 2 TB o más", extreme.get("ok", false) and int(extreme.equipo.ssd.capacity_gb) >= 2000)
	check("Desarrollo prefiere NVMe de 1 TB o más", develop.get("ok", false) and develop.equipo.ssd.interface == "nvme_pcie" and int(develop.equipo.ssd.capacity_gb) >= 1000)
	check("Render 4K prefiere NVMe de 2 TB o más", blender.get("ok", false) and blender.equipo.ssd.interface == "nvme_pcie" and int(blender.equipo.ssd.capacity_gb) >= 2000)
	var local = Controller.new()
	check("Respaldo local reconoce Roblox y Android Studio", local.clasificar_texto_local("Roblox") == "juegos" and local.clasificar_texto_local("Android Studio y emuladores") == "edicion")
	var details = local._validated_details({"nivel_exigencia": "alto", "actividad": "juegos", "resolucion": "1440p", "id": "no_confiable"})
	check("Detalles remotos validados sin ID", details.get("nivel_exigencia") == "alto" and not details.has("id"))
	check("Detalles remotos inválidos rechazados", local._validated_details({"nivel_exigencia": "inventado", "actividad": "juegos", "resolucion": "4k"}).is_empty())
	local.free()
	print("RECOMENDACIÓN POR EXIGENCIA: ", failures, " fallos")
	quit(1 if failures else 0)
