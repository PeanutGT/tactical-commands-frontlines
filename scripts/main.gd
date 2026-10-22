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
		_tick_time -= Simulation.TICK_SEC
		ticks += 1
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


## M2 test units: a mixed group at our spawn and a few enemies at theirs.
func _spawn_placeholders() -> void:
	var ours: Array[UnitType] = [
		UnitType.infantry(), UnitType.infantry(), UnitType.infantry(), UnitType.infantry(),
		UnitType.scout_car(), UnitType.tank(), UnitType.tank(),
	]
	var theirs: Array[UnitType] = [UnitType.infantry(), UnitType.infantry(), UnitType.tank()]
	if map.player_spawn != null:
		_spawn_group(ours, GameMap.Side.PLAYER, Vector2i(map.player_spawn.center.round()))
	if map.enemy_spawn != null:
		_spawn_group(theirs, GameMap.Side.ENEMY, Vector2i(map.enemy_spawn.center.round()))


func _spawn_group(types: Array[UnitType], side: int, around: Vector2i) -> void:
	var i: int = 0
	for off: Vector2i in Simulation.slot_offsets(types.size() * 4):
		if i == types.size():
			return
		var c: Vector2i = around + off * 2
		if Movement.passable(sim.map, c, types[i].vehicle):
			sim.spawn(types[i], side, c)
			i += 1
