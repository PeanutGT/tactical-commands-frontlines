class_name AiPlayer
extends RefCounted
## Rule-based opponent (section 12). Once a second it looks at what its side
## may know (its own units and cards, enemies its side sees now, who holds
## each point) and sends commands, nothing else, so it plays under the same
## fog and rules as the player. Difficulty sets how late its orders arrive and
## how often it plays a random card instead of the best one; that randomness
## comes from its own seeded PRNG, so a match still replays.

enum Difficulty { EASY, NORMAL, HARD }

const NAMES: Array[String] = ["簡單", "普通", "困難"]
const THINK_TICKS: int = Simulation.TICK_RATE
## Orders reach the field this many ticks after the AI decides them.
const REACTION_TICKS: Array[int] = [2 * Simulation.TICK_RATE, Simulation.TICK_RATE / 2, 0]
## Chance of playing a random affordable card instead of the best one.
const RANDOM_PICK: Array[float] = [0.5, 0.2, 0.0]
## Section 12: push for the enemy HQ once field weight reaches this share of the cap.
const ATTACK_AT: float = 0.7
## A point or the HQ counts as attacked with a seen enemy this close (cells).
const THREAT_CELLS: float = 8.0
## Units this close to an attacked place are pulled back to it (cells).
const DEFEND_REACH_CELLS: float = 25.0
## When sharing out points, each unit already sent there counts as this many
## cells further away, so groups spread over several points.
const CROWD_CELLS: float = 15.0
## Infantry on a held point digs in when no other point needs it.
const GARRISON_CELLS: float = 3.0

var sim: Simulation
var side: int = GameMap.Side.ENEMY
var difficulty: Difficulty = Difficulty.NORMAL

var _rng: SimRng
## Orders decided but not yet sent: [tick due, SimCommand].
var _queue: Array = []
## Last cell each unit was sent to, so idle orders are not repeated.
var _sent: Dictionary[int, Vector2i] = {}


func _init(p_sim: Simulation, p_side: int, p_difficulty: Difficulty, seed_value: int) -> void:
	sim = p_sim
	side = p_side
	difficulty = p_difficulty
	_rng = SimRng.new(seed_value * 7919 + 17)


## Call once after every simulation tick.
func update() -> void:
	var later: Array = []
	for q: Array in _queue:
		if q[0] <= sim.tick:
			sim.issue(q[1])
		else:
			later.append(q)
	_queue = later
	if sim.winner != Simulation.NO_WINNER or sim.tick % THINK_TICKS != 0:
		return
	_play_card()
	var busy: Dictionary[int, bool] = _defend()
	_advance(busy)


func _send(cmd: SimCommand) -> void:
	var delay: int = REACTION_TICKS[difficulty]
	if delay <= 0:
		sim.issue(cmd)
	else:
		_queue.append([sim.tick + delay, cmd])


# --- What the AI may look at ------------------------------------------------

## Own units that take orders.
func _army() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in sim.units:
		if u.side == side and u.on_map() and not u.type.structure and not u.is_convoy() and not u.retreating:
			out.append(u)
	return out


## Enemy units its side sees now, buildings left out.
func _seen_enemies() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in sim.units:
		if u.side != side and u.on_map() and not u.type.structure and sim.vision.sees(side, u):
			out.append(u)
	return out


static func _cells(u: SimUnit) -> Vector2:
	return Vector2(u.pos) / Simulation.SUBCELL


func _enemy_hq_cell() -> Vector2i:
	var h: SimUnit = sim.hq[1 - side]
	if h != null:
		return h.cell()
	return Vector2i(sim.home_centre(1 - side).floor())


# --- Cards --------------------------------------------------------------------

## Section 12 rule 1: play a card whenever one is affordable.
func _play_card() -> void:
	var s: SideState = sim.sides[side]
	var enemies: Array[SimUnit] = _seen_enemies()
	var options: Array[Array] = []  # [slot, card, cell, cell2, score]
	for slot: int in s.hand.size():
		var card: StringName = s.hand[slot]
		if card == SideState.EMPTY or s.supply < Card.cost(card):
			continue
		var plan: Array = _plan_unit(card, enemies) if Card.is_unit(card) else _plan_support(card, enemies)
		if plan.is_empty():
			continue
		if sim.can_deploy(side, slot, card, plan[0], plan[1]) != Simulation.Deploy.OK:
			continue
		options.append([slot, card, plan[0], plan[1], plan[2]])
	if options.is_empty():
		return
	var pick: Array = options[0]
	if _rng.next_float() < RANDOM_PICK[difficulty]:
		pick = options[_rng.next_int(options.size())]
	else:
		for o: Array in options:
			if o[4] > pick[4]:
				pick = o
	_send(SimCommand.deploy(side, pick[0], pick[1], pick[2], pick[3]))


