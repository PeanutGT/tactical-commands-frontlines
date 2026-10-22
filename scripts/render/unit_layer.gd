class_name UnitLayer
extends Node2D
## Draws units as dev-style shapes (infantry = circle, vehicle = box pointing
## where it drives), interpolating between the last two simulation ticks, plus
## health bars, hold-position brackets, tracers, blasts and wrecks.

const INFANTRY_RADIUS: float = 0.32  # cells
const VEHICLE_SIZE: Vector2 = Vector2(0.95, 0.6)  # cells, length × width
const TRACER_SEC: float = 0.12
const BLAST_SEC: float = 0.4
const WRECK_SEC: float = 1.5
const HP_BAR: Vector2 = Vector2(0.8, 0.12)  # cells
const HP_GOOD: Color = Color("7be05a")
const HP_LOW: Color = Color("f0b43c")
const HP_BG: Color = Color(0, 0, 0, 0.6)
const BLAST_COLOR: Color = Color("ffb04a")

var sim: Simulation
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
	var cells: float = VEHICLE_SIZE.x * 0.5 if u.type.vehicle else INFANTRY_RADIUS
	return maxf(cells, 0.4) * float(_style.cell_px)


## Call after every simulation tick to pick up its shots and deaths.
func capture_tick() -> void:
	var k: float = float(_style.cell_px) / float(Simulation.SUBCELL)
	for shot: Simulation.Shot in sim.shots:
		var life: float = BLAST_SEC if shot.splash > 0 else TRACER_SEC
		_shots.append([Vector2(shot.from) * k, Vector2(shot.to) * k, float(shot.splash) * k, life, shot.side])
	for u: SimUnit in sim.deaths:
		_wrecks.append([Vector2(u.pos) * k, WRECK_SEC])
		_heading.erase(u.id)
		selected.erase(u.id)


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
		if t != null:
			var tc: Color = _style.unit_colors[GameMap.Side.ENEMY]
			tc.a = 0.6
			draw_line(world_pos(u), world_pos(t), tc, 1.0)
	for u: SimUnit in sim.units:
		var p: Vector2 = world_pos(u)
		var fill: Color = _style.unit_colors[u.side]
		if u.type.vehicle:
			var moved: Vector2 = Vector2(u.pos - u.prev_pos)
			if moved != Vector2.ZERO:
				_heading[u.id] = moved.angle()
			draw_set_transform(p, _heading.get(u.id, 0.0))
			var size: Vector2 = VEHICLE_SIZE * s
			var body: Rect2 = Rect2(-size * 0.5, size)
			draw_rect(body, fill)
			draw_rect(body, _style.unit_outline, false, 1.5)
			# Nose mark shows the driving direction.
			draw_line(Vector2(size.x * 0.1, 0.0), Vector2(size.x * 0.5, 0.0), _style.unit_outline, 2.0)
			if u.type.id == &"tank":
				draw_circle(Vector2.ZERO, size.y * 0.3, _style.unit_outline, false, 1.5)
			elif u.type.id == &"mortar":
				draw_circle(Vector2.ZERO, size.y * 0.22, _style.unit_outline)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p, INFANTRY_RADIUS * s, fill)
			draw_circle(p, INFANTRY_RADIUS * s, _style.unit_outline, false, 1.5)
		if u.hold != SimUnit.Hold.NONE:
			_draw_hold(u, p, s)
		if selected.has(u.id):
			draw_arc(p, pick_radius(u) + 3.0, 0.0, TAU, 24, _style.selection, 1.5, true)
		if selected.has(u.id) or u.hp < u.type.max_hp:
			_draw_hp(u, p, s)
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


## Corner brackets around a unit holding position; faint while digging in or out.
func _draw_hold(u: SimUnit, p: Vector2, s: float) -> void:
	var c: Color = _style.unit_outline if u.hold == SimUnit.Hold.HELD else Color(_style.unit_outline, 0.4)
	var h: float = 0.45 * s
	var l: float = 0.18 * s
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q: Vector2 = p + corner * h
		draw_line(q, q - Vector2(corner.x * l, 0.0), c, 2.0)
		draw_line(q, q - Vector2(0.0, corner.y * l), c, 2.0)


func _draw_hp(u: SimUnit, p: Vector2, s: float) -> void:
	var size: Vector2 = HP_BAR * s
	var top: Vector2 = p + Vector2(-size.x * 0.5, -0.62 * s)
	var f: float = clampf(u.hp / u.type.max_hp, 0.0, 1.0)
	draw_rect(Rect2(top, size), HP_BG)
	draw_rect(Rect2(top, Vector2(size.x * f, size.y)), HP_GOOD if f > 0.4 else HP_LOW)


func _draw_path(u: SimUnit, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([world_pos(u)])
	for i: int in range(u.path_index, u.path.size()):
		pts.append((Vector2(u.path[i]) + Vector2(0.5, 0.5)) * s)
	var c: Color = _style.order_marker
	c.a = 0.45
	draw_polyline(pts, c, 1.0)
