class_name UnitLayer
extends Node2D
## Draws each formation on a faint footprint, one figure per surviving soldier
## or vehicle, interpolating between the last two simulation ticks, plus
## health and organization bars, hold-position brackets, engineer work rings,
## support-card markers, tracers, blasts and wrecks. HQs are drawn by
## MapMarkers.
##
## Figures use the style pack's UnitArt pictures, tinted per side, when the
## type has one: turrets turn towards the target, guns flash and recoil,
## tracks scroll and hulls sway while driving, soldiers bob as they walk,
## lost vehicles blow up and leave a wreck, and routing formations flicker
## under a white flag. Types without pictures (and the dev pack) are drawn as
## dots and boxes. All of this is view-only; the simulation is not touched.

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
const SHIELD: Color = Color("d8e4f0")
const BUFF: Color = Color("9cf06a")
const WORK: Color = Color("ffd24a")
## Click radius of an HQ, in cells.
const HQ_PICK: float = 1.6
## Everything drawn for a unit is this much bigger than the sizes above.
const UNIT_SCALE: float = 2.0
## Picture box side per vehicle length, and per soldier, in cells.
const VEHICLE_BOX: float = 1.2
const SOLDIER_BOX: float = 0.34
## Turret (and aiming soldier) turn rate, radians per second.
const TURRET_TURN: float = 3.5
## Gun kick-back, in picture pixels, easing out over RECOIL_SEC.
const RECOIL_PX: float = 5.0
const RECOIL_SEC: float = 0.25
const FLASH_SEC: float = 0.07
const FLASH: Color = Color("fff2b0")
## Driving sway (radians) and walking bob (cells), with their rates.
const SWAY: float = 0.03
const SWAY_RATE: float = 9.0
const BOB: float = 0.025
const BOB_RATE: float = 13.0
## Track link spacing, in picture pixels.
const TRACK_PITCH: float = 4.0
const SPARK_SEC: float = 0.16
const SPARK: Color = Color("ffe08a")
## Explosion when a vehicle is lost, then the wreck stays and fades out.
const BOOM_SEC: float = 0.6
const HULK_SEC: float = 25.0
const BODY_SEC: float = 10.0
const HULK_FADE_SEC: float = 3.0
const SMOKE: Color = Color(0.22, 0.2, 0.18)
const ROUT_FLICKER: float = 7.0
const FLAG: Color = Color("f4f4ee")
## Pictures are tinted with the side colour moved this far towards white, so
## their grey shading still shows.
const PICTURE_TINT_LIGHTEN: float = 0.3

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
## [world_pos, seconds_left], for units without pictures.
var _wrecks: Array = []
## Wrecks of pictured figures: [transform, UnitArt, box, age].
var _hulks: Array = []
## Bullet strikes: [world_pos, seconds_left, angle].
var _sparks: Array = []
var _time: float = 0.0
var _delta: float = 0.0
## Per unit id: turret (or aim) angle, seconds left of gun recoil, cells
## driven (for the track pattern), last drawn centre, and the figures last
## drawn [transforms, UnitArt, box] so lost ones can be left as wrecks.
var _aim: Dictionary[int, float] = {}
var _recoil: Dictionary[int, float] = {}
var _travel: Dictionary[int, float] = {}
var _last_pos: Dictionary[int, Vector2] = {}
var _figs: Dictionary[int, Array] = {}


func setup(p_sim: Simulation, style: StylePack) -> void:
	sim = p_sim
	_style = style


## Interpolated position of a unit in world pixels.
func world_pos(u: SimUnit) -> Vector2:
	var p: Vector2 = Vector2(u.prev_pos).lerp(Vector2(u.pos), alpha)
	return p / float(Simulation.SUBCELL) * float(_style.cell_px)


## Rough radius in world pixels, used for clicking on a unit.
func pick_radius(u: SimUnit) -> float:
	if u.type.structure:
		return HQ_PICK * float(_style.cell_px)
	var cells: float = vehicle_footprint(u.type).x * 0.5 if u.type.vehicle else INFANTRY_RADIUS
	return maxf(cells, 0.4) * UNIT_SCALE * float(_style.cell_px)