## [cell, cell2, score] for a unit card, or [] when it does not fit now. Seen
## armour calls for anti-tank weapons, a lot of seen infantry for armoured
## personnel carriers, otherwise the dearest unit goes first.
func _plan_unit(card: StringName, enemies: Array[SimUnit]) -> Array:
	var t: UnitType = UnitType.of(card)
	if sim.field_weight(side) + t.weight > sim.map.config.weight_cap:
		return []
	var armor: int = 0
	var infantry: int = 0
	for e: SimUnit in enemies:
		if e.type.kind == UnitType.Kind.ARMOR:
			armor += 1
		elif e.type.kind == UnitType.Kind.INFANTRY:
			infantry += 1
	var score: float = float(t.cost)
	if armor > 0 and t.weapon != null and t.weapon.penetration >= 12:
		score += 10.0
	elif infantry >= 3 and t.transport_capacity > 0:
		score += 10.0
	var cell: Vector2i = _deploy_cell(t.vehicle)
	if cell == Vector2i(-1, -1):
		return []
	return [cell, Vector2i(-1, -1), score]


## Where new units go: the spawn cell or held-point cell nearest the next
## point to take (or the enemy HQ).
func _deploy_cell(vehicle: bool) -> Vector2i:
	var goal: Vector2 = Vector2(_targets_or_hq()[0]) + Vector2(0.5, 0.5)
	var anchors: Array[Vector2] = [sim.home_centre(side)]
	for i: int in sim.map.pois.size():
		if sim.poi_owner[i] == side:
			anchors.append(sim.map.pois[i].center)
	anchors.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(goal) < b.distance_squared_to(goal))
	for a: Vector2 in anchors:
		for off: Vector2i in Simulation.slot_offsets(40):
			var c: Vector2i = Vector2i(a.floor()) + off
			if sim.map.in_bounds(c) and sim.deploy_cell_ok(side, c, vehicle):
				return c
	return Vector2i(-1, -1)


## [cell, cell2, score] for a support card, or [] when it is not worth it now.
func _plan_support(card: StringName, enemies: Array[SimUnit]) -> Array:
	var none: Vector2i = Vector2i(-1, -1)
	match card:
		&"supply_convoy":
			return _plan_convoy()
		&"artillery", &"barrage":
			var c: SimUnit = _densest(enemies, false)
			return [] if c == null else [c.cell(), none, 20.0]
		&"precision_missile":
			var best: SimUnit = null
			for e: SimUnit in enemies:
				if e.type.kind == UnitType.Kind.ARMOR and (best == null or e.type.cost > best.type.cost):
					best = e
			return [] if best == null else [best.cell(), none, 15.0]
		&"field_repair", &"addon_armor":
			for u: SimUnit in _army():
				if u.type.kind == UnitType.Kind.ARMOR and u.hp < u.type.max_hp * 0.5:
					return [u.cell(), none, 12.0]
			return []
		&"call_reserves":
			return [] if sim.sides[side].cooldowns.size() < 2 else [Vector2i(sim.home_centre(side).floor()), none, 8.0]
		&"drone_recon":
			return [] if not enemies.is_empty() else [_targets_or_hq()[0], none, 3.0]
		&"aps", &"armored_assault":
			var a: SimUnit = _densest(_army().filter(func(u: SimUnit) -> bool: return u.type.kind == UnitType.Kind.ARMOR), true)
			return [] if a == null or enemies.is_empty() else [a.cell(), none, 6.0]
	return []


## Truck from the held point furthest from home back to the HQ: the longer
## the drive, the bigger the pay-out.
func _plan_convoy() -> Array:
	if sim.hq[side] == null:
		return []
	var home: Vector2 = Vector2(sim.hq[side].pos) / Simulation.SUBCELL
	var best: int = -1
	for i: int in sim.map.pois.size():
		if sim.poi_owner[i] == side and (best < 0 or sim.map.pois[i].center.distance_squared_to(home)
				> sim.map.pois[best].center.distance_squared_to(home)):
			best = i
	if best < 0:
		return []
	var start: Vector2i = Vector2i(-1, -1)
	for off: Vector2i in Simulation.slot_offsets(40):
		var c: Vector2i = Vector2i(sim.map.pois[best].center.floor()) + off
		if Support.can_aim(sim, side, &"supply_convoy", c):
			start = c
			break
	if start == Vector2i(-1, -1):
		return []
	return [start, Vector2i(home.floor()), 5.0]


