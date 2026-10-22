class_name Support
extends RefCounted
## What each support card does (section 8 支援卡效果). Distances are standard
## cells (20 m) and scale with the map; damage takes the pacing ×0.7 in
## Simulation.support_strike. Durations, delays and penetration/suppression
## are the doc's starting values; LINE_HALF_WIDTH and the pick distances are
## invented starting values.

const SMOKE_RADIUS: float = 4.0
const SMOKE_SEC: float = 12.0
const ARTILLERY_DELAY_SEC: float = 3.0
const ARTILLERY_RADIUS: float = 3.0
const ARTILLERY_DAMAGE: float = 120.0
const ARTILLERY_PEN: int = 8
const ARTILLERY_SUP: float = 60.0
const DRONE_RADIUS: float = 10.0
const DRONE_SEC: float = 15.0
const MISSILE_DAMAGE: float = 250.0
const MISSILE_PEN: int = 24
const MISSILE_SUP: float = 40.0
const APS_RADIUS: float = 6.0
const APS_SEC: float = 10.0
## Anti-armour hits on a protected vehicle do this share of their damage.
const APS_TAKEN: float = 0.5
const BARRAGE_DELAY_SEC: float = 4.0
const BARRAGE_LENGTH: float = 12.0
## Units this far either side of the barrage line are hit.
const LINE_HALF_WIDTH: float = 1.0
const BARRAGE_DAMAGE: float = 90.0
const BARRAGE_PEN: int = 6
const BARRAGE_SUP: float = 60.0
const ASSAULT_RADIUS: float = 10.0
const ASSAULT_SEC: float = 10.0
const ASSAULT_SPEED: float = 1.4
const REPAIR_HP: float = 300.0
const ADDON_SHIELD: float = 200.0
const ADDON_SEC: float = 30.0
## A unit-targeted card picks the unit nearest the drop within this many cells.
const PICK_CELLS: float = 2.0


## Whether `card` may be dropped on `cell` by `side` right now.
static func can_aim(sim: Simulation, side: int, card: StringName, cell: Vector2i) -> bool:
	if not sim.map.in_bounds(cell):
		return false
	match Card.aim(card):
		Card.Aim.SEEN:
			return sim.vision.cell_visible(side, cell)
		Card.Aim.OWN_POINT:
			var p: int = sim.near_own_point(side, cell)
			return p >= 0 and not sim.points.under_attack(p, side) and Movement.passable(sim.map, cell, true)
		Card.Aim.ENEMY:
			return missile_target(sim, side, cell) != null or _standing_bridge(sim, cell) >= 0
		Card.Aim.OWN_ARMOR:
			return own_armor_near(sim, side, cell) != null
	return true


## Starts `card`; returns its running effect, or null when it is over at once.
static func play(sim: Simulation, side: int, card: StringName, cell: Vector2i) -> SupportEffect:
	var e: SupportEffect = SupportEffect.new()
	e.card = card
	e.side = side
	e.cell = cell
	match card:
		&"smoke":
			e.ticks_left = _ticks(SMOKE_SEC)
			sim.vision.add_smoke(_centre(cell), sim.std_cells(SMOKE_RADIUS))
		&"artillery":
			e.delay = _ticks(ARTILLERY_DELAY_SEC)
		&"barrage":
			e.delay = _ticks(BARRAGE_DELAY_SEC)
			e.dir = barrage_dir(sim, side, cell)
		&"drone_recon":
			e.ticks_left = _ticks(DRONE_SEC)
			sim.vision.add_drone(side, _centre(cell), sim.std_cells(DRONE_RADIUS))
		&"precision_missile":
			var t: SimUnit = missile_target(sim, side, cell)
			if t != null:
				sim.support_strike(side, t, MISSILE_DAMAGE, MISSILE_PEN, MISSILE_SUP, true, Simulation.cell_center(cell))
				sim.add_blast(side, t.pos, 0.5)
			else:
				var b: int = _standing_bridge(sim, cell)
				if b >= 0:
					sim.damage_bridge(b, MISSILE_DAMAGE * Simulation.DAMAGE_SCALE)
					sim.add_blast(side, Simulation.cell_center(cell), 0.5)
			return null
		&"aps":
			e.ticks_left = _ticks(APS_SEC)
			for u: SimUnit in _own_armor_within(sim, side, cell, APS_RADIUS):
				u.aps_ticks = e.ticks_left
		&"armored_assault":
			e.ticks_left = _ticks(ASSAULT_SEC)
			for u: SimUnit in _own_armor_within(sim, side, cell, ASSAULT_RADIUS):
				u.boost_ticks = e.ticks_left
		&"call_reserves":
			for c: Array in sim.sides[side].cooldowns:
				c[1] = ceili(c[1] * 0.5)
			return null
		&"field_repair":
			var r: SimUnit = own_armor_near(sim, side, cell)
			if r != null:
				r.hp = minf(r.type.max_hp, r.hp + REPAIR_HP)
			return null
		&"addon_armor":
			var a: SimUnit = own_armor_near(sim, side, cell)
			if a == null:
				return null
			a.shield = ADDON_SHIELD
			e.target_id = a.id
			e.ticks_left = _ticks(ADDON_SEC)
		_:
			return null
	return e


