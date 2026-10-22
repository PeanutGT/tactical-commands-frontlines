extends Node2D
## Map view: loads a map, runs the simulation at a fixed tick rate, builds the
## render layers and wires input and the HUD.

signal map_loaded(map: GameMap)
signal cursor_cell_changed(cell: Vector2i)

@export_dir var map_dir: String = "res://maps/hecheng"
@export var sim_seed: int = 1

## Most ticks run in one frame, so a long hitch does not spiral.
const MAX_TICKS_PER_FRAME: int = 5

@onready var _terrain: TerrainLayer = $TerrainLayer
@onready var _markers: MapMarkers = $Markers
@onready var _grid: GridOverlay = $Grid
@onready var _units: UnitLayer = $Units
@onready var _selection: SelectionController = $Selection
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $Hud

var map: GameMap
var sim: Simulation
var style: StylePack = StylePack.dev()
var _cursor: Vector2i = Vector2i(-1, -1)
var _tick_time: float = 0.0


func _ready() -> void:
	map_loaded.connect(_hud.show_map)
	cursor_cell_changed.connect(_hud.set_cursor)
	_selection.selection_changed.connect(_hud.set_selection)
	_camera.zoom_changed.connect(_hud.set_zoom)

	map = MapLoader.load_map(map_dir)
	if map == null:
		return
	if not map.unknown_colors.is_empty():
		var first: MapParser.UnknownColor = map.unknown_colors[0]
		push_warning("%s: %d unrecognised colours, first at %s rgb %s" % [map.config.id, map.unknown_colors.size(), first.pos, first.rgb])

	_terrain.build(map, style)
	_markers.setup(map, style)
	_grid.setup(map, style)
	_grid.visible = false
	sim = Simulation.new(map, sim_seed)
	_spawn_placeholders()
	_units.setup(sim, style)
	_selection.setup(sim, _units, style)
	map_loaded.emit(map)
	_camera.setup(Vector2(map.width, map.height) * style.cell_px)


func _process(delta: float) -> void:
	if map == null:
		return
	_tick_time += delta
	var ticks: int = 0
	while _tick_time >= Simulation.TICK_SEC and ticks < MAX_TICKS_PER_FRAME:
		sim.step()
		_units.capture_tick()
		_tick_time -= Simulation.TICK_SEC
		ticks += 1
	if ticks > 0:
		_selection.prune_dead()
		_hud.set_score(sim.score[GameMap.Side.PLAYER], sim.ff_penalty[GameMap.Side.PLAYER])
	if ticks == MAX_TICKS_PER_FRAME:
		_tick_time = minf(_tick_time, Simulation.TICK_SEC)
	_units.alpha = _tick_time / Simulation.TICK_SEC

	var cell: Vector2i = Vector2i((get_global_mouse_position() / float(style.cell_px)).floor())
	if not map.in_bounds(cell):
		cell = Vector2i(-1, -1)
	if cell != _cursor:
		_cursor = cell
		cursor_cell_changed.emit(cell)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_G:
			_grid.visible = not _grid.visible
		KEY_F, KEY_HOME:
			_camera.fit()


## M3 test units: a mixed group at our spawn, enemies at theirs, a held
## enemy outpost at the objective nearest to us and an enemy tank and mortar
## at the next one.
func _spawn_placeholders() -> void:
	var ours: Array[UnitType] = [
		UnitType.infantry(), UnitType.infantry(), UnitType.infantry(), UnitType.infantry(),
		UnitType.scout_car(), UnitType.tank(), UnitType.tank(), UnitType.mortar(),
	]
	var theirs: Array[UnitType] = [UnitType.infantry(), UnitType.infantry(), UnitType.tank()]
	if map.player_spawn == null or map.enemy_spawn == null:
		return
	var home: Vector2 = map.player_spawn.center
	_spawn_group(ours, GameMap.Side.PLAYER, Vector2i(home.round()))
	_spawn_group(theirs, GameMap.Side.ENEMY, Vector2i(map.enemy_spawn.center.round()))
	var pois: Array[CellGroup] = map.pois.duplicate()
	pois.sort_custom(func(a: CellGroup, b: CellGroup) -> bool:
		return a.center.distance_squared_to(home) < b.center.distance_squared_to(home))
	if pois.size() >= 1:
		var outpost: PackedInt32Array = _spawn_group([UnitType.infantry(), UnitType.infantry(), UnitType.scout_car()] as Array[UnitType],
			GameMap.Side.ENEMY, Vector2i(pois[0].center.round()))
		sim.issue(SimCommand.hold(GameMap.Side.ENEMY, outpost))
	if pois.size() >= 2:
		_spawn_group([UnitType.tank(), UnitType.mortar()] as Array[UnitType], GameMap.Side.ENEMY, Vector2i(pois[1].center.round()))


## Spawns `types` spread out around `around`; returns their ids.
func _spawn_group(types: Array[UnitType], side: int, around: Vector2i) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for off: Vector2i in Simulation.slot_offsets(types.size() * 4):
		if ids.size() == types.size():
			break
		var c: Vector2i = around + off * 2
		if Movement.passable(sim.map, c, types[ids.size()].vehicle):
			ids.append(sim.spawn(types[ids.size()], side, c).id)
	return ids
