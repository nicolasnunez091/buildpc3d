extends "res://scripts/model/CatalogDAO.gd"

var requested_urls: Array = []

func _document_url(part: String) -> String:
    return "http://127.0.0.1:18938/" + part

func _request(url: String) -> void:
    requested_urls.append(url)
    super._request(url)
