class_name DeployOverlay
extends Node2D
## While a card is dragged: for a unit card, lights up where it may be played
## (own spawn zone, around held points); for a support card, shows its reach
## around the cursor. The cell under the cursor is marked green or red. While
## a 運補車隊 waits for its destination, rings the places it may drive to.

const ZONE: Color = Color(0.6, 1.0, 0.5, 0.16)
const OK: Color = Color(0.5, 1.0, 0.4, 0.8)
const BAD: Color = Color(1.0, 0.35, 0.3, 0.8)
const REACH: Color = Color(1.0, 0.85, 0.4, 0.22)
## Radius drawn around the cursor per support card, in standard cells.
const RADIUS: Dictionary[StringName, float] = {
	&"smoke": Support.SMOKE_RADIUS, &"artillery": Support.ARTILLERY_RADIUS,
	&"drone_recon": Support.DRONE_RADIUS, &"aps": Support.APS_RADIUS,
	&"armored_assault": Support.ASSAULT_RADIUS,
}

var side: int = GameMap.Side.PLAYER
## Card being dragged, SideState.EMPTY for none.
var card: StringName = SideState.EMPTY

var _sim: Simulation
var _style: StylePack
var _spawn_cells: Array[Vector2i] = []
var _cursor: Vector2i = Vector2i(-1, -1)
## Start cell of a 運補車隊 waiting for its destination, (-1, -1) for none.
var _convoy: Vector2i = Vector2i(-1, -1)


func setup(sim: Simulation, style: StylePack) -> void:
	_sim = sim
	_style = style
	var t: int = Terrain.Type.PLAYER_SPAWN if side == GameMap.Side.PLAYER else Terrain.Type.ENEMY_SPAWN
	for y: int in sim.map.height:
		for x: int in sim.map.width:
			if sim.map.terrain_at(Vector2i(x, y)) == t:
				_spawn_cells.append(Vector2i(x, y))


func set_card(id: StringName) -> void:
	card = id
	queue_redraw()


func set_convoy(start: Vector2i) -> void:
	_convoy = start
	queue_redraw()


func _process(_delta: float) -> void:
	if card == SideState.EMPTY and _convoy == Vector2i(-1, -1):
		return
	var c: Vector2i = Vector2i((get_global_mouse_position() / float(_style.cell_px)).floor())
	if c != _cursor:
		_cursor = c
		queue_redraw()


func _draw() -> void:
	if _sim == null:
		return
	var s: float = float(_style.cell_px)
	if _convoy != Vector2i(-1, -1):
		_draw_convoy_goals(s)
		return
	if card == SideState.EMPTY:
		return
	if Card.is_support(card):
		_draw_support(s)
		return
	for c: Vector2i in _spawn_cells:
		draw_rect(Rect2(Vector2(c) * s, Vector2(s, s)), ZONE)
	for i: int in _sim.map.pois.size():
		if _sim.poi_owner[i] == side and not _sim.points.under_attack(i, side):
			draw_circle(_sim.map.pois[i].center * s, Simulation.DEPLOY_NEAR_POINT_CELLS * s, ZONE)
	if _sim.map.in_bounds(_cursor):
		var ok: bool = _sim.deploy_cell_ok(side, _cursor, UnitType.of(card).vehicle)
		draw_rect(Rect2(Vector2(_cursor) * s, Vector2(s, s)), OK if ok else BAD, false, 2.0)


func _draw_support(s: float) -> void:
	if card == &"supply_convoy":
		for i: int in _sim.map.pois.size():
			if _sim.poi_owner[i] == side and not _sim.points.under_attack(i, side):
				draw_circle(_sim.map.pois[i].center * s, Simulation.DEPLOY_NEAR_POINT_CELLS * s, ZONE)
	if not _sim.map.in_bounds(_cursor):
		return
	var at: Vector2 = (Vector2(_cursor) + Vector2(0.5, 0.5)) * s
	if RADIUS.has(card):
		draw_circle(at, _sim.std_cells(RADIUS[card]) * s, REACH)
	elif card == &"barrage":
		var d: Vector2 = Support.barrage_dir(_sim, side, _cursor) * _sim.std_cells(Support.BARRAGE_LENGTH) * 0.5 * s
		draw_line(at - d, at + d, Color(REACH, 0.6), _sim.std_cells(Support.LINE_HALF_WIDTH) * 2.0 * s)
	var ok: bool = Support.can_aim(_sim, side, card, _cursor)
	draw_rect(Rect2(Vector2(_cursor) * s, Vector2(s, s)), OK if ok else BAD, false, 2.0)


## Rings every held point (but the start) and the HQ a truck may drive to.
func _draw_convoy_goals(s: float) -> void:
	var from: int = _sim.near_own_point(side, _convoy)
	for i: int in _sim.map.pois.size():
		if _sim.poi_owner[i] == side and i != from:
			draw_arc(_sim.map.pois[i].center * s, CapturePoints.RADIUS_CELLS * s, 0.0, TAU, 48, OK, 3.0, true)
	var h: SimUnit = _sim.hq[side]
	if h != null:
		draw_arc(Vector2(h.pos) / Simulation.SUBCELL * s, Simulation.CONVOY_HQ_REACH_CELLS * s, 0.0, TAU, 48, OK, 3.0, true)
	draw_circle((Vector2(_convoy) + Vector2(0.5, 0.5)) * s, 0.4 * s, OK)
