extends Control

const FilterScript = preload("res://scripts/model/UseFilter.gd")
const ControllerScript = preload("res://scripts/controller/PCController.gd")
const DAOScript = preload("res://scripts/model/CatalogDAO.gd")
const ViewerScript = preload("res://scripts/view/PCViewer.gd")
const DemandAnalyzerScript = preload("res://scripts/model/DemandAnalyzer.gd")
const CpuCoolingInfoScript = preload("res://scripts/model/CpuCoolingInfo.gd")

const BACK = Color("0d0b12")
const CARD = Color("17121f")
const CARD_ALT = Color("201625")
const OUTLINE = Color("3e2636")
const PINK = Color("e42b6d")
const PINK_DARK = Color("8c1847")
const TEXT = Color("f7f2f7")
const SUB = Color("a69aa9")
const GREEN = Color("5de3ab")

var _controller: PCController
var _dao: CatalogDAO
var _catalog: Dictionary = {}
var _equipment: Dictionary = {}
var _current_use: String = ""
var _manual_use: String = ""
var _recommended_use: String = ""
var _recommended_message: String = ""
var _selected_part: String = "gpu"
var _selected_candidate: Dictionary = {}
var _pages: Array = []
var _profile_buttons: Dictionary = {}
var _description: TextEdit
var _home_status: Label
var _assembly_status: Label
var _cooling_status: Label
var _catalog_status: Label
var _total: Label
var _balance: Label
var _components_box: VBoxContainer
var _alternatives_box: VBoxContainer
var _catalog_heading: Label
var _selected_label: Label
var _viewer: PCViewer
var _viewer_note: Label
var _viewer_product: Label
var _dashboard: AcceptDialog
var _ai_button: Button
var _generate_button: Button
var _clear_use_button: Button
var _generic_gpu_toggle: CheckBox
var _detailed_view_toggle: CheckBox
var _pending_generation: bool = false
var _interpreted_text: String = ""
var _interpretation_message: String = ""
# Inyección opcional para pruebas locales; vacío usa la configuración instalada.
var _ai_service_url_override: String = ""

func _ready() -> void:
	_controller = ControllerScript.new()
	add_child(_controller)
	_controller.ia_resuelta.connect(_on_ia_resuelta)
	_build_ui()
	_dao = DAOScript.new()
	add_child(_dao)
	_dao.catalogo_cargado.connect(_on_catalog_ready)
	_dao.error_catalogo.connect(_on_catalog_error)
	_dao.obtener_catalogo()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _dashboard.visible:
		return
	if _pages[2].visible:
		_set_page(1)
	elif _pages[1].visible:
		_set_page(0)
	else:
		return
	get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var background = ColorRect.new()
	background.color = BACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_build_home(_new_page())
	_build_assembly(_new_page())
	_build_catalog(_new_page())
	_dashboard = AcceptDialog.new()
	_dashboard.title = "BUILDPC3D / Ensamble final"
	_dashboard.min_size = Vector2i(440, 520)
	add_child(_dashboard)
	_set_page(0)

func _new_page() -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 34)
	scroll.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	_pages.append(scroll)
	return column

func _build_home(column: VBoxContainer) -> void:
	var header = HBoxContainer.new()
	column.add_child(header)
	var name = _label("BUILD", 29, TEXT, true)
	name.custom_minimum_size.x = 96
	header.add_child(name)
	var mark = _label("PC3D", 29, PINK, true)
	mark.custom_minimum_size.x = 93
	header.add_child(mark)
	column.add_child(_separator())
	column.add_child(_label("CONFIGURADOR DE HARDWARE 3D", 11, PINK))
	column.add_child(_label("Diseño de Torre.\nCompatibilidad real.", 29, TEXT, true))
	var input_panel = _panel()
	column.add_child(input_panel)
	var input_column = _stack(input_panel, 9)
	input_column.add_child(_label("REQUERIMIENTO O USO PRINCIPAL", 11, SUB))
	_description = TextEdit.new()
	_description.editable = true
	_description.focus_mode = Control.FOCUS_ALL
	_description.mouse_filter = Control.MOUSE_FILTER_STOP
	_description.virtual_keyboard_enabled = true
	_description.virtual_keyboard_show_on_focus = true
	_description.placeholder_text = "Escribe tu petición para pasarla por nuestros filtros..."
	_description.custom_minimum_size.y = 113
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description.add_theme_color_override("font_color", TEXT)
	_description.add_theme_color_override("font_placeholder_color", SUB)
	_description.text_changed.connect(_on_description_changed)
	input_column.add_child(_description)
	input_column.add_child(_label("USO DEL EQUIPO", 11, SUB))
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	input_column.add_child(row1)
	for use in ["juegos", "edicion", "ofimatica"]:
		var title = {"juegos":"Gaming", "edicion":"Desarrollo / Render", "ofimatica":"Oficina"}[use]
		var btn = _button(title)
		btn.add_theme_font_size_override("font_size", 14)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_choose_manual_use.bind(use))
		row1.add_child(btn)
		_profile_buttons[use] = btn
	_clear_use_button = _button("Quitar selección")
	_clear_use_button.pressed.connect(_clear_manual_use)
	input_column.add_child(_clear_use_button)
	_ai_button = _button("Interpretar petición")
	_ai_button.pressed.connect(_request_ai)
	input_column.add_child(_ai_button)
	_home_status = _label("Cargando catálogo de componentes...", 12, SUB)
	_home_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_home_status)
	_fill_space(column, 105)
	_generate_button = _button("[ ANALIZAR Y GENERAR 3D ]", true)
	_generate_button.custom_minimum_size.y = 59
	_generate_button.pressed.connect(_generate)
	column.add_child(_generate_button)
	column.add_child(_label("BUILDPC3D  •  ANDROID  •  MVC + DAO", 10, SUB))
	column.add_child(_label("Precios de referencia, no cotizaciones verificadas para compra.", 10, SUB))

