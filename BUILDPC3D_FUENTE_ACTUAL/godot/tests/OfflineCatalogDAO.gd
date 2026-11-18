extends "res://scripts/model/CatalogDAO.gd"

# Puerto local no expuesto: prueba de respaldo sin acceder ni escribir en Firebase.
func _document_url(part: String) -> String:
    return "http://127.0.0.1:1/" + part
