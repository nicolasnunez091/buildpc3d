extends Node
class_name DAO

const FIREBASE_REST_URL = "https://firestore.googleapis.com/v1/projects/TU_PROYECTO_ID/databases/(default)/documents/Componentes"

var local_catalog: Dictionary = {}
var is_data_loaded: bool = false

signal catalog_download_complete
signal catalog_download_failed

func fetch_catalog_from_firebase() -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_catalog_received)
	
	print("[DAO] Iniciando descarga masiva del catálogo desde Firebase REST...")
	var err = http_request.request(FIREBASE_REST_URL)
	if err != OK:
		print("[DAO] Error al crear la petición HTTP: ", err)
		emit_signal("catalog_download_failed")

func _on_catalog_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			_parse_firestore_documents(json.get_data())
			is_data_loaded = true
			print("[DAO] Catálogo guardado con éxito en memoria local.")
			emit_signal("catalog_download_complete")
		else:
			emit_signal("catalog_download_failed")
	else:
		emit_signal("catalog_download_failed")

func _parse_firestore_documents(data: Dictionary) -> void:
	if data.has("documents"):
		for doc in data["documents"]:
			var fields = doc.get("fields", {})
			var item_id = doc.get("name", "").split("/")[-1]
			local_catalog[item_id] = {
				"name": fields.get("nombre", {}).get("stringValue", ""),
				"socket": fields.get("socket", {}).get("stringValue", ""),
				"tdp_vatios": fields.get("tdp_vatios", {}).get("integerValue", 0),
				"precio": fields.get("precio", {}).get("integerValue", 0),
				"modelo3D": fields.get("modelo3D", {}).get("stringValue", "")
			}