func _build_assembly(column: VBoxContainer) -> void:
	_page_header(column, "TORRE", "3D", 0)
	column.add_child(_label("ESTUDIO 3D  /  VISTA INTERACTIVA", 12, PINK))
	var vpanel = _panel()
	column.add_child(vpanel)
	var viewer_style = StyleBoxFlat.new()
	viewer_style.bg_color = Color("11121d")
	viewer_style.border_color = Color("624058")
	viewer_style.set_border_width_all(1)
	viewer_style.set_corner_radius_all(15)
	viewer_style.set_content_margin_all(14)
	vpanel.add_theme_stylebox_override("panel", viewer_style)
	var vbox = _stack(vpanel, 6)
	vbox.add_child(_label("Gira · Pellizca para zoom · Toca una pieza", 12, SUB))
	_viewer = ViewerScript.new()
	_viewer.custom_minimum_size.y = 460
	_viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewer.pieza_seleccionada.connect(_on_part_selected)
	vbox.add_child(_viewer)
	_viewer_product = _label("", 12, TEXT)
	_viewer_product.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_viewer_product)
	vbox.add_child(_label("VISTA DE CORTE  ·  REPRESENTACIÓN 3D", 11, PINK))
	_viewer_note = _label("Geometría genérica. El refrigerador ilustrado no se incluye en el precio.", 11, SUB)
	vbox.add_child(_viewer_note)
	_viewer.estado_visual_cambiado.connect(_on_viewer_status)
	var ssd_focus = CheckBox.new()
	ssd_focus.text = "Inspeccionar SSD por separado"
	ssd_focus.tooltip_text = "Aísla el SSD seleccionado. Modelo genérico educativo y montaje aproximado."
	ssd_focus.toggled.connect(_viewer.enfocar_ssd)
	vbox.add_child(ssd_focus)
	_detailed_view_toggle = CheckBox.new()
	_detailed_view_toggle.text = "Mostrar modelos genéricos detallados"
	_detailed_view_toggle.button_pressed = true
	_detailed_view_toggle.toggled.connect(_viewer.usar_modelos_detallados)
	vbox.add_child(_detailed_view_toggle)
	_generic_gpu_toggle = CheckBox.new()
	_generic_gpu_toggle.text = "GPU alternativa genérica CC0"
	_generic_gpu_toggle.tooltip_text = "Grab3D · CC0 1.0. Ilustración genérica; no cambia el catálogo ni representa la GPU elegida."
	_generic_gpu_toggle.button_pressed = false
	_generic_gpu_toggle.toggled.connect(_viewer.usar_gpu_generica)
	vbox.add_child(_generic_gpu_toggle)
	vbox.add_child(_label("Modelos: Innerscene y Grab3D · CC0 1.0.", 11, SUB))
	var price_panel = _panel()
	column.add_child(price_panel)
	var price_col = _stack(price_panel, 7)
	price_col.add_child(_label("COSTO TOTAL", 11, SUB))
	_total = _label("—", 26, TEXT, true)
	price_col.add_child(_total)
	_balance = _label("✓ COMPATIBILIDAD ESTIMADA", 12, GREEN)
	price_col.add_child(_balance)
	column.add_child(_label("COMPONENTES SUGERIDOS", 14, TEXT, true))
	column.add_child(_label("Toca una pieza para ver alternativas compatibles.", 11, SUB))
	_components_box = VBoxContainer.new()
	_components_box.add_theme_constant_override("separation", 8)
	column.add_child(_components_box)
	_assembly_status = _label("", 12, SUB)
	_assembly_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_assembly_status)
	_cooling_status = _label("", 12, TEXT)
	_cooling_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_cooling_status)
	var dashboard = _button("[ VER DASHBOARD DEL EQUIPO FINAL ]", true)
	dashboard.custom_minimum_size.y = 52
	dashboard.pressed.connect(_show_dashboard)
	column.add_child(dashboard)

