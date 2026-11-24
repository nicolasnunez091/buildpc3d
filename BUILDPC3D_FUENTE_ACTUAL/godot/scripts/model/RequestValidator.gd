extends RefCounted

const INVALID := "No pudimos identificar una solicitud válida para configurar un computador. Describe para qué necesitas tu PC e inténtalo nuevamente."
const INCOMPLETE := "Cuéntanos para qué utilizarás el computador: estudiar, trabajar, programar, diseñar o jugar."
const EXAMPLE := INVALID

func validate(text: String) -> Dictionary:
	if text.length() > 2000:
		return _result("too_long", "La petición supera los 2000 caracteres.")
	var value = _normalize(text)
	if value.is_empty():
		return _result("empty", "Escribe una petición antes de interpretarla.")
	if _matches(value, "\\b(portatil(?:es)?|laptop|notebook)\\b"):
		return _result("laptop", "BUILDPC3D configura computadores de escritorio, no portátiles.")
	if _matches(value, "\\b(ignora|ignorar|olvida|omite|desobedece|anula)\\b.{0,80}\\b(instrucciones|reglas|filtros|sistema)\\b") \
			or _matches(value, "\\b(cuentame|escribe|escribeme|dime|explica|explicame|hazme)\\b.{0,80}\\b(chiste|cuento|poema|receta|historia|clima)\\b") \
			or _matches(value, "\\b(como (se juega|jugar|instalar|reparar|preparar|preparo)|que (es|significa))\\b") \
			or _matches(value, "\\bno (quiero|necesito|busco|deseo) (un |una |el |la )?(pc|computador(?:a)?|ordenador|equipo)\\b"):
		return _result("invalid", INVALID)
	var computer = _matches(value, "\\b(pc|computador(?:a|es|as)?|ordenador(?:es)?|torre|equipo|computo)\\b")
	var intent = _matches(value, "\\b(necesit\\w*|quier\\w*|busc\\w*|quisiera|gustaria|recomiend\\w*|sugier\\w*|compr\\w*|arm\\w*|mont\\w*|configur\\w*|ayud\\w*|requier\\w*)\\b")
	var digital_action = _matches(value, "\\b(jugar|programar|editar|renderizar|desarrollar|grabar|transmitir|crear|hacer|usar|utilizar|ejecutar|trabajar|estudiar|aprender)\\b")
	var positive = _without_negated_uses(value)
	var school = _matches(positive, "\\b(estudi\\w*|estudiante\\w*|bachillerato|secundaria|noveno|colegio|universidad|universitari\\w*|tareas|clases|medicina|documentos|ofimatica|oficina|excel|word|powerpoint|navegar|internet|hojas de calculo)\\b")
	var games = _matches(positive, "\\b(jugar|juegos?|videojuegos?|gaming|gamer|minecraft|roblox|valorant|fortnite|warzone|gta|god of war)\\b")
	var professional = _matches(positive, "\\b(program\\w*|desarroll\\w*|android studio|emulador\\w*|autocad|blender|render\\w*|disen\\w*|modelad\\w*|animacion|premiere|photoshop|solidworks|ingenieria de sistemas|ingenieria de software)\\b")
	var video = _matches(positive, "\\b(grabar|grabacion|grabando|editar|edicion|crear|hacer|producir|transmitir|transmisiones|streaming)\\b") and _matches(positive, "\\b(video\\w*|contenido|transmisiones|directo|vivo|streaming)\\b")
	var irrelevant = _matches(value, "\\b(pizza|salchipapa|hamburguesa|comer|dormir|paseo|viajar|gato|receta)\\b")
	var purpose = school or games or professional or video
	if irrelevant and not purpose:
		return _result("invalid", INVALID)
	if computer and (intent or _matches(value, "\\b(para|porque|estudi\\w*|colegio)\\b")) and purpose:
		return _accepted(_profile(professional or video, games, school))
	if intent and digital_action and (games or professional or video or _matches(value, "\\b(excel|word|powerpoint|clases virtuales)\\b")):
		return _accepted(_profile(professional or video, games, school))
	if computer and (intent or _matches(value, "\\b(para|porque)\\b")):
		if irrelevant:
			return _result("invalid", INVALID)
		return _result("incomplete", INCOMPLETE)
	if intent and _matches(value, "\\b(trabajar|trabajo|economico|economica)\\b"):
		return _result("incomplete", INCOMPLETE)
	# El contexto informático sin finalidad identificable puede consultarse
	# al servicio, pero el respaldo local no inventará un perfil.
	if intent and _matches(value, "\\b(software|aplicaciones|informatico|informatica)\\b"):
		return {"ok": true, "status": "potential", "message": "", "profile": ""}
	return _result("invalid", INVALID)

func _profile(professional: bool, games: bool, school: bool) -> String:
	if professional: return "edicion"
	if games: return "juegos"
	if school: return "ofimatica"
	return ""

func _accepted(profile: String) -> Dictionary:
	return {"ok": true, "status": "valid", "message": "", "profile": profile}

func _result(status: String, message: String) -> Dictionary:
	return {"ok": false, "status": status, "message": message, "profile": ""}

func _normalize(text: String) -> String:
	var value = text.to_lower().strip_edges()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		value = value.replace(pair[0], pair[1])
	var regex = RegEx.new()
	regex.compile("[^a-z0-9]+")
	return regex.sub(value, " ", true).strip_edges()

func _matches(value: String, pattern: String) -> bool:
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null

func _without_negated_uses(value: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\bno (quiero|necesito|voy a|me interesa|es para) (jugar|juegos|videojuegos|gaming|programar|programacion|editar|edicion|estudiar|estudio)( (minecraft|roblox|valorant|fortnite))?\\b")
	return regex.sub(value, " ", true)