## One tick of a running effect; true once it is over.
static func update(sim: Simulation, e: SupportEffect) -> bool:
	if e.delay > 0:
		e.delay -= 1
		if e.delay > 0:
			return false
		_land(sim, e)
		return true
	if e.card == &"addon_armor":
		var a: SimUnit = sim.unit(e.target_id)
		if a == null or a.shield <= 0.0:
			return true
	e.ticks_left -= 1
	if e.ticks_left > 0:
		return false
	_finish(sim, e)
	return true


## Shells arriving: 砲擊 a circle, 彈幕射擊 a line. Both hit friend and foe
## and wear down bridges.
static func _land(sim: Simulation, e: SupportEffect) -> void:
	var at: Vector2 = _centre(e.cell)
	if e.card == &"artillery":
		var r: float = sim.std_cells(ARTILLERY_RADIUS)
		for u: SimUnit in sim.ground_units():
			if (Vector2(u.pos) / Simulation.SUBCELL).distance_to(at) <= r:
				sim.support_strike(e.side, u, ARTILLERY_DAMAGE, ARTILLERY_PEN, ARTILLERY_SUP, false, Simulation.cell_center(e.cell))
		sim.damage_bridges_near(at, r, ARTILLERY_DAMAGE * Simulation.DAMAGE_SCALE)
		sim.add_blast(e.side, Simulation.cell_center(e.cell), r)
		return
	var half: float = sim.std_cells(BARRAGE_LENGTH) * 0.5
	var w: float = sim.std_cells(LINE_HALF_WIDTH)
	for u: SimUnit in sim.ground_units():
		if _line_distance(Vector2(u.pos) / Simulation.SUBCELL, at, e.dir, half) <= w:
			sim.support_strike(e.side, u, BARRAGE_DAMAGE, BARRAGE_PEN, BARRAGE_SUP, false, Simulation.cell_center(e.cell))
	var hit: Dictionary[int, bool] = {}
	for k: int in range(-ceili(half), ceili(half) + 1):
		var p: Vector2 = at + e.dir * clampf(k, -half, half)
		for b: int in sim.bridges_near(p, w):
			hit[b] = true
		if k % 2 == 0:
			sim.add_blast(e.side, Vector2i((p * Simulation.SUBCELL).round()), w)
	for b: int in hit:
		sim.damage_bridge(b, BARRAGE_DAMAGE * Simulation.DAMAGE_SCALE)


static func _finish(sim: Simulation, e: SupportEffect) -> void:
	match e.card:
		&"smoke":
			sim.vision.remove_smoke(_centre(e.cell), sim.std_cells(SMOKE_RADIUS))
		&"drone_recon":
			sim.vision.remove_drone(e.side, _centre(e.cell))
		&"addon_armor":
			var a: SimUnit = sim.unit(e.target_id)
			if a != null:
				a.shield = 0.0


## Distance from `p` to the segment of half-length `half` through `at` along `dir`.
static func _line_distance(p: Vector2, at: Vector2, dir: Vector2, half: float) -> float:
	var along: float = clampf((p - at).dot(dir), -half, half)
	return p.distance_to(at + dir * along)


## The barrage runs across the line from the side's own spawn (or HQ) to the
## target, like a front.
static func barrage_dir(sim: Simulation, side: int, cell: Vector2i) -> Vector2:
	var home: Vector2 = sim.home_centre(side)
	var d: Vector2 = _centre(cell) - home
	if d == Vector2.ZERO:
		return Vector2.RIGHT
	return Vector2(-d.y, d.x).normalized()


## The seen enemy nearest `cell` within PICK_CELLS, buildings included.
static func missile_target(sim: Simulation, side: int, cell: Vector2i) -> SimUnit:
	return _nearest(sim, cell, func(u: SimUnit) -> bool:
		return u.side != side and sim.vision.sees(side, u))


## The side's own armoured unit nearest `cell` within PICK_CELLS.
static func own_armor_near(sim: Simulation, side: int, cell: Vector2i) -> SimUnit:
	return _nearest(sim, cell, func(u: SimUnit) -> bool:
		return u.side == side and u.type.kind == UnitType.Kind.ARMOR and not u.type.structure)


static func _nearest(sim: Simulation, cell: Vector2i, ok: Callable) -> SimUnit:
	var at: Vector2 = _centre(cell)
	var best: SimUnit = null
	var best_d: float = sim.std_cells(PICK_CELLS)
	for u: SimUnit in sim.ground_units():
		if not ok.call(u):
			continue
		var reach: float = 1.5 if u.type.structure else 0.0
		var d: float = (Vector2(u.pos) / Simulation.SUBCELL).distance_to(at) - reach
		if d <= best_d:
			best_d = d
			best = u
	return best


static func _own_armor_within(sim: Simulation, side: int, cell: Vector2i, radius: float) -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	var r: float = sim.std_cells(radius)
	for u: SimUnit in sim.ground_units():
		if u.side == side and u.type.kind == UnitType.Kind.ARMOR and not u.type.structure \
				and (Vector2(u.pos) / Simulation.SUBCELL).distance_to(_centre(cell)) <= r:
			out.append(u)
	return out


static func _standing_bridge(sim: Simulation, cell: Vector2i) -> int:
	var b: int = sim.bridges.at(cell)
	return b if b >= 0 and not sim.bridges.broken[b] else -1


static func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


static func _ticks(sec: float) -> int:
	return roundi(sec * Simulation.TICK_RATE)
