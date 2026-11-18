extends SceneTree

# Prueba real: pulsa la señal del botón existente y usa el backend configurado.
# Puede consumir cuota de Groq; no registra texto ni cabeceras.
const MAIN = preload("res://scenes/Main.tscn")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(description: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + description)
    if not ok:
        failures += 1

func _run() -> void:
    var app = MAIN.instantiate()
    root.add_child(app)
    # Aislar cualquier caché que el DAO pudiera crear durante la prueba.
    app._dao._cache_path = "user://groq-button-test-" + str(Time.get_ticks_usec()) + ".json"
    for i in range(5):
        await process_frame
    var config = JSON.parse_string(FileAccess.get_file_as_string("res://config/app_config.json"))
    check("URL local configurada", typeof(config) == TYPE_DICTIONARY and config.get("ai_service_url") == "http://127.0.0.1:8000/interpretar")
    var state = {"resolved": false, "ok": false, "use": "", "http_received": false, "http": 0, "result": -1, "source": ""}
    app._controller.ia_resuelta.connect(func(ok, _message, use):
        state["resolved"] = true
        state["ok"] = ok
        state["use"] = use if use in ["juegos", "edicion", "ofimatica"] else ""
    )
    app._controller._http.request_completed.connect(func(result, code, _headers, body):
        state["http_received"] = true
        state["result"] = result
        state["http"] = code
        var parsed = JSON.parse_string(body.get_string_from_utf8())
        if typeof(parsed) == TYPE_DICTIONARY and parsed.get("fuente") in ["groq", "local"]:
            state["source"] = parsed["fuente"]
    )
    app._description.text = "Necesito un computador para editar videos profesionalmente y hacer renderizados 3D."
    app._ai_button.emit_signal("pressed")
    var deadline = Time.get_ticks_msec() + 25000
    while (not state["resolved"] or (app._controller._busy and not state["http_received"])) and Time.get_ticks_msec() < deadline:
        await create_timer(0.1).timeout
    await process_frame
    print("PRUEBA BOTÓN: HTTP=", state["http"], "; resultado=", state["result"],
        "; fuente_respuesta=", state["source"], "; fuente_controlador=", app._controller._last_source,
        "; perfil=", state["use"])
    check("Botón envió petición HTTP", state["http_received"] and state["result"] == HTTPRequest.RESULT_SUCCESS)
    check("Backend devolvió Groq", state["http"] == 200 and state["source"] == "groq" and app._controller._last_source == "groq")
    check("Vista aplicó edición", state["resolved"] and state["ok"] and state["use"] == "edicion" and app._current_use == "edicion")
    app.free()
    print("GROQ REAL DESDE BOTÓN SIMULADO: ", failures, " fallos")
    quit(1 if failures else 0)
