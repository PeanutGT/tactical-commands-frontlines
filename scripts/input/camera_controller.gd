class_name CameraController
extends Camera2D
## PC camera: wheel (or trackpad pinch) zooms at the cursor; middle-drag or
## Space + left-drag pans; WASD / arrow keys and screen-edge scrolling pan.
## Plain left/right clicks are left free for selection and orders (M2).

signal zoom_changed(zoom: float)

const MAX_ZOOM: float = 4.0
## Zooming out stops a little past "whole map fits".
const MIN_ZOOM_FACTOR: float = 0.9
const WHEEL_STEP: float = 1.15
const KEY_PAN_SPEED: float = 900.0  # screen px per second
const EDGE_PX: float = 14.0
const EDGE_PAN_SPEED: float = 800.0

var world_size: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse_inside: bool = false


func _ready() -> void:
	get_window().mouse_entered.connect(func() -> void: _mouse_inside = true)
	get_window().mouse_exited.connect(func() -> void: _mouse_inside = false)
	get_viewport().size_changed.connect(_on_view_resized)


func setup(p_world_size: Vector2) -> void:
	world_size = p_world_size
	fit()


func fit() -> void:
	_apply(CameraMath.fit_zoom(_view(), world_size), world_size * 0.5)


func min_zoom() -> float:
	return CameraMath.fit_zoom(_view(), world_size) * MIN_ZOOM_FACTOR


func zoom_at(next_zoom: float, screen: Vector2) -> void:
	var z: float = clampf(next_zoom, min_zoom(), MAX_ZOOM)
	_apply(z, CameraMath.position_for_zoom_at(position, _view(), zoom.x, z, screen))


func pan_screen(delta: Vector2) -> void:
	_apply(zoom.x, position - delta / zoom.x)


func _process(delta: float) -> void:
	if world_size == Vector2.ZERO:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	var speed: float = KEY_PAN_SPEED

	if dir == Vector2.ZERO and _mouse_inside and not _dragging and get_window().has_focus():
		var m: Vector2 = get_viewport().get_mouse_position()
		var view: Vector2 = _view()
		if m.x < EDGE_PX:
			dir.x = -1.0
		elif m.x > view.x - EDGE_PX:
			dir.x = 1.0
		if m.y < EDGE_PX:
			dir.y = -1.0
		elif m.y > view.y - EDGE_PX:
			dir.y = 1.0
		speed = EDGE_PAN_SPEED

	if dir != Vector2.ZERO:
		pan_screen(-dir * speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var steps: float = mb.factor if mb.factor > 0.0 else 1.0
					var dir_sign: float = 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
					zoom_at(zoom.x * pow(WHEEL_STEP, dir_sign * steps), mb.position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
			MOUSE_BUTTON_LEFT:
				if mb.pressed and Input.is_physical_key_pressed(KEY_SPACE):
					_dragging = true
					get_viewport().set_input_as_handled()
				elif not mb.pressed and _dragging:
					_dragging = false
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		pan_screen((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var g: InputEventMagnifyGesture = event
		zoom_at(zoom.x * g.factor, g.position)
	elif event is InputEventPanGesture:
		pan_screen(-(event as InputEventPanGesture).delta * 20.0)


func _apply(z: float, pos: Vector2) -> void:
	var changed: bool = not is_equal_approx(z, zoom.x)
	zoom = Vector2(z, z)
	position = CameraMath.clamp_position(pos, _view(), z, world_size)
	if changed:
		zoom_changed.emit(z)


func _view() -> Vector2:
	return get_viewport_rect().size


func _on_view_resized() -> void:
	if world_size != Vector2.ZERO:
		_apply(maxf(zoom.x, min_zoom()), position)
