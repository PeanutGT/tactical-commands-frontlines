class_name MapMarkers
extends Node2D
## Points of interest (rings: yellow while nobody holds them, else the
## holder's colour, with an arc filling up while a side takes one) and HQs
## (side-coloured blocks).

## Set once a match starts; until then points are drawn unheld.
var sim: Simulation

var _map: GameMap
var _style: StylePack


func setup(map: GameMap, style: StylePack) -> void:
	_map = map
	_style = style
	queue_redraw()


func _process(_delta: float) -> void:
	if sim != null:
		queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	var s: float = _style.cell_px
	for i: int in _map.pois.size():
		var poi: CellGroup = _map.pois[i]
		var r: float = (sqrt(float(poi.cells.size())) / 2.0 + 0.6) * s
		var c: Vector2 = poi.center * s
		var ring: Color = _style.poi_ring
		if sim != null and sim.poi_owner[i] != CellGroup.NO_OWNER:
			ring = _style.hq_colors[sim.poi_owner[i]]
		var fill: Color = ring
		fill.a = 0.35
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 64, ring, 3.0, true)
		if sim != null and sim.points.taker[i] != CellGroup.NO_OWNER:
			var a: float = TAU * sim.points.share(i)
			draw_arc(c, r + 4.0, -PI / 2.0, -PI / 2.0 + a, 48, _style.hq_colors[sim.points.taker[i]], 4.0, true)
	for hq: CellGroup in _map.hqs:
		var b: Rect2i = hq.bounds()
		var rect: Rect2 = Rect2(Vector2(b.position) * s, Vector2(b.size) * s)
		draw_rect(rect, _style.hq_colors[hq.owner], true)
		draw_rect(rect, Color(0.07, 0.07, 0.07), false, 3.0)
		draw_rect(rect.grow(-5.0), Color(1, 1, 1, 0.9), false, 2.0)
