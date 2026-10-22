class_name UnitLayer
extends Node2D
## Draws each formation as dev-style figures (soldiers = dots, vehicles =
## boxes pointing where it drives) on a faint footprint, one figure per
## surviving soldier or vehicle, interpolating between the last two simulation
## ticks, plus health and organization bars, hold-position brackets, tracers,
## blasts and wrecks.

const INFANTRY_RADIUS: float = 0.4  # cells, footprint
const SOLDIER_RADIUS: float = 0.085  # cells
const SOLDIER_SPACING: float = 0.21  # cells
## One heavy vehicle (armour HEAVY_ARMOR and up); lighter ones are drawn at
## LIGHT_VEHICLE_SCALE. A vehicle is several soldiers long.
const FIGURE_VEHICLE: Vector2 = Vector2(0.56, 0.32)  # cells, length × width
const FIGURE_VEHICLE_GAP: Vector2 = Vector2(0.1, 0.12)  # cells, across × along
const HEAVY_ARMOR: int = 10
const LIGHT_VEHICLE_SCALE: float = 0.78
const FOOTPRINT_MARGIN: float = 0.14  # cells
const FOOTPRINT_ALPHA: float = 0.28
const TRACER_SEC: float = 0.12
const BLAST_SEC: float = 0.4
const WRECK_SEC: float = 1.5
const HP_BAR: Vector2 = Vector2(1.0, 0.13)  # cells
const HP_GOOD: Color = Color("7be05a")
const HP_LOW: Color = Color("f0b43c")
const HP_BG: Color = Color(0, 0, 0, 0.6)
const ORG_GOOD: Color = Color("5ab4f0")
const ORG_SUPPRESSED: Color = Color("f08c3c")
const ORG_ROUTING: Color = Color("e04848")
const BLAST_COLOR: Color = Color("ffb04a")
## Retreating formations are drawn see-through.
const RETREAT_ALPHA: float = 0.5
const PASSENGER_PIP: float = 0.18  # cells
## Everything drawn for a unit is this much bigger than the sizes above.
const UNIT_SCALE: float = 2.0

var sim: Simulation
## Side whose eyes the view uses: other sides' units show only while seen.
var view_side: int = GameMap.Side.PLAYER
## Fraction of the way from the last tick to the next one, 0..1.
var alpha: float = 0.0
var selected: Dictionary[int, bool] = {}

var _style: StylePack
## Last drawn heading per unit id, so a stopped vehicle keeps its facing.
var _heading: Dictionary[int, float] = {}
## Short-lived effects in world pixels: [from, to, splash_px, seconds_left, side].
var _shots: Array = []
## [world_pos, seconds_left].
var _wrecks: Array = []


func setup(p_sim: Simulation, style: StylePack) -> void:
	sim = p_sim
	_style = style


## Interpolated position of a unit in world pixels.
func world_pos(u: SimUnit) -> Vector2:
	var p: Vector2 = Vector2(u.prev_pos).lerp(Vector2(u.pos), alpha)
	return p / float(Simulation.SUBCELL) * float(_style.cell_px)


## Rough radius in world pixels, used for clicking on a unit.
func pick_radius(u: SimUnit) -> float:
	var cells: float = vehicle_footprint(u.type).x * 0.5 if u.type.vehicle else INFANTRY_RADIUS
	return maxf(cells, 0.4) * UNIT_SCALE * float(_style.cell_px)


## Call after every simulation tick to pick up its shots and deaths.
func capture_tick() -> void:
	var k: float = float(_style.cell_px) / float(Simulation.SUBCELL)
	for shot: Simulation.Shot in sim.shots:
		if shot.side != view_side and not _in_view(shot.from) and not _in_view(shot.to):
			continue
		var life: float = BLAST_SEC if shot.splash > 0 else TRACER_SEC
		_shots.append([Vector2(shot.from) * k, Vector2(shot.to) * k, float(shot.splash) * k, life, shot.side])
	for u: SimUnit in sim.deaths:
		if u.side == view_side or _in_view(u.pos):
			_wrecks.append([Vector2(u.pos) * k, WRECK_SEC])
		_heading.erase(u.id)
		selected.erase(u.id)
	for u: SimUnit in sim.retreated:
		_heading.erase(u.id)
		selected.erase(u.id)
	# Passengers are not on the map, so they cannot stay selected.
	for id: int in selected.keys():
		var p: SimUnit = sim.unit(id)
		if p != null and not p.on_map():
			selected.erase(id)


## Whether a point in sub-cells lies in a cell the view side sees now.
func _in_view(pos: Vector2i) -> bool:
	return sim.vision.cell_visible(view_side, Vector2i(pos.x / Simulation.SUBCELL, pos.y / Simulation.SUBCELL))


