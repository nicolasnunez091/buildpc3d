extends RefCounted
class_name UseFilter

const TYPES = ["cpu", "motherboard", "ram", "gpu", "psu", "case", "ssd"]
const LABELS = {
    "cpu": "Procesador", "motherboard": "Placa madre", "ram": "Memoria RAM",
    "gpu": "Tarjeta gráfica", "psu": "Fuente de poder", "case": "Chasis", "ssd": "Almacenamiento SSD"
}
const PROFILES = {
    "ofimatica": {"cpu_cores": 4, "ram_gb": 8, "gpu_vram_gb": 2},
    "juegos": {"cpu_cores": 6, "ram_gb": 16, "gpu_vram_gb": 8},
    "edicion": {"cpu_cores": 8, "ram_gb": 32, "gpu_vram_gb": 8}
}
# Umbrales orientativos provisionales, no benchmarks ni requisitos oficiales.
const DEMAND_MINIMUMS = {
    "basico": {"cpu_cores": 4, "ram_gb": 8, "gpu_vram_gb": 2},
    "intermedio": {"cpu_cores": 6, "ram_gb": 16, "gpu_vram_gb": 4},
    "alto": {"cpu_cores": 8, "ram_gb": 32, "gpu_vram_gb": 8},
    "extremo": {"cpu_cores": 8, "ram_gb": 32, "gpu_vram_gb": 12}
}

func obtener_usos() -> Array:
    return ["ofimatica", "juegos", "edicion"]

func uso_valido(uso: String) -> bool:
    return PROFILES.has(uso)

func filtrar_por_uso(uso: String, catalogo: Dictionary, demanda: Dictionary = {}) -> Dictionary:
    if not uso_valido(uso):
        return {}
    var level = str(demanda.get("nivel_exigencia", ""))
    var profile: Dictionary = PROFILES[uso].duplicate()
    if DEMAND_MINIMUMS.has(level):
        profile = DEMAND_MINIMUMS[level].duplicate()
        # Emuladores priorizan memoria y CPU; no implican GPU profesional.
        if demanda.get("actividad", "") == "desarrollo":
            profile["gpu_vram_gb"] = 2
    var candidates: Dictionary = {}
    for component_type in TYPES:
        var allowed: Array = []
        var source: Array = catalogo.get(component_type, [])
        for item in source:
            if typeof(item) != TYPE_DICTIONARY:
                continue
            if not item.has("id") or not item.has("price_cop"):
                continue
            if component_type == "cpu" and int(item.get("cores", 0)) < int(profile["cpu_cores"]):
                continue
            if component_type == "ram" and int(item.get("capacity_gb", 0)) < int(profile["ram_gb"]):
                continue
            if component_type == "gpu" and int(item.get("vram_gb", 0)) < int(profile["gpu_vram_gb"]):
                continue
            allowed.append(item)
        if component_type == "ssd" and DEMAND_MINIMUMS.has(level):
            # Preferencias orientativas, no requisitos ni garantías de rendimiento.
            var target = {"basico": 480, "intermedio": 1000, "alto": 1000, "extremo": 2000}[level]
            var prefer_nvme = demanda.get("actividad", "") in ["desarrollo", "edicion_render"]
            if demanda.get("actividad", "") == "edicion_render" and demanda.get("resolucion", "") == "4k":
                target = 2000
            allowed.sort_custom(func(a, b):
                var a_ok = int(a.get("capacity_gb", 0)) >= target
                var b_ok = int(b.get("capacity_gb", 0)) >= target
                if a_ok != b_ok: return a_ok
                if prefer_nvme and (a.get("interface") == "nvme_pcie") != (b.get("interface") == "nvme_pcie"):
                    return a.get("interface") == "nvme_pcie"
                return int(a["price_cop"]) < int(b["price_cop"])
            )
        elif DEMAND_MINIMUMS.has(level) and component_type in ["cpu", "ram", "gpu"]:
            var metric = {"cpu": "cores", "ram": "capacity_gb", "gpu": "vram_gb"}[component_type]
            allowed.sort_custom(func(a, b): return int(a.get(metric, 0)) < int(b.get(metric, 0)))
        else:
            allowed.sort_custom(func(a, b): return int(a["price_cop"]) < int(b["price_cop"]))
        candidates[component_type] = allowed
    return candidates
