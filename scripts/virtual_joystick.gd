class_name EcoVirtualStick
extends Control

var output := Vector2.ZERO
var touch_index: int = -1
var center := Vector2.ZERO
var knob_position := Vector2.ZERO
var radius: float = 88.0
var active: bool = false

const NO_POINTER := -1
const MOUSE_POINTER := -2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	center = Vector2(radius + 18.0, size.y - radius - 18.0)
	knob_position = center
	resized.connect(_on_resized)
	queue_redraw()


func _on_resized() -> void:
	if active:
		center = _clamp_center(center)
		knob_position = center + output * radius
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Track real touch events before Control GUI routing. On mobile/web, pressing a
	# regular Button with a second finger can change the emulated mouse pointer or
	# GUI focus. Raw touch indices remain stable, so the sprint finger can never
	# relocate or release the steering finger owned by this stick.
	if not is_visible_in_tree() or _modal_is_open():
		return
	if event is InputEventScreenTouch:
		var local_position := _viewport_to_local(event.position)
		if _handle_touch_event(event, local_position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var local_position := _viewport_to_local(event.position)
		if _handle_touch_event(event, local_position):
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# Screen touches are owned by _input() above. Handling them again here would
	# mix raw multitouch with the GUI's emulated mouse stream.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	if _handle_pointer_event(event):
		accept_event()


func _handle_pointer_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return _handle_touch_event(event, event.position)
	elif event is InputEventScreenDrag:
		return _handle_touch_event(event, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Mobile browsers and platform compatibility layers can emit a mouse
			# press while a real touch is already steering. Never let that fallback
			# event steal the active finger and relocate the dynamic stick.
			if touch_index != NO_POINTER:
				return false
			touch_index = MOUSE_POINTER
			_activate_at(event.position)
			_set_from_position(event.position)
		elif touch_index == MOUSE_POINTER:
			touch_index = NO_POINTER
			_reset()
		else:
			return false
		return true
	elif event is InputEventMouseMotion and touch_index == MOUSE_POINTER:
		_set_from_position(event.position)
		return true
	return false


func _handle_touch_event(event: InputEvent, local_position: Vector2) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == NO_POINTER:
			if not Rect2(Vector2.ZERO, size).has_point(local_position):
				return false
			touch_index = event.index
			_activate_at(local_position)
			_set_from_position(local_position)
		elif not event.pressed and event.index == touch_index:
			touch_index = NO_POINTER
			_reset()
		else:
			return false
		return true
	elif event is InputEventScreenDrag and event.index == touch_index:
		_set_from_position(local_position)
		return true
	return false


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _modal_is_open() -> bool:
	# _input() runs before GUI hit testing, so a visible sibling modal cannot
	# otherwise prevent this joystick from consuming touches underneath it.
	var node: Node = self
	for _index in range(8):
		if node == null:
			break
		var modal := node.get_node_or_null("ModalRoot") as CanvasItem
		if modal != null and modal.visible:
			return true
		node = node.get_parent()
	return false


func _activate_at(local_position: Vector2) -> void:
	active = true
	center = _clamp_center(local_position)
	knob_position = center
	output = Vector2.ZERO
	queue_redraw()


func _clamp_center(value: Vector2) -> Vector2:
	var margin := radius + 14.0
	return Vector2(
		clampf(value.x, margin, maxf(margin, size.x - margin)),
		clampf(value.y, margin, maxf(margin, size.y - margin))
	)


func _set_from_position(local_position: Vector2) -> void:
	var delta := local_position - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob_position = center + delta
	output = delta / radius
	if output.length() < 0.12:
		output = Vector2.ZERO
	queue_redraw()


func _reset() -> void:
	output = Vector2.ZERO
	knob_position = center
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	draw_circle(center, radius + 12.0, Color(0.025, 0.10, 0.09, 0.52))
	draw_arc(center, radius + 10.0, 0.0, TAU, 56, Color(0.64, 0.94, 0.70, 0.70), 4.0, true)
	draw_circle(knob_position, radius * 0.48, Color(0.55, 0.94, 0.65, 0.86))
	draw_arc(knob_position, radius * 0.48, 0.0, TAU, 40, Color(0.94, 1.0, 0.94, 0.94), 3.0, true)