## The unit with the most others of `units` within 3 cells; null for none.
## With `allow_alone` false a lone unit does not count.
func _densest(units: Array, allow_alone: bool) -> SimUnit:
	var best: SimUnit = null
	var best_n: int = 0 if allow_alone else 1
	for u: SimUnit in units:
		var n: int = 0
		for v: SimUnit in units:
			if v != u and _cells(u).distance_to(_cells(v)) <= 3.0:
				n += 1
		if (allow_alone and best == null) or n > best_n:
			best = u
			best_n = n
	return best


# --- Orders -----------------------------------------------------------------

## Section 12 rule 3: an attacked point or HQ pulls nearby units back to it.
## Returns the units given a defending order.
func _defend() -> Dictionary[int, bool]:
	var busy: Dictionary[int, bool] = {}
	var enemies: Array[SimUnit] = _seen_enemies()
	var places: Array[Vector2] = []
	if sim.hq[side] != null:
		places.append(_cells(sim.hq[side]))
	for i: int in sim.map.pois.size():
		if sim.poi_owner[i] == side:
			places.append(sim.map.pois[i].center)
	for p: Vector2 in places:
		var threat: SimUnit = null
		for e: SimUnit in enemies:
			if _cells(e).distance_to(p) <= THREAT_CELLS:
				threat = e
				break
		if threat == null:
			continue
		for u: SimUnit in _army():
			if busy.has(u.id) or u.target_id != 0 or _cells(u).distance_to(p) > DEFEND_REACH_CELLS:
				continue
			busy[u.id] = true
			if _cells(u).distance_to(_cells(threat)) > 4.0:
				_order_move(u, threat.cell())
	return busy


## Section 12 rules 2 and 4: idle units take the nearest point the side does
## not hold, spread out; once the field is 70% full, everyone goes for the
## enemy HQ.
func _advance(busy: Dictionary[int, bool]) -> void:
	var army: Array[SimUnit] = _army()
	var attack: bool = sim.field_weight(side) >= sim.map.config.weight_cap * ATTACK_AT
	var targets: Array[Vector2i] = _targets_or_hq()
	if attack:
		targets = [_enemy_hq_cell()]
	var assigned: Dictionary[Vector2i, int] = {}
	for u: SimUnit in army:
		if busy.has(u.id) or u.forced_target or u.target_id != 0 or u.board_id != 0 or u.routing:
			continue
		if not attack and _garrisons(u):
			continue
		var best: Vector2i = targets[0]
		var best_d: float = INF
		for t: Vector2i in targets:
			var d: float = _cells(u).distance_to(Vector2(t)) + CROWD_CELLS * assigned.get(t, 0)
			if d < best_d:
				best_d = d
				best = t
		assigned[best] = assigned.get(best, 0) + 1
		if _sent.get(u.id, Vector2i(-1, -1)) != best or not u.is_moving():
			if _cells(u).distance_to(Vector2(best)) > CapturePoints.RADIUS_CELLS - 1.0 or u.is_moving():
				_order_move(u, best)


## Infantry standing on a held point with no other infantry dug in there
## stays and holds it.
func _garrisons(u: SimUnit) -> bool:
	if u.type.kind != UnitType.Kind.INFANTRY:
		return false
	for i: int in sim.map.pois.size():
		var p: CellGroup = sim.map.pois[i]
		if sim.poi_owner[i] != side or _cells(u).distance_to(p.center) > GARRISON_CELLS:
			continue
		for v: SimUnit in _army():
			if v != u and v.hold != SimUnit.Hold.NONE and _cells(v).distance_to(p.center) <= GARRISON_CELLS:
				return false
		if u.hold == SimUnit.Hold.NONE and not u.is_moving():
			_send(SimCommand.hold(side, PackedInt32Array([u.id])))
		return u.hold != SimUnit.Hold.NONE or not u.is_moving()
	return false


## Points the side does not hold, as cells; the enemy HQ when it holds all.
func _targets_or_hq() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in sim.map.pois.size():
		if sim.poi_owner[i] != side:
			out.append(Vector2i(sim.map.pois[i].center.floor()))
	if out.is_empty():
		out.append(_enemy_hq_cell())
	return out


func _order_move(u: SimUnit, cell: Vector2i) -> void:
	if _sent.get(u.id, Vector2i(-1, -1)) == cell and u.is_moving():
		return
	_sent[u.id] = cell
	_send(SimCommand.move(side, PackedInt32Array([u.id]), cell))
