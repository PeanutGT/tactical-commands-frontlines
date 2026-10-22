class_name SelectionController
extends Node2D
## PC unit control (section 3): left-click selects, left-drag box-selects,
## Shift adds, right-click moves (or attacks the enemy under the cursor),
## Ctrl+right-click force-attacks any unit, right-click on an own transport
## boards the selected infantry, H toggles hold position, X stops, R retreats,
## U unloads. Orders go to the simulation as
## commands; selection itself is presentation and never enters the sim.

signal selection_changed(count: int)

## Screen pixels the mouse must travel before a press becomes a box.
const DRAG_THRESHOLD: float = 6.0
const MARKER_SEC: float = 0.6

var side: int = GameMap.Side.PLAYER

var _sim: Simulation
var _layer: UnitLayer
var _style: StylePack
var _pressing: bool = false
var _press_screen: Vector2 = Vector2.ZERO
var _press_world: Vector2 = Vector2.ZERO
var _boxing: bool = false
var _drag_world: Vector2 = Vector2.ZERO
var _marker_pos: Vector2 = Vector2.ZERO
var _marker_left: float = 0.0


func setup(sim: Simulation, layer: UnitLayer, style: StylePack) -> void:
	_sim = sim
	_layer = layer
	_style = style


func selected_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for id: int in _layer.selected:
		ids.append(id)
	ids.sort()
	return ids


func _unhandled_input(event: InputEvent) -> void:
	if _sim == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not Input.is_physical_key_pressed(KEY_SPACE):
				_pressing = true
				_boxing = false
				_press_screen = mb.position
				_press_world = _to_world(mb.position)
				_drag_world = _press_world
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _pressing:
				_pressing = false
				if _boxing:
					_select_box(Rect2(_press_world, Vector2.ZERO).expand(_to_world(mb.position)), mb.shift_pressed)
				else:
					_select_click(_to_world(mb.position), mb.shift_pressed)
				_boxing = false
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var world: Vector2 = _to_world(mb.position)
			var t: SimUnit = _unit_at(world, -1 if mb.ctrl_pressed else 1 - side)
			var ride: SimUnit = null if mb.ctrl_pressed else _unit_at(world, side)
			if t != null:
				_order_attack(t)
			elif ride != null and ride.type.transport_capacity > 0:
				_order_board(ride)
			else:
				_order_move(world)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressing:
		var mm: InputEventMouseMotion = event
		if not _boxing and mm.position.distance_to(_press_screen) >= DRAG_THRESHOLD:
			_boxing = true
		_drag_world = _to_world(mm.position)
		if _boxing:
			queue_redraw()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return
		var ids: PackedInt32Array = selected_ids()
		match key.physical_keycode:
			KEY_X:
				if not ids.is_empty():
					_sim.issue(SimCommand.stop(side, ids))
				get_viewport().set_input_as_handled()
			KEY_H:
				if not ids.is_empty():
					_sim.issue(SimCommand.hold(side, ids))
				get_viewport().set_input_as_handled()
			KEY_R:
				if not ids.is_empty():
					_sim.issue(SimCommand.retreat(side, ids))
				get_viewport().set_input_as_handled()
			KEY_U:
				if not ids.is_empty():
					_sim.issue(SimCommand.unload(side, ids))
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _marker_left > 0.0:
		_marker_left -= delta
		queue_redraw()


func _draw() -> void:
	if _boxing:
		var rect: Rect2 = Rect2(_press_world, Vector2.ZERO).expand(_drag_world)
		var fill: Color = _style.selection
		fill.a = 0.12
		draw_rect(rect, fill)
		draw_rect(rect, _style.selection, false, 1.0)
	if _marker_left > 0.0:
		var t: float = _marker_left / MARKER_SEC
		var c: Color = _style.order_marker
		c.a = t
		draw_arc(_marker_pos, float(_style.cell_px) * (0.3 + 0.5 * t), 0.0, TAU, 24, c, 2.0, true)


func _to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


## Drops dead units from the selection; call after simulation ticks.
func prune_dead() -> void:
	var before: int = _layer.selected.size()
	for id: int in _layer.selected.keys():
		if _sim.unit(id) == null:
			_layer.selected.erase(id)
	if _layer.selected.size() != before:
		selection_changed.emit(_layer.selected.size())


## Closest unit of `of_side` under `world` (-1 = any side), or null.
func _unit_at(world: Vector2, of_side: int) -> SimUnit:
	var best: SimUnit = null
	var best_d: float = INF
	for u: SimUnit in _sim.units:
		if not u.on_map() or (of_side >= 0 and u.side != of_side):
			continue
		var d: float = _layer.world_pos(u).distance_to(world)
		if d <= _layer.pick_radius(u) and d < best_d:
			best_d = d
			best = u
	return best


func _select_click(world: Vector2, add: bool) -> void:
	var best: SimUnit = _unit_at(world, side)
	if not add:
		_layer.selected.clear()
	if best != null:
		if add and _layer.selected.has(best.id):
			_layer.selected.erase(best.id)
		else:
			_layer.selected[best.id] = true
	selection_changed.emit(_layer.selected.size())


func _select_box(rect: Rect2, add: bool) -> void:
	if not add:
		_layer.selected.clear()
	for u: SimUnit in _sim.units:
		if u.side == side and u.on_map() and rect.has_point(_layer.world_pos(u)):
			_layer.selected[u.id] = true
	selection_changed.emit(_layer.selected.size())


func _order_attack(t: SimUnit) -> void:
	var ids: PackedInt32Array = selected_ids()
	if ids.is_empty():
		return
	_sim.issue(SimCommand.attack(side, ids, t.id))
	_marker_pos = _layer.world_pos(t)
	_marker_left = MARKER_SEC
	queue_redraw()


## Selected infantry boards `t`; anything else selected moves next to it.
func _order_board(t: SimUnit) -> void:
	var riders: PackedInt32Array = PackedInt32Array()
	var others: PackedInt32Array = PackedInt32Array()
	for id: int in selected_ids():
		if id == t.id:
			continue
		var u: SimUnit = _sim.unit(id)
		if u != null and u.type.kind == UnitType.Kind.INFANTRY:
			riders.append(id)
		else:
			others.append(id)
	if not riders.is_empty():
		_sim.issue(SimCommand.board(side, riders, t.id))
	if not others.is_empty():
		_sim.issue(SimCommand.move(side, others, t.cell()))
	_marker_pos = _layer.world_pos(t)
	_marker_left = MARKER_SEC
	queue_redraw()


func _order_move(world: Vector2) -> void:
	var ids: PackedInt32Array = selected_ids()
	var cell: Vector2i = Vector2i((world / float(_style.cell_px)).floor())
	if ids.is_empty() or not _sim.map.in_bounds(cell):
		return
	_sim.issue(SimCommand.move(side, ids, cell))
	_marker_pos = (Vector2(cell) + Vector2(0.5, 0.5)) * float(_style.cell_px)
	_marker_left = MARKER_SEC
	queue_redraw()
