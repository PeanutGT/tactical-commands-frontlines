class_name MapMarkers
extends Node2D
## Points of interest (rings: yellow while nobody holds them, else the
## holder's colour, with an arc filling up while a side takes one), HQs
## (side-coloured blocks with a health bar), bridge durability, and support
## cards on the ground: smoke for everyone, the viewing side's own drones and
## incoming shells.

const SMOKE: Color = Color(0.82, 0.84, 0.8, 0.55)
const DRONE: Color = Color(0.55, 0.85, 1.0, 0.7)
const INCOMING: Color = Color(1.0, 0.5, 0.25, 0.8)
const BAR_BG: Color = Color(0, 0, 0, 0.65)
const BAR_OK: Color = Color("7be05a")
const BAR_LOW: Color = Color("f0b43c")
const FUSE: Color = Color("ff5040")

## Set once a match starts; until then points are drawn unheld.
var sim: Simulation
var view_side: int = GameMap.Side.PLAYER

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
		if sim != null and sim.hq[hq.owner] != null:
			var h: SimUnit = sim.hq[hq.owner]
			_bar(Vector2(rect.position.x, rect.position.y - 10.0), rect.size.x, h.hp / h.type.max_hp)
	if sim == null:
		return
	_draw_bridges(s)
	_draw_effects(s)


func _bar(at: Vector2, width: float, share: float) -> void:
	var f: float = clampf(share, 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(width, 6.0)), BAR_BG)
	draw_rect(Rect2(at, Vector2(width * f, 6.0)), BAR_OK if f > 0.5 else BAR_LOW)


## A durability bar over each damaged standing bridge; a red outline while a
## charge is burning on it.
func _draw_bridges(s: float) -> void:
	var b: Bridges = sim.bridges
	for i: int in _map.bridges.size():
		var r: Rect2i = _map.bridges[i].bounds()
		var rect: Rect2 = Rect2(Vector2(r.position) * s, Vector2(r.size) * s)
		if not b.broken[i] and b.hp[i] < b.max_hp[i]:
			_bar(Vector2(rect.position.x, rect.get_center().y - 3.0), rect.size.x, b.hp[i] / b.max_hp[i])
		for f: Array in b.fuses:
			if f[0] == i:
				draw_rect(rect, FUSE, false, 3.0)


func _draw_effects(s: float) -> void:
	for z: Vector3 in sim.vision.smoke_zones:
		draw_circle(Vector2(z.x, z.y) * s, z.z * s, SMOKE)
	for d: Vector3 in sim.vision.drones[view_side]:
		draw_arc(Vector2(d.x, d.y) * s, d.z * s, 0.0, TAU, 64, DRONE, 2.0, true)
	for e: SupportEffect in sim.effects:
		if e.side != view_side or e.delay <= 0:
			continue
		var at: Vector2 = (Vector2(e.cell) + Vector2(0.5, 0.5)) * s
		if e.card == &"artillery":
			draw_arc(at, sim.std_cells(Support.ARTILLERY_RADIUS) * s, 0.0, TAU, 48, INCOMING, 2.0, true)
		else:
			var d: Vector2 = e.dir * sim.std_cells(Support.BARRAGE_LENGTH) * 0.5 * s
			draw_line(at - d, at + d, INCOMING, 2.0)
