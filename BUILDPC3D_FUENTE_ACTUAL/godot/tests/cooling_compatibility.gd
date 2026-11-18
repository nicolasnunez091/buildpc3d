extends SceneTree

const CoolingEngine = preload("res://scripts/model/CoolingCompatibility.gd")
var failures = 0

func check(label: String, ok: bool) -> void:
    print(("OK " if ok else "FAIL ") + label)
    if not ok: failures += 1

func _initialize() -> void:
    var engine = CoolingEngine.new()
    var cooler = {"id":"cooler_test","sockets":["AM4"],"height_mm":150,"cooling_type":"air"}
    var cpu = {"id":"cpu_test","socket":"AM4"}
    var board = {"id":"board_test","socket":"AM4"}
    var chassis = {"id":"case_test"}
    # Datos ficticios exclusivamente para comprobar el motor; no autorizan
    # ninguna combinación de productos reales.
    var evidence = {"cases":{"case_test":{"cooler_height_mm":160,"source":"fixture"}}, "boards":{"board_test":{"cooler_test":{"status":"verificada","ram_clear":true,"source":"fixture"}}}, "thermal":{"cpu_test":{"cooler_test":{"status":"orientativa","source":"fixture"}}}}
    var good = engine.evaluate(cooler, cpu, board, chassis, evidence)
    check("Evidencia completa separa montaje y temperatura", good.physical == "verificada" and good.thermal == "orientativa")
    check("Datos ausentes son pendientes", engine.evaluate(cooler, cpu, board, chassis, {}).physical == "pendiente")
    var no_board = evidence.duplicate(true)
    no_board.boards.clear()
    check("Socket y altura no bastan sin placa", engine.evaluate(cooler, cpu, board, chassis, no_board).physical == "pendiente")
    var no_ram = evidence.duplicate(true)
    no_ram.boards.board_test.cooler_test.ram_clear = false
    check("Sin despeje RAM no se afirma montaje", engine.evaluate(cooler, cpu, board, chassis, no_ram).physical == "pendiente")
    var short_case = evidence.duplicate(true)
    short_case.cases.case_test.cooler_height_mm = 140
    check("Altura excedida rechazada", engine.evaluate(cooler, cpu, board, chassis, short_case).physical == "incompatible")
    var wrong_cpu = cpu.duplicate(true)
    wrong_cpu.socket = "AM5"
    check("Socket incompatible rechazado", engine.evaluate(cooler, wrong_cpu, board, chassis, evidence).physical == "incompatible")
    var no_thermal = evidence.duplicate(true)
    no_thermal.thermal.clear()
    check("Montaje no implica suficiencia térmica", engine.evaluate(cooler, cpu, board, chassis, no_thermal).thermal == "pendiente")
    var aio = cooler.duplicate(true)
    aio.cooling_type = "aio"
    check("AIO no se aprueba por altura", engine.evaluate(aio, cpu, board, chassis, evidence).physical == "pendiente")
    print("COMPATIBILIDAD REFRIGERACIÓN: ", failures, " fallos")
    quit(1 if failures else 0)
