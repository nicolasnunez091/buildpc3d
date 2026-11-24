extends RefCounted
class_name Recommender

const REQUIRED = ["cpu", "motherboard", "ram", "gpu", "psu", "case", "ssd"]
const SSD_EXTENSION = "res://data/ssd_extension.json"
const COMPATIBILITY_DATA = "res://data/compatibility_specs.json"
var _spec_cache: Dictionary = {}
var _spec_loaded: bool = false

func _extra_specs(part: Dictionary) -> Dictionary:
    if not _spec_loaded:
        var data = JSON.parse_string(FileAccess.get_file_as_string(COMPATIBILITY_DATA))
        if typeof(data) == TYPE_DICTIONARY:
            _spec_cache = data
        _spec_loaded = true
    var group = _spec_cache.get(_category(part), {})
    if typeof(group) != TYPE_DICTIONARY:
        return {}
    var record = group.get(str(part.get("id", "")), {})
    return record if typeof(record) == TYPE_DICTIONARY else {}

func _nonnegative_integer(value) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
        and float(value) >= 0 and float(value) <= 100000 and floor(float(value)) == float(value)

# Estos estados solo cubren los datos indicados, no son garantía de montaje.
# Solo los fixtures sin ID usan campos directos; el catálogo usa datos locales.
func evaluar_adicional(a: Dictionary, b: Dictionary) -> Dictionary:
    var ta = _category(a)
    var tb = _category(b)
    if (ta == "gpu" and tb == "psu") or (ta == "psu" and tb == "gpu"):
        var gpu = a if ta == "gpu" else b
        var psu = b if ta == "gpu" else a
        var gs = _extra_specs(gpu).duplicate(true)
        var ps = _extra_specs(psu).duplicate(true)
        if str(gpu.get("id", "")).is_empty(): gs.merge(gpu, true)
        if str(psu.get("id", "")).is_empty(): ps.merge(psu, true)
        var required = gs.get("pcie_8pin_required")
        var available = ps.get("pcie_8pin_available")
        if not _nonnegative_integer(required) or not _nonnegative_integer(available):
            return {"estado":"pendiente", "detalle":"Conectores GPU–fuente sin verificar para el modelo exacto."}
        if int(required) > int(available):
            return {"estado":"incompatible", "detalle":"Faltan conectores PCIe de 8 pines."}
        return {"estado":"compatible", "detalle":"Cantidad de conectores PCIe de 8 pines compatible; revisar cables y adaptadores."}
    if (ta == "psu" and tb == "case") or (ta == "case" and tb == "psu"):
        var psu = a if ta == "psu" else b
        var chassis = b if ta == "psu" else a
        var ps = _extra_specs(psu).duplicate(true)
        var cs = _extra_specs(chassis).duplicate(true)
        if str(psu.get("id", "")).is_empty(): ps.merge(psu, true)
        if str(chassis.get("id", "")).is_empty(): cs.merge(chassis, true)
        var format = ps.get("psu_format")
        var formats = cs.get("psu_formats")
        var length = ps.get("psu_length_mm")
        var limit = cs.get("psu_max_length_mm")
        if typeof(format) != TYPE_STRING or str(format).is_empty() or typeof(formats) != TYPE_ARRAY or formats.is_empty():
            return {"estado":"pendiente", "detalle":"Formato o montaje de fuente–chasis sin verificar."}
        for item in formats:
            if typeof(item) != TYPE_STRING or item.strip_edges().is_empty():
                return {"estado":"pendiente", "detalle":"Formato de chasis malformado; verificar montaje."}
        if format not in formats:
            return {"estado":"incompatible", "detalle":"El formato de fuente no está admitido por el chasis."}
        if not _nonnegative_integer(length) or not _nonnegative_integer(limit) or int(length) == 0 or int(limit) == 0:
            return {"estado":"pendiente", "detalle":"Espacio o longitud de fuente sin verificar."}
        if int(length) > int(limit):
            return {"estado":"incompatible", "detalle":"La fuente excede la longitud admitida."}
        var unconditional = cs.get("psu_unconditional_length_mm")
        if _nonnegative_integer(unconditional) and int(unconditional) > 0 and int(length) > int(unconditional):
            return {"estado":"pendiente", "detalle":"El montaje puede requerir retirar la jaula de discos; verifica la configuración del chasis."}
        return {"estado":"compatible", "detalle":"Formato y longitud de fuente compatibles según datos disponibles."}
    if (ta == "cpu" and tb == "motherboard") or (ta == "motherboard" and tb == "cpu"):
        var cpu = a if ta == "cpu" else b
        var board = b if ta == "cpu" else a
        var cpu_socket = str(cpu.get("socket", ""))
        var board_socket = str(board.get("socket", ""))
        if cpu_socket.is_empty() or board_socket.is_empty():
            return {"estado":"pendiente", "detalle":"Socket de CPU o placa sin verificar."}
        if cpu_socket != board_socket:
            return {"estado":"incompatible", "detalle":"Los sockets no coinciden."}
        return {"estado":"pendiente", "detalle":"Verifica CPU, chipset, revisión y versión de BIOS en la lista del fabricante."}
    return {"estado":"pendiente", "detalle":"No existe una regla adicional para este par."}

func son_compatibles(a: Dictionary, b: Dictionary) -> bool:
    var ta = _category(a)
    var tb = _category(b)
    if (ta == "gpu" and tb == "psu") or (ta == "psu" and tb == "gpu") \
            or (ta == "psu" and tb == "case") or (ta == "case" and tb == "psu"):
        return evaluar_adicional(a, b)["estado"] == "compatible"
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
        if evaluar_adicional(a, b)["estado"] == "incompatible":
            return false
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
        and fuente_suficiente(equipo, equipo["psu"]) \
        and evaluar_adicional(equipo["gpu"], equipo["psu"])["estado"] != "incompatible" \
        and evaluar_adicional(equipo["psu"], equipo["case"])["estado"] != "incompatible"

func advertencias_compatibilidad(equipo: Dictionary) -> Array:
    var warnings: Array = []
    for pair in [["cpu", "motherboard"], ["gpu", "psu"], ["psu", "case"]]:
        var a = equipo.get(pair[0])
        var b = equipo.get(pair[1])
        if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
            continue
        var evaluation = evaluar_adicional(a, b)
        if evaluation["estado"] != "compatible":
            warnings.append(str(evaluation["detalle"]))
    return warnings

func calcular_valor_total(equipo: Dictionary) -> int:
    var total = 0
    for component_type in REQUIRED:
        var part = equipo.get(component_type, {})
        if typeof(part) != TYPE_DICTIONARY:
            continue
        var price = part.get("price_cop")
        if typeof(price) not in [TYPE_INT, TYPE_FLOAT]:
            continue
        var amount = float(price)
        if not is_finite(amount) or amount <= 0 or amount > 1000000000000.0 or floor(amount) != amount:
            continue
        total += int(amount)
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