func shows(u: SimUnit) -> bool:
	return u.on_map() and sim.vision.sees(view_side, u)


func _process(delta: float) -> void:
	for e: Array in _shots:
		e[3] -= delta
	_shots = _shots.filter(func(e: Array) -> bool: return e[3] > 0.0)
	for w: Array in _wrecks:
		w[1] -= delta
	_wrecks = _wrecks.filter(func(w: Array) -> bool: return w[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var s: float = float(_style.cell_px)
	for w: Array in _wrecks:
		var wc: Color = Color(0.1, 0.1, 0.1, w[1] / WRECK_SEC)
		var r: float = 0.3 * s
		draw_line(w[0] - Vector2(r, r), w[0] + Vector2(r, r), wc, 2.0)
		draw_line(w[0] - Vector2(r, -r), w[0] + Vector2(r, -r), wc, 2.0)
	for u: SimUnit in sim.units:
		if not selected.has(u.id):
			continue
		if u.is_moving():
			_draw_path(u, s)
		var t: SimUnit = sim.unit(u.target_id) if u.forced_target else null
		if t != null and shows(t):
			var tc: Color = _style.unit_colors[GameMap.Side.ENEMY]
			tc.a = 0.6
			draw_line(world_pos(u), world_pos(t), tc, 1.0)
	# Unit figures, bars and markers are drawn UNIT_SCALE times their cell size.
	s *= UNIT_SCALE
	for u: SimUnit in sim.units:
		if not shows(u):
			continue
		var p: Vector2 = world_pos(u)
		var fill: Color = _style.unit_colors[u.side]
		if u.retreating:
			fill.a = RETREAT_ALPHA
		if u.type.vehicle:
			var moved: Vector2 = Vector2(u.pos - u.prev_pos)
			if moved != Vector2.ZERO:
				_heading[u.id] = moved.angle()
			draw_set_transform(p, _heading.get(u.id, 0.0))
			var size: Vector2 = vehicle_footprint(u.type) * s
			draw_rect(Rect2(-size * 0.5, size), Color(fill, FOOTPRINT_ALPHA))
			_draw_vehicles(u.type, u.figures(), fill, s)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p, INFANTRY_RADIUS * s, Color(fill, FOOTPRINT_ALPHA))
			_draw_soldiers(u.figures(), p, fill, s)
		if u.hold != SimUnit.Hold.NONE:
			_draw_hold(u, p, s)
		if not u.passengers.is_empty():
			_draw_passengers(u, p, s)
		if selected.has(u.id):
			draw_arc(p, pick_radius(u) + 3.0, 0.0, TAU, 24, _style.selection, 1.5, true)
		if selected.has(u.id) or u.hp < u.type.max_hp or u.org < u.type.max_org:
			_draw_bars(u, p, s)
	for e: Array in _shots:
		if e[2] > 0.0:
			var a: float = e[3] / BLAST_SEC
			var bc: Color = BLAST_COLOR
			bc.a = a * 0.5
			draw_circle(e[1], e[2], bc)
			bc.a = a
			draw_arc(e[1], e[2], 0.0, TAU, 24, bc, 1.5, true)
		else:
			var lc: Color = _style.unit_colors[e[4]].lightened(0.6)
			lc.a = e[3] / TRACER_SEC
			draw_line(e[0], e[1], lc, 1.5)


## One small square per passenger squad beside the transport, and a ring
## that fills up while they get out.
func _draw_passengers(u: SimUnit, p: Vector2, s: float) -> void:
	var pip: float = PASSENGER_PIP * s
	var start: Vector2 = p + Vector2(-0.5 * s, 0.55 * s)
	for i: int in u.passengers.size():
		var r: Rect2 = Rect2(start + Vector2(i * pip * 1.4, 0.0), Vector2(pip, pip))
		draw_rect(r, _style.selection)
		draw_rect(r, _style.unit_outline, false, 1.0)
	if u.unload_ticks > 0:
		var done: float = 1.0 - float(u.unload_ticks) / Simulation.UNLOAD_TICKS
		draw_arc(p, 0.7 * s, -PI * 0.5, -PI * 0.5 + TAU * done, 24, _style.selection, 2.0, true)


## Corner brackets around a unit holding position; faint while digging in or out.
func _draw_hold(u: SimUnit, p: Vector2, s: float) -> void:
	var c: Color = _style.unit_outline if u.hold == SimUnit.Hold.HELD else Color(_style.unit_outline, 0.4)
	var h: float = 0.6 * s
	var l: float = 0.22 * s
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q: Vector2 = p + corner * h
		draw_line(q, q - Vector2(corner.x * l, 0.0), c, 2.0)
		draw_line(q, q - Vector2(0.0, corner.y * l), c, 2.0)


## Soldiers in rows of up to four, centred on `p`; the last ones go first.
func _draw_soldiers(n: int, p: Vector2, fill: Color, s: float) -> void:
	for pos: Vector2 in figure_offsets(n, 4, Vector2(SOLDIER_SPACING, SOLDIER_SPACING)):
		draw_circle(p + pos * s, SOLDIER_RADIUS * s, fill)
		draw_circle(p + pos * s, SOLDIER_RADIUS * s, _style.unit_outline, false, -1.0)


## Vehicles in columns of two along the driving direction (drawn in the
## unit's rotated frame).
func _draw_vehicles(t: UnitType, n: int, fill: Color, s: float) -> void:
	var fig: Vector2 = vehicle_figure(t)
	var size: Vector2 = fig * s
	for off: Vector2 in figure_offsets(n, _vehicles_per_row(t), _vehicle_spacing(fig)):
		# Rows run across the footprint, so swap axes: columns go nose to tail.
		var c: Vector2 = Vector2(-off.y, off.x) * s
		var body: Rect2 = Rect2(c - size * 0.5, size)
		draw_rect(body, fill)
		draw_rect(body, _style.unit_outline, false, -1.0)
		draw_line(c + Vector2(size.x * 0.1, 0.0), c + Vector2(size.x * 0.5, 0.0), _style.unit_outline, -1.0)


## Size in cells of one of `t`'s vehicles, length × width.
static func vehicle_figure(t: UnitType) -> Vector2:
	return FIGURE_VEHICLE if t.armor >= HEAVY_ARMOR else FIGURE_VEHICLE * LIGHT_VEHICLE_SCALE


## Faint box under a vehicle formation, sized for its full strength.
static func vehicle_footprint(t: UnitType) -> Vector2:
	var fig: Vector2 = vehicle_figure(t)
	var gap: Vector2 = _vehicle_spacing(fig)
	var per_row: int = _vehicles_per_row(t)
	var rows: int = ceili(float(t.figures) / per_row)
	var across: int = mini(per_row, t.figures)
	return Vector2((rows - 1) * gap.y + fig.x, (across - 1) * gap.x + fig.y) + Vector2.ONE * FOOTPRINT_MARGIN


## Platoons drive two abreast, bigger formations three.
static func _vehicles_per_row(t: UnitType) -> int:
	return 2 if t.figures <= 4 else 3


## Centre-to-centre spacing, across × along.
static func _vehicle_spacing(fig: Vector2) -> Vector2:
	return Vector2(fig.y + FIGURE_VEHICLE_GAP.x, fig.x + FIGURE_VEHICLE_GAP.y)


## Offsets in cells for `n` figures laid out in rows of up to `per_row`,
## the whole block centred on zero.
static func figure_offsets(n: int, per_row: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var rows: int = ceili(float(n) / per_row)
	for i: int in n:
		var row: int = i / per_row
		var in_row: int = mini(per_row, n - row * per_row)
		var col: int = i % per_row
		out.append(Vector2((col - (in_row - 1) * 0.5) * spacing.x, (row - (rows - 1) * 0.5) * spacing.y))
	return out


## Health bar with the organization bar under it; organization turns orange
## when suppressed and red with a frame when routing.
func _draw_bars(u: SimUnit, p: Vector2, s: float) -> void:
	var size: Vector2 = HP_BAR * s
	var top: Vector2 = p + Vector2(-size.x * 0.5, -0.9 * s)
	var f: float = clampf(u.hp / u.type.max_hp, 0.0, 1.0)
	draw_rect(Rect2(top, size), HP_BG)
	draw_rect(Rect2(top, Vector2(size.x * f, size.y)), HP_GOOD if f > 0.4 else HP_LOW)
	var otop: Vector2 = top + Vector2(0.0, size.y + 1.0)
	var o: float = clampf(u.org / u.type.max_org, 0.0, 1.0)
	var oc: Color = ORG_ROUTING if u.routing else (ORG_SUPPRESSED if u.is_suppressed() else ORG_GOOD)
	draw_rect(Rect2(otop, size), HP_BG)
	draw_rect(Rect2(otop, Vector2(size.x * o, size.y)), oc)
	if u.routing:
		draw_rect(Rect2(otop, size), ORG_ROUTING, false, 1.0)


func _draw_path(u: SimUnit, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([world_pos(u)])
	for i: int in range(u.path_index, u.path.size()):
		pts.append((Vector2(u.path[i]) + Vector2(0.5, 0.5)) * s)
	var c: Color = _style.order_marker
	c.a = 0.45
	draw_polyline(pts, c, 1.0)
