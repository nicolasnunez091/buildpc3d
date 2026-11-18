extends SceneTree

const Analyzer = preload("res://scripts/model/DemandAnalyzer.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	var analyzer = Analyzer.new()
	for case in [
		["Quiero jugar Roblox", "juegos", "basico"],
		["God of War Ragnarök a 1440p", "juegos", "alto"],
		["Quiero GTA 6 con los mejores gráficos", "juegos", "extremo"],
		["Word, Excel y clases virtuales", "oficina", "basico"],
		["Android Studio con varios emuladores", "desarrollo", "alto"],
		["Blender y renderizado complejo en 4K", "edicion_render", "alto"],
	]:
		var result = analyzer.analyze(case[0])
		check(case[0], result.actividad == case[1] and result.nivel_exigencia == case[2])
	check("Portátil detectado", analyzer.analyze("Quiero un portátil").portatil)
	check("Escritorio no es portátil", not analyzer.analyze("Quiero un computador de escritorio").portatil)
	check("4K supera 1080p", analyzer.analyze("jugar 4K").nivel_exigencia == "extremo" and analyzer.analyze("jugar 1080p").nivel_exigencia == "intermedio")
	print("ANÁLISIS LOCAL EXPERIMENTAL: ", failures, " fallos")
	quit(1 if failures else 0)
