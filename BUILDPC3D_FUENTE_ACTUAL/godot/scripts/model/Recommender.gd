extends RefCounted
class_name Recommender

const REQUIRED = ["cpu", "motherboard", "ram", "gpu", "psu", "case", "ssd"]
const SSD_EXTENSION = "res://data/ssd_extension.json"

func son_compatibles(a: Dictionary, b: Dictionary) -> bool:
    var ta = _category(a)
    var tb = _category(b)
    if ta == "ssd" and tb == "motherboard" or ta == "motherboard" and tb == "ssd":
        var drive = a if ta == "ssd" else b
        var board = b if ta == "ssd" else a
        var extension = JSON.parse_string(FileAccess.get_file_as_string(SSD_EXTENSION))
        if typeof(extension) != TYPE_DICTIONARY:
            return false
        var metadata = extension.get("motherboards", {}).get(str(board.get("id", "")), {})
        if drive.get("interface") == "nvme_pcie" and drive.get("form_factor") == "m2_2280":
            return metadata.get("nvme_m2_2280", false) == true
        if drive.get("interface") == "sata" and drive.get("form_factor") == "2.5":
            return metadata.get("sata", false) == true
        return false
    if ta == "ssd" and tb == "case" or ta == "case" and tb == "ssd":
        var drive = a if ta == "ssd" else b
        var chassis = b if ta == "ssd" else a
        if drive.get("interface") == "nvme_pcie" and drive.get("form_factor") == "m2_2280":
            return true
        if drive.get("interface") == "sata" and drive.get("form_factor") == "2.5":
            var extension = JSON.parse_string(FileAccess.get_file_as_string(SSD_EXTENSION))
            if typeof(extension) == TYPE_DICTIONARY:
                return extension.get("cases", {}).get(str(chassis.get("id", "")), {}).get("bay_25", false) == true
        return false
    if ta == "cpu" and tb == "motherboard" or ta == "motherboard" and tb == "cpu":
        var cpu = a if ta == "cpu" else b
        var motherboard = b if ta == "cpu" else a
        if str(cpu.get("socket", "")).is_empty() or str(motherboard.get("ram_type", "")).is_empty() \
                or str(cpu.get("socket", "")) != str(motherboard.get("socket", "")):
            return false
        if cpu.has("ram_types"):
            return str(motherboard.get("ram_type", "")) in cpu.get("ram_types", [])
        return str(cpu.get("ram_type", "")) == str(motherboard.get("ram_type", ""))
    if ta == "ram" and tb == "motherboard" or ta == "motherboard" and tb == "ram":
        return not str(a.get("ram_type", "")).is_empty() and str(a.get("ram_type", "")) == str(b.get("ram_type", ""))
    if ta == "gpu" and tb == "case" or ta == "case" and tb == "gpu":
        var gpu = a if ta == "gpu" else b
        var chassis = b if ta == "gpu" else a
        var length = int(gpu.get("length_mm", 0))
        var clearance = int(chassis.get("max_gpu_mm", 0))
        return length > 0 and clearance > 0 and length <= clearance
    if ta == "motherboard" and tb == "case" or ta == "case" and tb == "motherboard":
        var motherboard = a if ta == "motherboard" else b
        var chassis = b if ta == "motherboard" else a
        var factor = str(motherboard.get("form_factor", ""))
        return not factor.is_empty() and factor in chassis.get("form_factors", [])
    return true

func _category(item: Dictionary) -> String:
    if item.has("type"):
        return str(item["type"])
    var id_string = str(item.get("id", ""))
    if id_string.begins_with("cpu_"): return "cpu"
    if id_string.begins_with("mb_") or id_string.begins_with("motherboard_"): return "motherboard"
    if id_string.begins_with("ram_"): return "ram"
    if id_string.begins_with("gpu_"): return "gpu"
    if id_string.begins_with("psu_"): return "psu"
    if id_string.begins_with("case_"): return "case"
    return str(item.get("type", ""))

func consumo_equipo(equipo: Dictionary) -> int:
    return int(equipo.get("cpu", {}).get("tdp_w", 0)) + int(equipo.get("motherboard", {}).get("power_w", 0)) + int(equipo.get("ram", {}).get("power_w", 0)) + int(equipo.get("gpu", {}).get("tdp_w", 0)) + 40

