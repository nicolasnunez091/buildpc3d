extends ScrollContainer

# Desplazamiento de páginas con ratón y tacto, también sobre botones.
# El visor y los editores conservan sus propios gestos.
const DRAG_THRESHOLD := 10.0
const DECELERATION := 2400.0

var input_blocked := false
var _pointer := -2
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _dragging := false
var _velocity := 0.0
var _last_time := 0
var _position_y := 0.0

func _ready() -> void:
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	visibility_changed.connect(cancel_drag)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or input_blocked:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == -2:
			_begin(event.position, event.index)
		elif not event.pressed and event.index == _pointer:
			_finish(event.canceled)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pointer == -2:
			_begin(event.position, -1)
		elif not event.pressed and _pointer == -1:
			_finish(false)
	elif event is InputEventMouseMotion and _pointer == -1:
		_move(event.position)

func _begin(point: Vector2, pointer: int) -> void:
	if not get_global_rect().has_point(point):
		return
	_velocity = 0.0
	if _has_own_gesture(self, point):
		return
	_pointer = pointer
	_start = point
	_last = point
	_dragging = false
	_velocity = 0.0
	_position_y = scroll_vertical
	_last_time = Time.get_ticks_msec()

func _has_own_gesture(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			if child is SubViewportContainer or child is TextEdit or child is LineEdit:
				if child.get_global_rect().has_point(point):
					return true
			if _has_own_gesture(child, point):
				return true
	return false

func _move(point: Vector2) -> void:
	var now = Time.get_ticks_msec()
	if not _dragging and absf(point.y - _start.y) >= DRAG_THRESHOLD:
		_dragging = true
		# BaseButton cancela la pulsación: deslizar una tarjeta no la activa.
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		scroll_started.emit()
	if _dragging:
		var dy = point.y - _last.y
		var elapsed = maxf(float(now - _last_time) / 1000.0, 0.008)
		_velocity = clampf(-dy / elapsed, -2200.0, 2200.0)
		_apply_scroll(-dy)
		get_viewport().set_input_as_handled()
	_last = point
	_last_time = now

func _finish(canceled: bool) -> void:
	if _dragging:
		get_viewport().set_input_as_handled()
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
		scroll_ended.emit()
	if canceled or Time.get_ticks_msec() - _last_time > 100:
		_velocity = 0.0
	_pointer = -2
	_dragging = false

func _process(delta: float) -> void:
	if not is_visible_in_tree() or input_blocked or _pointer != -2 or absf(_velocity) < 1.0:
		return
	_apply_scroll(_velocity * delta)
	_velocity = move_toward(_velocity, 0.0, DECELERATION * delta)

func _apply_scroll(amount: float) -> void:
	var bar = get_v_scroll_bar()
	_position_y = clampf(_position_y + amount, 0.0, maxf(0.0, bar.max_value - bar.page))
	scroll_vertical = roundi(_position_y)

func cancel_drag() -> void:
	if _dragging:
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
	_pointer = -2
	_dragging = false
	_velocity = 0.0
