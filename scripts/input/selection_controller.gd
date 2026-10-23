class_name SelectionController
extends Node2D
## PC unit control (section 3): left-click selects, left-drag box-selects,
## Shift adds, right-click moves (or attacks the enemy under the cursor),
## Ctrl+right-click force-attacks any unit, right-click on an own transport
## boards the selected infantry, H toggles hold position, X stops, R retreats,
## U unloads, B sets engineers to blow up or rebuild a bridge. Control groups:
## Ctrl+1..9 saves the selection, 1..9 recalls it (twice quickly also centres
## the camera on it), Shift+1..9 adds it to the selection. Z / C / V give the
## selection a line / wedge / column formation for later moves (same key again
## turns it off). HQs and supply trucks cannot be selected. Orders go to the simulation as
## commands; selection itself is presentation and never enters the sim.

signal selection_changed(count: int)
## A short note for the player about an order (some units cannot hurt the target).
signal order_note(text: String)
## Ask the camera to centre on a world point (double-tapped control group).
signal focus_requested(world: Vector2)

## Screen pixels the mouse must travel before a press becomes a box.
const DRAG_THRESHOLD: float = 6.0
const MARKER_SEC: float = 0.6
## Number keys for control groups; the hand cards use F1-F4.
const GROUP_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const FORMATION_KEYS: Dictionary = {
	KEY_Z: Formation.Shape.LINE, KEY_C: Formation.Shape.WEDGE, KEY_V: Formation.Shape.COLUMN,
}

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
var _groups: ControlGroups = ControlGroups.new()
## Unit id -> Formation.Shape it moves in; missing = free.
var _formation: Dictionary = {}


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
		var group: int = GROUP_KEYS.find(key.physical_keycode)
		if group >= 0:
			_on_group_key(group, key)
			get_viewport().set_input_as_handled()
			return
		var ids: PackedInt32Array = selected_ids()
		if FORMATION_KEYS.has(key.physical_keycode):
			_set_formation(ids, FORMATION_KEYS[key.physical_keycode])
			get_viewport().set_input_as_handled()
			return
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
			KEY_B:
				if not ids.is_empty():
					_sim.issue(SimCommand.engineer(side, ids))
				get_viewport().set_input_as_handled()


func _on_group_key(group: int, key: InputEventKey) -> void:
	var label: String = OS.get_keycode_string(GROUP_KEYS[group])
	if key.is_command_or_control_pressed():
		var ids: PackedInt32Array = selected_ids()
		_groups.store(group, ids)
		order_note.emit("編組 %s：%d 個單位" % [label, ids.size()] if not ids.is_empty() else "編組 %s 已清除" % label)
		return
	var members: PackedInt32Array = _groups.members(group, func(id: int) -> bool: return _sim.unit(id) != null)
	if not key.shift_pressed:
		_layer.selected.clear()
	for id: int in members:
		if _selectable(_sim.unit(id)):
			_layer.selected[id] = true
	selection_changed.emit(_layer.selected.size())
	if _groups.tap(group, Time.get_ticks_msec()) and not key.shift_pressed:
		_focus_selection()


## Gives `ids` the formation `shape`, or frees them when they all have it.
func _set_formation(ids: PackedInt32Array, shape: Formation.Shape) -> void:
	if ids.is_empty():
		return
	var all_same: bool = true
	for id: int in ids:
		all_same = all_same and _formation.get(id, Formation.Shape.NONE) == shape
	var next: Formation.Shape = Formation.Shape.NONE if all_same else shape
	for id: int in ids:
		if next == Formation.Shape.NONE:
			_formation.erase(id)
		else:
			_formation[id] = next
	order_note.emit("陣形：%s" % Formation.NAMES[next])


