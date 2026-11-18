extends RefCounted

# Estimaciones locales, no requisitos oficiales ni garantías de rendimiento.
# Alimenta umbrales orientativos; no sustituye benchmarks ni requisitos oficiales.
func analyze(text: String) -> Dictionary:
	var value = _normalize(text)
	var laptop = _contains_any(value, ["portatil", "laptop", "notebook", "computador portatil"])
	var resolution = ""
	if _contains_any(value, ["4k", "2160p", "uhd"]):
		resolution = "4k"
	elif _contains_any(value, ["1440p", "qhd", "2k"]):
		resolution = "1440p"
	elif _contains_any(value, ["1080p", "full hd", "fhd"]):
		resolution = "1080p"
	var activity = "general"
	var level = 1
	if _contains_any(value, ["blender", "render", "renderizado", "editar video", "edicion de video"]):
		activity = "edicion_render"
		level = 2
		if resolution == "4k" or _contains_any(value, ["complejo", "compleja", "profesional"]):
			level = 3
	elif _contains_any(value, ["android studio", "emuladores", "programar", "programacion"]):
		activity = "desarrollo"
		level = 2
		if _contains_any(value, ["varios emuladores", "muchos emuladores", "multiples emuladores"]):
			level = 3
	elif _contains_any(value, ["jugar", "juego", "gaming", "videojuegos", "roblox", "god of war", "gta 6", "gta vi"]):
		activity = "juegos"
		level = 2
		if value.contains("roblox"):
			level = 1
		if _contains_any(value, ["god of war", "ragnarok"]):
			level = 3
		if _contains_any(value, ["gta 6", "gta vi"]):
			level = 4
	elif _contains_any(value, ["word", "excel", "oficina", "clases virtuales", "navegar"]):
		activity = "oficina"
		level = 1
	if resolution == "1440p" and activity == "juegos":
		level = maxi(level, 3)
	if resolution == "4k" and activity == "juegos":
		level = 4
	if _contains_any(value, ["mejores graficos", "ultra", "streaming", "transmitir", "multitarea"]):
		level = mini(4, maxi(level, 2) + 1)
	var warning = "Estimación orientativa; no garantiza rendimiento ni requisitos oficiales."
	if _contains_any(value, ["gta 6", "gta vi"]):
		warning = "Exigencia estimada; verifica los requisitos oficiales de PC y no se garantiza rendimiento."
	return {
		"actividad": activity,
		"nivel_exigencia": ["basico", "intermedio", "alto", "extremo"][level - 1],
		"resolucion": resolution,
		"portatil": laptop,
		"advertencia": warning,
	}

func _normalize(text: String) -> String:
	var result = text.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		result = result.replace(pair[0], pair[1])
	return result

func _contains_any(value: String, terms: Array) -> bool:
	for term in terms:
		if value.contains(term):
			return true
	return false