## Call after every simulation tick to pick up its shots and deaths.
func capture_tick() -> void:
	var k: float = float(_style.cell_px) / float(Simulation.SUBCELL)
	# Shots carry no shooter, so find it by where it stands.
	var shooter_at: Dictionary[Vector2i, int] = {}
	if not sim.shots.is_empty():
		for u: SimUnit in sim.units:
			if u.on_map() and u.type.weapon != null:
				shooter_at[u.pos] = u.id
	for shot: Simulation.Shot in sim.shots:
		if shot.from != shot.to and shooter_at.has(shot.from):
			_recoil[shooter_at[shot.from]] = RECOIL_SEC
		if shot.side != view_side and not _in_view(shot.from) and not _in_view(shot.to):
			continue
		var life: float = BLAST_SEC if shot.splash > 0 else TRACER_SEC
		_shots.append([Vector2(shot.from) * k, Vector2(shot.to) * k, float(shot.splash) * k, life, shot.side])
		if shot.splash == 0:
			var jitter: Vector2 = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * float(_style.cell_px)
			_sparks.append([Vector2(shot.to) * k + jitter, SPARK_SEC + TRACER_SEC, randf() * TAU])
	for u: SimUnit in sim.deaths:
		if u.side == view_side or _in_view(u.pos):
			if _figs.has(u.id):
				_leave_wrecks(_figs[u.id], 0)
			else:
				_wrecks.append([Vector2(u.pos) * k, WRECK_SEC])
		_forget(u.id)
	for u: SimUnit in sim.retreated:
		_forget(u.id)
	# Passengers are not on the map, so they cannot stay selected.
	for id: int in selected.keys():
		var p: SimUnit = sim.unit(id)
		if p != null and not p.on_map():
			selected.erase(id)


func _forget(id: int) -> void:
	_heading.erase(id)
	_aim.erase(id)
	_recoil.erase(id)
	_travel.erase(id)
	_last_pos.erase(id)
	_figs.erase(id)
	selected.erase(id)


## Leaves a wreck for every figure from index `from` of a [transforms,
## UnitArt, box] record.
func _leave_wrecks(rec: Array, from: int) -> void:
	var xforms: Array = rec[0]
	for i: int in range(from, xforms.size()):
		_hulks.append([xforms[i], rec[1], rec[2], 0.0])


## Whether a point in sub-cells lies in a cell the view side sees now.
func _in_view(pos: Vector2i) -> bool:
	return sim.vision.cell_visible(view_side, Vector2i(pos.x / Simulation.SUBCELL, pos.y / Simulation.SUBCELL))


func shows(u: SimUnit) -> bool:
	return u.on_map() and sim.vision.sees(view_side, u)


func _process(delta: float) -> void:
	_time += delta
	_delta = delta
	for id: int in _recoil.keys():
		_recoil[id] -= delta
		if _recoil[id] <= 0.0:
			_recoil.erase(id)
	for sp: Array in _sparks:
		sp[1] -= delta
	_sparks = _sparks.filter(func(sp: Array) -> bool: return sp[1] > 0.0)
	for h: Array in _hulks:
		h[3] += delta
	_hulks = _hulks.filter(func(h: Array) -> bool: return h[3] < (BODY_SEC if (h[1] as UnitArt).infantry else HULK_SEC))
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
	for h: Array in _hulks:
		_draw_hulk(h)
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
		if not shows(u) or u.type.structure:
			continue
		var p: Vector2 = world_pos(u)
		var fill: Color = _style.unit_colors[u.side]
		if u.retreating:
			fill.a = RETREAT_ALPHA
		if u.routing:
			fill.a *= 0.55 + 0.45 * absf(sin(_time * ROUT_FLICKER))
		var art: UnitArt = _style.unit_art.get(u.type.id)
		if art != null:
			_draw_pictured(u, art, p, fill, s)
		elif u.type.vehicle:
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
		if u.routing:
			_draw_white_flag(p, s)
		if u.hold != SimUnit.Hold.NONE:
			_draw_hold(u, p, s)
		if not u.passengers.is_empty():
			_draw_passengers(u, p, s)
		if u.work != SimUnit.Work.NONE:
			var total: int = Bridges.PLANT_TICKS if u.work == SimUnit.Work.DEMOLISH else Bridges.REPAIR_TICKS
			var done: float = 1.0 - float(u.work_ticks) / total
			draw_arc(p, 0.75 * s, -PI * 0.5, -PI * 0.5 + TAU * done, 32, WORK, 2.5, true)
		if u.aps_ticks > 0 or u.boost_ticks > 0:
			draw_arc(p, 0.85 * s, 0.0, TAU, 32, Color(BUFF, 0.7), 1.5, true)
		if selected.has(u.id):
			draw_arc(p, pick_radius(u) + 3.0, 0.0, TAU, 24, _style.selection, 1.5, true)
		if selected.has(u.id) or u.hp < u.type.max_hp or u.org < u.type.max_org:
			_draw_bars(u, p, s)
	for sp: Array in _sparks:
		if sp[1] <= SPARK_SEC:
			_draw_spark(sp)
	for e: Array in _shots:
		if e[2] > 0.0:
			var a: float = e[3] / BLAST_SEC
			var bc: Color = BLAST_COLOR
			bc.a = a * 0.5
			draw_circle(e[1], e[2], bc)
			bc.a = a
			draw_arc(e[1], e[2], 0.0, TAU, 24, bc, 1.5, true)
		else:
			# A short streak flying from the shooter to the target.
			var lc: Color = _style.unit_colors[e[4]].lightened(0.6)
			var t: float = 1.0 - e[3] / TRACER_SEC
			var from: Vector2 = e[0]
			var to: Vector2 = e[1]
			draw_line(from.lerp(to, maxf(t - 0.3, 0.0)), from.lerp(to, t), lc, 1.5)


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
	if u.shield > 0.0:
		var stop: Vector2 = top - Vector2(0.0, size.y + 1.0)
		draw_rect(Rect2(stop, Vector2(size.x * clampf(u.shield / Support.ADDON_SHIELD, 0.0, 1.0), size.y)), SHIELD)