## Centres the camera on the middle of the selected units.
func _focus_selection() -> void:
	if _layer.selected.is_empty():
		return
	var sum: Vector2 = Vector2.ZERO
	for id: int in _layer.selected:
		sum += _layer.world_pos(_sim.unit(id))
	focus_requested.emit(sum / float(_layer.selected.size()))


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
	for id: int in _formation.keys():
		if _sim.unit(id) == null:
			_formation.erase(id)
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
		if not _layer.shows(u) or (of_side >= 0 and u.side != of_side):
			continue
		var d: float = _layer.world_pos(u).distance_to(world)
		if d <= _layer.pick_radius(u) and d < best_d:
			best_d = d
			best = u
	return best


func _select_click(world: Vector2, add: bool) -> void:
	var best: SimUnit = _unit_at(world, side)
	if best != null and not _selectable(best):
		best = null
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
		if u.side == side and _selectable(u) and rect.has_point(_layer.world_pos(u)):
			_layer.selected[u.id] = true
	selection_changed.emit(_layer.selected.size())


func _selectable(u: SimUnit) -> bool:
	return u.on_map() and not u.type.structure and not u.is_convoy()


func _order_attack(t: SimUnit) -> void:
	var ids: PackedInt32Array = selected_ids()
	if ids.is_empty():
		return
	_sim.issue(SimCommand.attack(side, ids, t.id))
	var unable: PackedStringArray = PackedStringArray()
	for id: int in ids:
		var u: SimUnit = _sim.unit(id)
		if u == null or u == t:
			continue
		var note: String = ""
		if u.type.weapon == null or not u.type.weapon.may_target(t.type.kind):
			note = "%s打不了%s" % [u.type.display_name, t.type.display_name]
		elif _sim.pen_factor(u, t) <= 0.0:
			note = "%s打不穿%s" % [u.type.display_name, t.type.display_name]
		if note != "" and not unable.has(note):
			unable.append(note)
	if not unable.is_empty():
		order_note.emit("、".join(unable))
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
	var shape: Formation.Shape = _formation.get(ids[0], Formation.Shape.NONE)
	for id: int in ids:
		if _formation.get(id, Formation.Shape.NONE) != shape:
			shape = Formation.Shape.NONE
	if shape == Formation.Shape.NONE or ids.size() < 2:
		_sim.issue(SimCommand.move(side, ids, cell))
	else:
		_order_formation_move(ids, cell, shape)
	_marker_pos = (Vector2(cell) + Vector2(0.5, 0.5)) * float(_style.cell_px)
	_marker_left = MARKER_SEC
	queue_redraw()


## One move per unit to its slot of `shape` around `cell`, facing away from
## where the group is now. Slots on ground the unit cannot cross shift to
## the nearest free cell it can.
func _order_formation_move(ids: PackedInt32Array, cell: Vector2i, shape: Formation.Shape) -> void:
	var cell_size: float = float(_style.cell_px)
	var at: Array[Vector2] = []
	var centre: Vector2 = Vector2.ZERO
	for id: int in ids:
		var p: Vector2 = _layer.world_pos(_sim.unit(id)) / cell_size
		at.append(p)
		centre += p
	centre /= float(ids.size())
	var target: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	var slot_pos: Array[Vector2] = Formation.slots(shape, ids.size(), target, target - centre)
	var pick: PackedInt32Array = Formation.assign(at, slot_pos)
	var used: Dictionary = {}
	for i: int in ids.size():
		var u: SimUnit = _sim.unit(ids[i])
		var dest: Vector2i = _free_cell(Vector2i(slot_pos[pick[i]].floor()), u.type.vehicle, used)
		used[dest] = true
		_sim.issue(SimCommand.move(side, PackedInt32Array([ids[i]]), dest))


## `want`, or the closest in-bounds cell within a few steps that `vehicle`
## can stand on and no other slot took; `want` clamped to the map otherwise.
func _free_cell(want: Vector2i, vehicle: bool, used: Dictionary) -> Vector2i:
	for r: int in 4:
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = want + Vector2i(dx, dy)
				if not used.has(c) and Movement.passable(_sim.map, c, vehicle):
					return c
	return want.clamp(Vector2i.ZERO, Vector2i(_sim.map.width - 1, _sim.map.height - 1))