func _on_viewer_status(message: String) -> void:
	_viewer_note.text = message

func _build_catalog(column: VBoxContainer) -> void:
	_page_header(column, "CATÁLOGO", "DAO", 1)
	column.add_child(_label("REEMPLAZO DE COMPONENTES", 11, PINK))
	var details = _panel()
	column.add_child(details)
	var detail_column = _stack(details, 8)
	_catalog_heading = _label("Selecciona un componente", 16, TEXT, true)
	_catalog_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(_catalog_heading)
	detail_column.add_child(_label("Alternativas compatibles con los mínimos del uso elegido.", 12, SUB))
	_selected_label = _label("", 12, SUB)
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_selected_label)
	_alternatives_box = VBoxContainer.new()
	_alternatives_box.add_theme_constant_override("separation", 11)
	column.add_child(_alternatives_box)
	_catalog_status = _label("", 12, SUB)
	_catalog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_catalog_status)
	_fill_space(column, 60)
	var confirm = _button("[ CONFIRMAR REEMPLAZO ]", true)
	confirm.custom_minimum_size.y = 60
	confirm.pressed.connect(_replace)
	column.add_child(confirm)
	var back = _button("CANCELAR Y VOLVER")
	back.pressed.connect(_cancel_candidate)
	column.add_child(back)

func _page_header(column: VBoxContainer, left: String, right: String, back_page: int) -> void:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	column.add_child(header)
	var back = _button("‹ VOLVER")
	back.custom_minimum_size.x = 88
	back.add_theme_font_size_override("font_size", 12)
	back.pressed.connect(_set_page.bind(back_page))
	header.add_child(back)
	var filler = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(filler)
	var section_title = _label(left, 21, TEXT, true)
	section_title.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(section_title)
	var section_suffix = _label(right, 21, PINK, true)
	section_suffix.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(section_suffix)
	column.add_child(_separator())

func _choose_use(use: String) -> void:
	_current_use = use
	for candidate in _profile_buttons:
		_set_button_style(_profile_buttons[candidate], candidate == _manual_use)

func _choose_manual_use(use: String) -> void:
	if _manual_use == use:
		_clear_manual_use()
		return
	_manual_use = use
	_choose_use(use)
	_interpretation_message = "Perfil seleccionado: " + {"juegos": "Juegos", "edicion": "Diseño / Edición", "ofimatica": "Ofimática"}[use]
	_home_status.text = _interpretation_message

func _clear_manual_use() -> void:
	_manual_use = ""
	if not _recommended_use.is_empty() and _interpreted_text == _description.text.strip_edges():
		_choose_use(_recommended_use)
		_interpretation_message = _recommended_message
		_home_status.text = "Selección manual quitada. " + _recommended_message
	else:
		_choose_use("")
		_interpretation_message = ""
		_home_status.text = "Selección manual quitada. Escribe una petición o elige un uso."

func _on_description_changed() -> void:
	_interpreted_text = ""
	_recommended_use = ""
	_recommended_message = ""
	if _manual_use.is_empty():
		_current_use = ""
		_interpretation_message = ""

func _set_page(index: int) -> void:
	# _pages stores root scroll nodes in the same order as the UI screens.
	for i in range(_pages.size()):
		var item: Control = _pages[i]
		item.visible = i == index
		if item is ScrollContainer:
			(item as ScrollContainer).scroll_vertical = 0

func _on_catalog_ready(catalog: Dictionary, _source: String) -> void:
	_catalog = catalog
	_controller.establecer_catalogo(catalog)
	_home_status.text = "Catálogo disponible. Cuéntanos cómo usarás tu computador."

func _on_catalog_error(_message: String) -> void:
	_home_status.text = "Catálogo disponible sin conexión." if not _catalog.is_empty() else "No fue posible cargar el catálogo."

func _set_interpreting(busy: bool) -> void:
	_generate_button.disabled = busy
	_ai_button.disabled = busy
	_clear_use_button.disabled = busy
	_description.editable = not busy
	for button in _profile_buttons.values():
		button.disabled = busy

