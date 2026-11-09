extends Node

var dao: DAO = DAO.new()
var recomendador: Recomendador = Recomendador.new()

func _ready() -> void:
	print("[MainController] Inicializando arquitectura MVC en Godot...")
	add_child(dao)
	add_child(recomendador)
	
	dao.catalog_download_complete.connect(_on_catalog_ready)
	dao.fetch_catalog_from_firebase()

func _on_catalog_ready() -> void:
	print("[MainController] Catálogo listo en memoria local.")
