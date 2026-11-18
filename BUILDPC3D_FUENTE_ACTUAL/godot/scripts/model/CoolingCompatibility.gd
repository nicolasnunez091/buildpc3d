extends RefCounted

# Motor aislado de la aplicación hasta contar con una matriz real revisada.
# "verificada" significa solo que superó los datos aportados, no garantiza
# temperaturas ni contempla accesorios o revisiones no especificadas.
const VERIFIED = "verificada"
const PENDING = "pendiente"
const INCOMPATIBLE = "incompatible"

func evaluate(cooler: Dictionary, cpu: Dictionary, board: Dictionary, chassis: Dictionary, evidence: Dictionary) -> Dictionary:
    var result = {"physical": PENDING, "thermal": PENDING, "reason": ""}
    var sockets = cooler.get("sockets")
    var socket = str(cpu.get("socket", ""))
    var board_socket = str(board.get("socket", ""))
    var kind = str(cooler.get("cooling_type", ""))
    var height = int(cooler.get("height_mm", 0))
    if typeof(sockets) != TYPE_ARRAY or sockets.is_empty() or socket.is_empty() or board_socket.is_empty() or kind.is_empty():
        result.reason = "Faltan socket o especificaciones del refrigerador."
        return result
    if socket != board_socket or socket not in sockets:
        result.physical = INCOMPATIBLE
        result.reason = "Socket o montaje incompatible."
        return result
    if kind != "air":
        result.reason = "No hay comprobación documentada de radiador y ventiladores."
        return result
    var case_record = evidence.get("cases", {}).get(str(chassis.get("id", "")), {})
    var clearance = int(case_record.get("cooler_height_mm", 0))
    if height <= 0 or clearance <= 0 or str(case_record.get("source", "")).is_empty():
        result.reason = "Falta altura documentada del refrigerador o chasis."
        return result
    if height > clearance:
        result.physical = INCOMPATIBLE
        result.reason = "El disipador excede la altura del chasis."
        return result
    var board_record = evidence.get("boards", {}).get(str(board.get("id", "")), {}).get(str(cooler.get("id", "")), {})
    var status = str(board_record.get("status", ""))
    if status == INCOMPATIBLE and not str(board_record.get("source", "")).is_empty():
        result.physical = INCOMPATIBLE
        result.reason = "El fabricante documenta una interferencia con la placa."
        return result
    if status != VERIFIED or str(board_record.get("source", "")).is_empty() or board_record.get("ram_clear", false) != true:
        result.reason = "Falta verificar el par placa–refrigerador y el despeje de RAM."
        return result
    result.physical = VERIFIED
    result.reason = "Montaje comprobado según los datos disponibles; verificar revisión y kit."
    var thermal = evidence.get("thermal", {}).get(str(cpu.get("id", "")), {}).get(str(cooler.get("id", "")), {})
    if str(thermal.get("status", "")) == "orientativa" and not str(thermal.get("source", "")).is_empty():
        result.thermal = "orientativa"
    return result
