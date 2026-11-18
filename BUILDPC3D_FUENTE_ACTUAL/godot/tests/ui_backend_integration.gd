extends SceneTree

# Backend Python real en localhost; Groq se simula. No requiere credenciales.
const Main = preload("res://scenes/Main.tscn")
var failures = 0

func _initialize() -> void:
    call_deferred("_run")

func check(message: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + message)
    if not ok:
        failures += 1

func _run() -> void:
    var app = Main.instantiate()
    root.add_child(app)
    for i in range(5):
        await process_frame
    # Inyección en memoria: no se modifica app_config.json.
    app._ai_service_url_override = "http://127.0.0.1:18941/interpretar"
    app._description.text = "Quiero un computador para diseño gráfico"
    app._request_ai()
    await app._controller.ia_resuelta
    check("Interpretación llega a la vista", app._current_use == "edicion" and "Diseño / Edición" in app._home_status.text)
    app._description.text = "Necesito una PC para jugar Valorant"
    app._generate()
    await app._controller.ia_resuelta
    await process_frame
    check("Analizar y generar usa perfil recibido", app._current_use == "juegos" and app._equipment.size() == 6 and app._pages[1].visible)
    check("El recomendador calculó el precio", app._total.text == app._money(app._controller.calcular_total()))
    app.free()
    print("UI Y BACKEND SIMULADO: ", failures, " fallos")
    quit(1 if failures else 0)