func _draw_path(u: SimUnit, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([world_pos(u)])
	for i: int in range(u.path_index, u.path.size()):
		pts.append((Vector2(u.path[i]) + Vector2(0.5, 0.5)) * s)
	var c: Color = _style.order_marker
	c.a = 0.45
	draw_polyline(pts, c, 1.0)


## A formation drawn with its pictures. Vehicles keep the column layout of
## the dev shapes, in the driving direction; soldiers stand in rows facing
## where they walk or aim.
func _draw_pictured(u: SimUnit, art: UnitArt, p: Vector2, fill: Color, s: float) -> void:
	var moving: bool = u.pos != u.prev_pos
	var heading: float = _heading.get(u.id, 0.0)
	if moving:
		heading = Vector2(u.pos - u.prev_pos).angle()
		_heading[u.id] = heading
	var last: Vector2 = _last_pos.get(u.id, p)
	_travel[u.id] = _travel.get(u.id, 0.0) + last.distance_to(p) / s
	_last_pos[u.id] = p
	var aim: float = _turn_aim(u, p, heading)
	var n: int = u.figures()
	var xforms: Array[Transform2D] = []
	var box: Vector2
	if art.infantry:
		box = Vector2.ONE * SOLDIER_BOX * s
		var fwd: Vector2 = Vector2.from_angle(aim)
		var offs: Array[Vector2] = figure_offsets(n, 4, Vector2(SOLDIER_SPACING, SOLDIER_SPACING))
		for i: int in n:
			var bob: float = sin(_time * BOB_RATE + i * 1.7 + u.id) * BOB * s if moving else 0.0
			xforms.append(Transform2D(aim + PI * 0.5, p + offs[i] * s + fwd * bob))
	else:
		var fig: Vector2 = vehicle_figure(u.type)
		box = Vector2.ONE * fig.x * VEHICLE_BOX * s
		var i: int = 0
		for off: Vector2 in figure_offsets(n, _vehicles_per_row(u.type), _vehicle_spacing(fig)):
			var sway: float = sin(_time * SWAY_RATE + i * 2.3 + u.id) * SWAY if moving else 0.0
			var c: Vector2 = Vector2(-off.y, off.x) * s
			xforms.append(Transform2D(heading + PI * 0.5 + sway, p + c.rotated(heading)))
			i += 1
	var prev: Array = _figs.get(u.id, [])
	if not prev.is_empty() and (prev[0] as Array).size() > n:
		_leave_wrecks(prev, n)
	_figs[u.id] = [xforms, art, box]

	var k: float = box.x / UnitArt.SIZE
	var recoil_left: float = _recoil.get(u.id, 0.0)
	var kick: Vector2 = Vector2(0.0, RECOIL_PX * k * ease(recoil_left / RECOIL_SEC, 2.0))
	var rel: float = aim - heading
	var piv: Vector2 = (art.pivot - Vector2(32, 32)) * k
	var muzzles: PackedVector2Array = PackedVector2Array()
	var tint: Color = Color(fill.lerp(Color.WHITE, PICTURE_TINT_LIGHTEN), fill.a)
	for xf: Transform2D in xforms:
		draw_set_transform_matrix(xf)
		draw_texture_rect(art.body, Rect2(-box * 0.5, box), false, tint)
		if not art.tracks.is_empty():
			_draw_tracks(art, k, fill, _travel[u.id] * UnitArt.SIZE / (box.x / s))
		var m: Vector2 = (art.muzzle - Vector2(32, 32)) * k
		if art.turret != null:
			draw_set_transform_matrix(xf * Transform2D(rel, piv) * Transform2D(0.0, -piv + kick))
			draw_texture_rect(art.turret, Rect2(-box * 0.5, box), false, tint)
			muzzles.append(xf * (piv + (m - piv + kick).rotated(rel)))
		else:
			muzzles.append(xf * (m + kick))
	draw_set_transform(Vector2.ZERO)
	if recoil_left > RECOIL_SEC - FLASH_SEC:
		var dir: Vector2 = Vector2.from_angle(aim if art.turret != null or art.infantry else heading)
		var r: float = (0.05 if art.infantry else 0.12) * s
		for q: Vector2 in muzzles:
			draw_colored_polygon(PackedVector2Array([q + dir.orthogonal() * r * 0.6, q + dir * r * 2.4, q - dir.orthogonal() * r * 0.6]), Color(FLASH, 0.9))
			draw_circle(q, r, FLASH)


## Turns the turret (or the soldiers) towards the current target, or back to
## the driving direction, at TURRET_TURN; returns the angle to draw.
func _turn_aim(u: SimUnit, p: Vector2, heading: float) -> float:
	var want: float = heading
	var t: SimUnit = sim.unit(u.target_id) if u.target_id != 0 else null
	if t != null and t.on_map() and t.side != u.side:
		want = (world_pos(t) - p).angle()
	var cur: float = _aim.get(u.id, want)
	var step: float = TURRET_TURN * _delta
	var diff: float = wrapf(want - cur, -PI, PI)
	cur += clampf(diff, -step, step)
	_aim[u.id] = cur
	return cur


## Track runs redrawn with links that move as the vehicle drives (`travel`
## in picture pixels), in the figure's picture frame scaled by `k`.
func _draw_tracks(art: UnitArt, k: float, fill: Color, travel: float) -> void:
	var dark: Color = Color(fill.r * 0.42, fill.g * 0.42, fill.b * 0.42, fill.a)
	var link: Color = Color(fill.r * 0.2, fill.g * 0.2, fill.b * 0.2, fill.a)
	var pitch: float = TRACK_PITCH * k
	for t: Rect2 in art.tracks:
		var r: Rect2 = Rect2((t.position - Vector2(32, 32)) * k, t.size * k)
		draw_rect(r, dark)
		var y: float = r.position.y + fposmod(travel * k, pitch)
		while y < r.end.y:
			draw_line(Vector2(r.position.x + k, y), Vector2(r.end.x - k, y), link, maxf(0.8 * k, 1.0))
			y += pitch
		draw_rect(r, Color(_style.unit_outline, fill.a), false, maxf(k, 1.0))


## A wreck: a short explosion, then the burnt picture fading out at the end.
func _draw_hulk(h: Array) -> void:
	var art: UnitArt = h[1]
	var box: Vector2 = h[2]
	var age: float = h[3]
	var life: float = BODY_SEC if art.infantry else HULK_SEC
	var a: float = clampf((life - age) / HULK_FADE_SEC, 0.0, 1.0)
	var xf: Transform2D = h[0]
	draw_set_transform_matrix(xf)
	draw_texture_rect(art.wreck, Rect2(-box * 0.5, box), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
	if age < BOOM_SEC and not art.infantry:
		var f: float = age / BOOM_SEC
		var r: float = box.x * lerpf(0.2, 0.7, sqrt(f))
		draw_circle(xf.origin, r, Color(SMOKE, 0.6 * (1.0 - f)))
		draw_circle(xf.origin, r * 0.7, Color(BLAST_COLOR, 1.0 - f))
		draw_circle(xf.origin, r * 0.35, Color(FLASH, maxf(1.0 - f * 2.0, 0.0)))


## Bullet strike: a few short sparks flying out.
func _draw_spark(sp: Array) -> void:
	var f: float = 1.0 - sp[1] / SPARK_SEC
	var c: Color = Color(SPARK, 1.0 - f)
	var len: float = float(_style.cell_px) * 0.35
	for i: int in 4:
		var d: Vector2 = Vector2.from_angle(sp[2] + i * TAU / 4.0 + i * 0.4)
		draw_line(sp[0] + d * len * f * 0.5, sp[0] + d * len * (0.2 + f), c, 1.2)


## White flag over a routing formation, waving.
func _draw_white_flag(p: Vector2, s: float) -> void:
	var foot: Vector2 = p + Vector2(0.55, -0.1) * s
	var top: Vector2 = foot - Vector2(0.0, 0.75 * s)
	draw_line(foot, top, _style.unit_outline, 2.0)
	var wave: float = sin(_time * 6.0) * 0.05 * s
	var w: float = 0.42 * s
	var h: float = 0.26 * s
	var flag: PackedVector2Array = PackedVector2Array([top, top + Vector2(w, wave), top + Vector2(w, h + wave), top + Vector2(0.0, h)])
	draw_colored_polygon(flag, FLAG)
	flag.append(top)
	draw_polyline(flag, _style.unit_outline, 1.0)
