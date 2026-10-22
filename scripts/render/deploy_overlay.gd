class_name DeployOverlay
extends Node2D
## While a unit card is dragged: lights up where it may be played (own spawn
## zone, around held points) and marks the cell under the cursor green or red.

const ZONE: Color = Color(0.6, 1.0, 0.5, 0.16)
const OK: Color = Color(0.5, 1.0, 0.4, 0.8)
const BAD: Color = Color(1.0, 0.35, 0.3, 0.8)

var side: int = GameMap.Side.PLAYER
## Card being dragged, SideState.EMPTY for none.
var card: StringName = SideState.EMPTY

var _sim: Simulation
var _style: StylePack
var _spawn_cells: Array[Vector2i] = []
var _cursor: Vector2i = Vector2i(-1, -1)


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


func _process(_delta: float) -> void:
	if card == SideState.EMPTY:
		return
	var c: Vector2i = Vector2i((get_global_mouse_position() / float(_style.cell_px)).floor())
	if c != _cursor:
		_cursor = c
		queue_redraw()


func _draw() -> void:
	if _sim == null or card == SideState.EMPTY or not Card.is_unit(card):
		return
	var s: float = float(_style.cell_px)
	for c: Vector2i in _spawn_cells:
		draw_rect(Rect2(Vector2(c) * s, Vector2(s, s)), ZONE)
	for i: int in _sim.map.pois.size():
		if _sim.poi_owner[i] == side:
			draw_circle(_sim.map.pois[i].center * s, Simulation.DEPLOY_NEAR_POINT_CELLS * s, ZONE)
	if _sim.map.in_bounds(_cursor):
		var ok: bool = _sim.deploy_cell_ok(side, _cursor, UnitType.of(card).vehicle)
		draw_rect(Rect2(Vector2(_cursor) * s, Vector2(s, s)), OK if ok else BAD, false, 2.0)
