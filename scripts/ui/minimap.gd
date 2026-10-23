class_name Minimap
extends Control
## Whole-map overview in a corner: terrain in flat colours under the viewing
## side's fog, points of interest by owner, HQs, units as dots (enemies only
## while seen), and the camera's view as a frame. Click or drag on it to move
## the camera there. Reads the simulation and the views, never changes them.

signal focus_requested(world: Vector2)

const FRAME: Color = Color(0.9, 0.92, 0.88, 0.9)
const DOT_PX: float = 3.0
const POI_PX: float = 5.0
const HQ_PX: float = 6.0
## Extra darkening per Vision.Fog value (unexplored, explored, visible).
const FOG_DIM: Array[float] = [0.8, 0.45, 0.0]

var view_side: int = GameMap.Side.PLAYER

var _sim: Simulation
var _units: UnitLayer
var _camera: Camera2D
var _style: StylePack
var _ground: Image
var _img: Image
var _tex: ImageTexture
var _fog_revision: int = -1
var _bridge_revision: int = -1
var _dragging: bool = false


func setup(sim: Simulation, units: UnitLayer, camera: Camera2D, style: StylePack) -> void:
	_sim = sim
	_units = units
	_camera = camera
	_style = style
	_img = Image.create_empty(sim.map.width, sim.map.height, false, Image.FORMAT_RGB8)
	_tex = ImageTexture.create_from_image(_img)
	visible = true


func _process(_delta: float) -> void:
	if _sim == null:
		return
	if _sim.bridges.revision != _bridge_revision:
		_bridge_revision = _sim.bridges.revision
		_build_ground()
		_fog_revision = -1
	if _sim.vision.revision != _fog_revision:
		_fog_revision = _sim.vision.revision
		_apply_fog()
	queue_redraw()


func _build_ground() -> void:
	var m: GameMap = _sim.map
	_ground = Image.create_empty(m.width, m.height, false, Image.FORMAT_RGB8)
	for y: int in m.height:
		for x: int in m.width:
			var c: Vector2i = Vector2i(x, y)
			var col: Color = _style.terrain_colors[m.terrain_at(c)]
			_ground.set_pixel(x, y, StylePack.shade(col, _style.height_shade[clampi(m.elevation_at(c), 0, _style.height_shade.size() - 1)]))


func _apply_fog() -> void:
	var m: GameMap = _sim.map
	var f: PackedByteArray = _sim.vision.fog[view_side]
	for y: int in m.height:
		for x: int in m.width:
			_img.set_pixel(x, y, _ground.get_pixel(x, y).darkened(FOG_DIM[f[y * m.width + x]]))
	_tex.update(_img)


func _draw() -> void:
	if _sim == null:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1), box)
	var area: Rect2 = _map_rect()
	draw_texture_rect(_tex, area, false)
	var k: float = area.size.x / _sim.map.width
	for i: int in _sim.map.pois.size():
		var own: int = _sim.points.owner[i]
		var col: Color = UiTheme.side_color(own) if own >= 0 else UiTheme.UNKNOWN
		var c: Vector2 = area.position + _sim.map.pois[i].center * k
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -POI_PX), c + Vector2(POI_PX, 0), c + Vector2(0, POI_PX), c + Vector2(-POI_PX, 0)]), col)
		draw_polyline(PackedVector2Array([c + Vector2(0, -POI_PX), c + Vector2(POI_PX, 0), c + Vector2(0, POI_PX), c + Vector2(-POI_PX, 0), c + Vector2(0, -POI_PX)]), UiTheme.GRAPHITE, 1.0)
	for side: int in 2:
		var hq: SimUnit = _sim.hq[side]
		if hq != null:
			var hp: Vector2 = area.position + _cell_of(hq) * k
			draw_rect(Rect2(hp - Vector2.ONE * HQ_PX * 0.5, Vector2.ONE * HQ_PX), UiTheme.side_color(side))
			draw_rect(Rect2(hp - Vector2.ONE * HQ_PX * 0.5, Vector2.ONE * HQ_PX), UiTheme.GRAPHITE, false, 1.0)
	for u: SimUnit in _sim.units:
		if u.type.structure or u.carrier_id != 0 or not _units.shows(u):
			continue
		var p: Vector2 = area.position + _cell_of(u) * k
		var col: Color = UiTheme.side_color(u.side)
		if _units.selected.has(u.id):
			col = UiTheme.TEXT
		draw_rect(Rect2(p - Vector2.ONE * DOT_PX * 0.5, Vector2.ONE * DOT_PX), col)
	# Camera view.
	var inv: Transform2D = _camera.get_canvas_transform().affine_inverse()
	var view: Vector2 = _camera.get_viewport_rect().size
	var a: Vector2 = inv * Vector2.ZERO / float(_style.cell_px)
	var b: Vector2 = inv * view / float(_style.cell_px)
	var frame: Rect2 = Rect2(area.position + a * k, (b - a) * k).intersection(area)
	draw_rect(frame, FRAME, false, 1.0)


## Square map area inside the panel's border.
func _map_rect() -> Rect2:
	var inner: Vector2 = size - Vector2(8, 8)
	var k: float = minf(inner.x / _sim.map.width, inner.y / _sim.map.height)
	var s: Vector2 = Vector2(_sim.map.width, _sim.map.height) * k
	return Rect2((size - s) * 0.5, s)


func _cell_of(u: SimUnit) -> Vector2:
	return _units.world_pos(u) / float(_style.cell_px)


func _gui_input(event: InputEvent) -> void:
	if _sim == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if mb.pressed:
			_focus(mb.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_focus((event as InputEventMouseMotion).position)
		accept_event()


func _focus(local: Vector2) -> void:
	var area: Rect2 = _map_rect()
	var cell: Vector2 = (local - area.position) / (area.size.x / _sim.map.width)
	focus_requested.emit(cell * float(_style.cell_px))
