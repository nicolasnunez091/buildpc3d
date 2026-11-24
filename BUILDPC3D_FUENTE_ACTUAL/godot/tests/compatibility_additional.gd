extends SceneTree

const REC = preload("res://scripts/model/Recommender.gd")
var failures := 0

func check(label: String, actual: String, expected: String) -> void:
	var ok = actual == expected
	print(("OK " if ok else "FAIL ") + label + ": " + actual + " esperado=" + expected)
	if not ok:
		failures += 1

func _initialize() -> void:
	var rec = REC.new()
	var gpu = {"type":"gpu", "pcie_8pin_required":2}
	var psu = {"type":"psu", "pcie_8pin_available":2, "psu_format":"ATX", "psu_length_mm":140}
	var box = {"type":"case", "psu_formats":["ATX"], "psu_max_length_mm":180}
	check("GPU sintética compatible", rec.evaluar_adicional(gpu, psu).estado, "compatible")
	gpu.pcie_8pin_required = 3
	check("GPU sintética incompatible", rec.evaluar_adicional(gpu, psu).estado, "incompatible")
	gpu.pcie_8pin_required = "desconocido"
	check("GPU malformada", rec.evaluar_adicional(gpu, psu).estado, "pendiente")
	check("Fuente sintética compatible", rec.evaluar_adicional(psu, box).estado, "compatible")
	psu.psu_length_mm = 200
	check("Fuente sintética larga", rec.evaluar_adicional(psu, box).estado, "incompatible")
	psu.psu_length_mm = null
	check("Fuente longitud desconocida", rec.evaluar_adicional(psu, box).estado, "pendiente")
	box.psu_formats = [null]
	check("Formato malformado", rec.evaluar_adicional(psu, box).estado, "pendiente")
	var cpu = {"type":"cpu", "id":"test", "socket":"AM4"}
	var board = {"type":"motherboard", "socket":"AM5"}
	check("Socket distinto", rec.evaluar_adicional(cpu, board).estado, "incompatible")
	board.socket = "AM4"
	board.cpu_support = {"test":{"supported":true, "bios_confirmed":true}}
	check("BIOS sin evidencia confiable", rec.evaluar_adicional(cpu, board).estado, "pendiente")
	var commercial_psu = {"id":"psu_msi_mag_a650bn_650w_80_bronze"}
	var commercial_case = {"id":"case_chasis_corsair_4000d_airflow_mid_tower"}
	check("MSI A650BN y Corsair 4000D", rec.evaluar_adicional(commercial_psu, commercial_case).estado, "compatible")
	print("COMPATIBILIDAD ADICIONAL: fallos=", failures)
	quit(1 if failures else 0)