func fuente_suficiente(equipo: Dictionary, fuente: Dictionary) -> bool:
    for requirement in [["cpu", "tdp_w"], ["motherboard", "power_w"], ["ram", "power_w"], ["gpu", "tdp_w"]]:
        var part = equipo.get(requirement[0], {})
        if typeof(part) != TYPE_DICTIONARY or int(part.get(requirement[1], 0)) <= 0:
            return false
    return int(fuente.get("watts", 0)) >= int(ceil(float(consumo_equipo(equipo)) * 1.2))

func es_equipo_compatible(equipo: Dictionary) -> bool:
    for component_type in REQUIRED:
        if not equipo.has(component_type) or typeof(equipo[component_type]) != TYPE_DICTIONARY:
            return false
    return son_compatibles(equipo["cpu"], equipo["motherboard"]) \
        and son_compatibles(equipo["motherboard"], equipo["ram"]) \
        and son_compatibles(equipo["gpu"], equipo["case"]) \
        and son_compatibles(equipo["motherboard"], equipo["case"]) \
        and son_compatibles(equipo["motherboard"], equipo["ssd"]) \
        and son_compatibles(equipo["case"], equipo["ssd"]) \
        and fuente_suficiente(equipo, equipo["psu"])

func calcular_valor_total(equipo: Dictionary) -> int:
    var total = 0
    for component_type in REQUIRED:
        total += int(equipo.get(component_type, {}).get("price_cop", 0))
    return total

func generar_equipo_inicial(uso: String, catalogo: Dictionary, demanda: Dictionary = {}) -> Dictionary:
    var filter = UseFilter.new()
    var candidates = filter.filtrar_por_uso(uso, catalogo, demanda)
    if candidates.is_empty():
        return {"ok": false, "mensaje": "El uso indicado no existe."}
    for component_type in REQUIRED:
        if candidates.get(component_type, []).is_empty():
            return {"ok": false, "mensaje": "No hay piezas suficientes de tipo: " + str(UseFilter.LABELS[component_type])}
    for cpu in candidates["cpu"]:
        for mb in candidates["motherboard"]:
            if not son_compatibles(cpu, mb): continue
            for ram in candidates["ram"]:
                if not son_compatibles(mb, ram): continue
                for gpu in candidates["gpu"]:
                    for chassis in candidates["case"]:
                        if not son_compatibles(gpu, chassis) or not son_compatibles(mb, chassis): continue
                        for psu in candidates["psu"]:
                            for ssd in candidates["ssd"]:
                                var assembly = {"cpu": cpu, "motherboard": mb, "ram": ram, "gpu": gpu, "psu": psu, "case": chassis, "ssd": ssd}
                                if es_equipo_compatible(assembly):
                                    return {"ok": true, "equipo": assembly.duplicate(true), "total": calcular_valor_total(assembly)}
    return {"ok": false, "mensaje": "No se encontró un equipo compatible con los mínimos del uso."}

func obtener_alternativas(equipo: Dictionary, component_type: String, catalogo: Dictionary) -> Array:
    var result: Array = []
    if not REQUIRED.has(component_type) or not es_equipo_compatible(equipo):
        return result
    for candidate in catalogo.get(component_type, []):
        if str(candidate.get("id", "")) == str(equipo[component_type].get("id", "")): continue
        var trial: Dictionary = equipo.duplicate(true)
        trial[component_type] = candidate
        if not es_equipo_compatible(trial): continue
        result.append(candidate)
    result.sort_custom(func(a, b): return int(a["price_cop"]) < int(b["price_cop"]))
    return result

func reemplazar_pieza(equipo: Dictionary, component_type: String, candidate: Dictionary, catalogo: Dictionary) -> Dictionary:
    for alternative in obtener_alternativas(equipo, component_type, catalogo):
        if str(alternative.get("id", "")) == str(candidate.get("id", "")):
            var updated: Dictionary = equipo.duplicate(true)
            updated[component_type] = alternative
            return {"ok": true, "equipo": updated, "total": calcular_valor_total(updated)}
    return {"ok": false, "mensaje": "La pieza no es una alternativa válida y compatible."}
