extends RefCounted

const DATA_PATH = "res://data/cpu_cooling_boxed.json"

func message(cpu: Dictionary) -> String:
    var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(data) != TYPE_DICTIONARY:
        return "No se ha confirmado si esta presentación del procesador incluye disipador. Verifica la refrigeración antes del ensamblaje."
    var entry = data.get(str(cpu.get("id", "")), {})
    # Los registros originales no indican SKU ni presentación. La ficha boxed
    # no convierte una oferta desconocida o tray/OEM en un producto boxed.
    var presentation = str(cpu.get("presentation", "unknown")).to_lower()
    if presentation not in ["boxed", "unknown", ""]:
        return "No se ha confirmado si esta presentación del procesador incluye disipador. Verifica la refrigeración antes del ensamblaje."
    var qualifier = "La presentación de esta oferta no está confirmada. " if presentation != "boxed" else ""
    if entry.get("boxed") == "included" and not str(entry.get("cooler", "")).is_empty():
        return qualifier + "En presentación boxed incluye " + str(entry["cooler"]) + ", sin costo adicional por ese disipador. No garantiza temperaturas adecuadas para toda carga; verifica el contenido antes de comprar."
    if entry.get("boxed") == "not_included":
        return qualifier + "La presentación boxed no incluye disipador. Necesitas refrigeración compatible para completar el computador; el precio no la incluye. Verifica la presentación antes de comprar."
    return "No se ha confirmado si esta presentación del procesador incluye disipador. Verifica la refrigeración antes del ensamblaje."
