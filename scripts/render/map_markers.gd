class_name MapMarkers
extends Node2D
## Points of interest (yellow rings) and HQs (side-coloured blocks).

var _map: GameMap
var _style: StylePack


func setup(map: GameMap, style: StylePack) -> void:
	_map = map
	_style = style
	queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	var s: float = _style.cell_px
	for poi: CellGroup in _map.pois:
		var r: float = (sqrt(float(poi.cells.size())) / 2.0 + 0.6) * s
		var c: Vector2 = poi.center * s
		var fill: Color = _style.poi_ring
		fill.a = 0.35
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 64, _style.poi_ring, 3.0, true)
	for hq: CellGroup in _map.hqs:
		var b: Rect2i = hq.bounds()
		var rect: Rect2 = Rect2(Vector2(b.position) * s, Vector2(b.size) * s)
		draw_rect(rect, _style.hq_colors[hq.owner], true)
		draw_rect(rect, Color(0.07, 0.07, 0.07), false, 3.0)
		draw_rect(rect.grow(-5.0), Color(1, 1, 1, 0.9), false, 2.0)
