class_name FogLayer
extends Sprite2D
## Draws one side's fog of war over the map: black where it has never looked,
## dimmed where it has looked before, clear where it sees now. One texel per
## cell, stretched with linear filtering so the edges come out soft.

var view_side: int = GameMap.Side.PLAYER

var _sim: Simulation
var _img: Image
var _tex: ImageTexture
var _revision: int = -1
var _shade: PackedByteArray = PackedByteArray()


func setup(sim: Simulation, style: StylePack) -> void:
	_sim = sim
	_img = Image.create_empty(sim.map.width, sim.map.height, false, Image.FORMAT_LA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex
	centered = false
	scale = Vector2(style.cell_px, style.cell_px)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Alpha per Vision.Fog value, as luminance 0 + alpha pairs.
	_shade = PackedByteArray([roundi(style.fog_unexplored * 255), roundi(style.fog_explored * 255), 0])
	_refresh()


func _process(_delta: float) -> void:
	if _sim != null and _sim.vision.revision != _revision:
		_refresh()


func _refresh() -> void:
	_revision = _sim.vision.revision
	var f: PackedByteArray = _sim.vision.fog[view_side]
	var data: PackedByteArray = PackedByteArray()
	data.resize(f.size() * 2)
	for i: int in f.size():
		data[i * 2 + 1] = _shade[f[i]]
	_img.set_data(_sim.map.width, _sim.map.height, false, Image.FORMAT_LA8, data)
	_tex.update(_img)
