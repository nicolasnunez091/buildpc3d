extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = MAIN.instantiate()
	root.add_child(app)
	await process_frame
	var edit: TextEdit = app._description
	var ok = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch") \
		and edit.editable and edit.focus_mode == Control.FOCUS_ALL \
		and edit.mouse_filter == Control.MOUSE_FILTER_STOP \
		and edit.virtual_keyboard_enabled and edit.virtual_keyboard_show_on_focus \
		and app._pages[0].follow_focus
	edit.grab_focus()
	ok = ok and edit.has_focus()
	print("CONFIGURACIÓN ENTRADA MÓVIL: ", "OK" if ok else "FAIL", " (teclado Android no probado)")
	app.free()
	quit(0 if ok else 1)
