extends Node2D
## Map view: loads a map, builds the render layers and wires the HUD.

signal map_loaded(map: GameMap)
signal cursor_cell_changed(cell: Vector2i)

@export_dir var map_dir: String = "res://maps/hecheng"

@onready var _terrain: TerrainLayer = $TerrainLayer
@onready var _markers: MapMarkers = $Markers
@onready var _grid: GridOverlay = $Grid
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $Hud

var map: GameMap
var style: StylePack = StylePack.dev()
var _cursor: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	map_loaded.connect(_hud.show_map)
	cursor_cell_changed.connect(_hud.set_cursor)
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
	map_loaded.emit(map)
	_camera.setup(Vector2(map.width, map.height) * style.cell_px)


func _process(_delta: float) -> void:
	if map == null:
		return
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