func _request_ai() -> void:
	_start_interpretation(false)

func _start_interpretation(generate_after: bool) -> void:
	_pending_generation = generate_after
	_set_interpreting(true)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://config/app_config.json"))
	var url = ""
	if typeof(data) == TYPE_DICTIONARY:
		url = str(data.get("ai_service_url_android", "")) if OS.get_name() == "Android" else str(data.get("ai_service_url", ""))
	if not _ai_service_url_override.is_empty():
		url = _ai_service_url_override
	var warm_up = OS.get_name() == "Android"
	_home_status.text = "Conectando con el servidor; puede tardar hasta 90 segundos..." if warm_up else "Interpretando petición..."
	_controller.solicitar_uso(_description.text, url, warm_up)

func _on_ia_resuelta(ok: bool, message: String, use: String) -> void:
	var generate_after = _pending_generation
	_pending_generation = false
	_set_interpreting(false)
	_home_status.text = message
	if ok:
		_interpreted_text = _description.text.strip_edges()
		_recommended_use = use
		_recommended_message = message
		_manual_use = ""
		_interpretation_message = message
		_choose_use(use)
		if generate_after:
			_generate_selected()

func _generate() -> void:
	if _catalog.is_empty():
		_home_status.text = "El catálogo todavía no está disponible."
		return
	var text = _description.text.strip_edges()
	if not text.is_empty() and DemandAnalyzerScript.new().analyze(text)["portatil"]:
		_home_status.text = "BUILDPC3D configura computadores de escritorio, no portátiles."
		return
	if _manual_use.is_empty() and not text.is_empty() and text != _interpreted_text:
		_start_interpretation(true)
		return
	if _current_use.is_empty():
		_home_status.text = "Escribe una petición o selecciona un uso antes de generar."
		return
	_generate_selected()

func _generate_selected() -> void:
	var demand = {}
	if _manual_use.is_empty() and not _interpreted_text.is_empty() and _interpreted_text == _description.text.strip_edges():
		demand = DemandAnalyzerScript.new().analyze(_interpreted_text)
		# El backend antiguo no incluye detalles; las reglas locales prevalecen
		# para actividades conocidas. Nunca se aceptan IDs del modelo.
		if demand.get("actividad") == "general" and not _controller._remote_details.is_empty():
			demand.merge(_controller._remote_details, true)
	var outcome = _controller.generar_inicial(_current_use, demand)
	if not outcome.get("ok", false):
		_home_status.text = str(outcome.get("mensaje", "No hay configuración compatible."))
		return
	_equipment = outcome["equipo"]
	_viewer.mostrar_equipo(_equipment)
	_refresh_equipment()
	_assembly_status.text = _interpretation_message + " · SSD incluido; precio estimado no verificado. Refrigeración adicional no presupuestada. Velocidad M.2 depende de placa y CPU."
	if not demand.is_empty():
		_assembly_status.text += "\nExigencia estimada: " + str(demand["nivel_exigencia"]).capitalize() + ". " + str(demand["advertencia"])
	_set_page(1)

func _refresh_equipment() -> void:
	if _equipment.is_empty():
		return
	var featured: Dictionary = _equipment.get(_selected_part, {})
	_viewer_product.text = "Producto: " + str(featured.get("name", "")) + "  ·  Vista aproximada"
	if _equipment.has("ssd"):
		_viewer_product.text += "\nSSD: " + str(_equipment["ssd"].get("name", "")) + " · representación genérica"
	var total: int = _controller.calcular_total()
	_total.text = _money(total)
	_balance.text = "✓ COMPATIBILIDAD ESTIMADA"
	_cooling_status.text = "REFRIGERACIÓN: " + CpuCoolingInfoScript.new().message(_equipment.get("cpu", {}))
	for child in _components_box.get_children():
		child.queue_free()
	for key in FilterScript.TYPES:
		var part: Dictionary = _equipment[key]
		var option = _button("", key == _selected_part)
		option.text = "  " + str(FilterScript.LABELS[key]).to_upper() + "  ·  " + str(part.get("name", "")) + "\n  " + _money(int(part.get("price_cop", 0)))
		if key == "ssd":
			option.text += " (estimación no verificada)"
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.custom_minimum_size.y = 65
		option.pressed.connect(_open_catalog.bind(key))
		_components_box.add_child(option)

func _on_part_selected(category: String) -> void:
	if _equipment.has(category):
		_open_catalog(category)

func _open_catalog(category: String) -> void:
	if not _equipment.has(category):
		return
	_selected_part = category
	_selected_candidate.clear()
	var part: Dictionary = _equipment[category]
	_viewer_product.text = "Producto: " + str(part.get("name", "")) + "  ·  Vista aproximada"
	_catalog_heading.text = str(FilterScript.LABELS[category]).to_upper()
	_selected_label.text = "ACTUAL: " + str(part["name"]) + " · " + _money(int(part["price_cop"]))
	_catalog_status.text = "Selecciona una alternativa y confirma el reemplazo."
	if category == "ssd":
		_catalog_status.text += " Precios estimados no verificados; representación 3D genérica."
	_refresh_candidates()
	_set_page(2)

func _refresh_candidates() -> void:
	for child in _alternatives_box.get_children():
		child.queue_free()
	var alternatives = _controller.obtener_alternativas(_selected_part)
	if alternatives.is_empty():
		_alternatives_box.add_child(_label("No hay otras piezas compatibles con este uso.", 13, SUB))
	for candidate in alternatives:
		if str(candidate.get("id", "")) == str(_equipment[_selected_part].get("id", "")):
			continue
		var chosen = str(_selected_candidate.get("id", "")) == str(candidate.get("id", ""))
		var option = _button("", chosen)
		option.text = str(candidate["name"]) + "\n" + _money(int(candidate["price_cop"])) + "   ·   " + ("SELECCIONADA ✓" if chosen else "ELEGIR")
		if _selected_part == "ssd":
			option.text += " · estimación no verificada"
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.custom_minimum_size.y = 79
		option.pressed.connect(_select_candidate.bind(candidate))
		_alternatives_box.add_child(option)

func _select_candidate(candidate: Dictionary) -> void:
	_selected_candidate = candidate.duplicate(true)
	_catalog_status.text = "Elegida: " + str(candidate["name"])
	_refresh_candidates()

func _cancel_candidate() -> void:
	_selected_candidate.clear()
	_set_page(1)

func _replace() -> void:
	if _selected_candidate.is_empty():
		_catalog_status.text = "Primero elige una alternativa."
		return
	var outcome = _controller.reemplazar(_selected_part, _selected_candidate)
	if not outcome.get("ok", false):
		_catalog_status.text = str(outcome.get("mensaje", "No se pudo reemplazar esta pieza."))
		return
	_equipment = outcome["equipo"]
	_viewer.mostrar_equipo(_equipment)
	_refresh_equipment()
	_assembly_status.text = "Componente reemplazado. Costo actualizado; precio SSD estimado no verificado. Refrigeración adicional no presupuestada."
	_set_page(1)

func _show_dashboard() -> void:
	if _equipment.is_empty():
		_assembly_status.text = "Genera primero un computador."
		return
	var info = "Uso principal: " + _current_use.capitalize() + "\n\n"
	for kind in FilterScript.TYPES:
		var part: Dictionary = _equipment[kind]
		info += str(FilterScript.LABELS[kind]) + ":\n" + str(part["name"]) + " · " + _money(int(part["price_cop"])) + "\n\n"
	info += "TOTAL: " + _money(_controller.calcular_total()) + "\nIncluye precio SSD estimado no verificado. Refrigeración adicional no presupuestada.\n\n"
	info += "REFRIGERACIÓN:\n" + CpuCoolingInfoScript.new().message(_equipment.get("cpu", {}))
	_dashboard.dialog_text = info
	_dashboard.popup_centered()

func _panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = OUTLINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 14
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _stack(parent: Node, gap: int = 8) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _button(title: String, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 52
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 14)
	_set_button_style(button, primary)
	return button

func _set_button_style(button: Button, primary: bool) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = PINK_DARK if primary else CARD_ALT
	box.border_color = PINK if primary else OUTLINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 11
	box.content_margin_bottom = 11
	button.add_theme_stylebox_override("normal", box)
	var hover = box.duplicate()
	hover.bg_color = PINK if primary else Color("3b2340")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)

func _label(message: String, font_size: int = 14, color: Color = TEXT, bold: bool = false) -> Label:
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", maxi(font_size, 14))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if message.length() > 65 and font_size <= 14:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .30))
	return label

func _separator() -> HSeparator:
	var line = HSeparator.new()
	line.add_theme_constant_override("separation", 8)
	return line

func _fill_space(parent: VBoxContainer, pixels: float) -> void:
	var fill = Control.new()
	fill.custom_minimum_size.y = pixels
	parent.add_child(fill)

func _money(value: int) -> String:
	var amount = str(absi(value))
	var result = ""
	while amount.length() > 3:
		result = "." + amount.substr(amount.length() - 3) + result
		amount = amount.substr(0, amount.length() - 3)
	result = amount + result
	return ("-$" if value < 0 else "$") + result + " COP"
