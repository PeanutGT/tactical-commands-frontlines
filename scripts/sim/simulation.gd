class_name Simulation
extends RefCounted
## Fixed-rate simulation (section 3): 20 ticks per second, driven only by
## commands, all randomness from a seeded PRNG. No nodes, no engine physics.
## A command issued now runs at the start of the next tick.

const TICK_RATE: int = 20
const TICK_SEC: float = 1.0 / TICK_RATE
## Sub-cell steps per cell for unit positions.
const SUBCELL: int = 1024

## Section 9 combat numbers.
const HOLD_ENTER_TICKS: int = 4 * TICK_RATE
const HOLD_LEAVE_TICKS: int = 2 * TICK_RATE
const HOLD_DAMAGE_TAKEN: float = 0.6
const HOLD_RANGE: float = 1.1
## Held in forest or next to a building: a further −20% damage taken.
const COVER_DAMAGE_TAKEN: float = 0.8
const HIGH_GROUND_DAMAGE: float = 1.15
const LOW_GROUND_DAMAGE: float = 0.85
## Shooting downhill adds one standard cell (20 m) of range.
const HIGH_GROUND_RANGE_M: float = MapScale.STANDARD_METERS_PER_CELL
## Section 11: −5 score per 100 friendly damage, −weight × 5 per friendly kill.
const FF_SCORE_PER_100: int = 5
const FF_KILL_SCORE_PER_WEIGHT: int = 5
## A chasing unit re-plans its path at most this often when the target moves.
const CHASE_REPATH_TICKS: int = 10
## Body radii (cells) for unit separation.
const INFANTRY_RADIUS: float = 0.5
const VEHICLE_RADIUS: float = 0.75
## Organization (starting values, see progress.md). Suppressed below this
## share of max: weapons reload 50% slower and the unit moves 25% slower.
const SUPPRESSED_BELOW: float = 0.5
const SUPPRESSED_COOLDOWN: float = 1.5
const SUPPRESSED_SPEED: float = 0.75
## A routing unit moves at this share of its speed and acts again once
## back to RALLY_AT of max. Without a spawn zone it flees this far from
## whoever broke it.
const ROUT_SPEED: float = 0.5
const RALLY_AT: float = 0.3
const ROUT_FALLBACK_CELLS: int = 10
## Recovery starts this long after the last hit.
const ORG_RECOVER_DELAY_TICKS: int = 4 * TICK_RATE
const ORG_RECOVER_PER_SEC: float = 3.0
const ORG_RECOVER_HELD: float = 1.5
const ORG_RECOVER_FOREST: float = 1.5
const ORG_RECOVER_MOVING: float = 0.5
## Section 6 supply per second: BASE × (1 − WEIGHT_SLOWDOWN × weight / cap)
## + PER_POINT × points held (pacing decisions in progress.md; slowed again
## by Peanut on 2026-10-23).
const SUPPLY_BASE: float = 0.15
const SUPPLY_WEIGHT_SLOWDOWN: float = 0.5
const SUPPLY_PER_POINT: float = 0.03
## Pacing (progress.md): every unit moves at 60% of its card speed, and unit
## weapons, support cards and the HQ gun do 70% of their listed damage.
const SPEED_SCALE: float = 0.6
const DAMAGE_SCALE: float = 0.7
## winner while the match runs, and when both sides end level.
const NO_WINNER: int = -1
const DRAW: int = 2
## A 運補車隊 truck pays out one supply per this many cells driven, within
## CONVOY_MIN..CONVOY_MAX.
const CONVOY_CELLS_PER_SUPPLY: float = 10.0
const CONVOY_MIN: int = 1
const CONVOY_MAX: int = 6
## A truck has arrived this close to its HQ's centre (starting value).
const CONVOY_HQ_REACH_CELLS: float = 3.0
## Self-propelled guns and rocket launchers wear down bridges (section 4.4).
const BRIDGE_BREAKERS: Array[StringName] = [&"spg", &"mrl"]
## Cards may also be played this close to the centre of a point the side holds
## (starting value).
const DEPLOY_NEAR_POINT_CELLS: float = 4.0
## Section 7: a retreat gives back half the card's cost.
const RETREAT_REFUND: float = 0.5
## Section 9 搭載: infantry boards once this close to its transport (starting
## value), getting everyone out takes 2 s, and a destroyed transport's
## passengers lose half their health.
const BOARD_RANGE_CELLS: float = 1.5
const UNLOAD_TICKS: int = 2 * TICK_RATE
const WRECKED_CARRIER_LOSS: float = 0.5

## Line-of-fire samples per cell of distance.
const LOS_SAMPLES: int = 4
## Section 10: sight is recomputed every 4 ticks (0.2 s), and at once after a
## unit arrives.
const VISION_TICKS: int = 4
## Section 11: each point held scores this much per second.
const SCORE_PER_POINT: int = 1

## Why a DEPLOY was refused.
enum Deploy { OK, NOT_IN_HAND, NO_SUPPLY, OVER_WEIGHT, BAD_PLACE }
## How the match was decided (section 11).
enum End { NONE, HQ_DESTROYED, SCORE, TIME }


## One shot fired this tick, for drawing tracers and blasts.
class Shot:
	var side: int
	var from: Vector2i
	var to: Vector2i
	## Blast radius in sub-cells, 0 for a direct hit.
	var splash: int


var map: GameMap
var rng: SimRng
var tick: int = 0
var units: Array[SimUnit] = []
## Every command in the order it ran; with the seed this replays the match.
var command_log: Array[SimCommand] = []
## Per side (GameMap.Side). Never below 0.
var score: Array[int] = [0, 0]
## Total damage each side has dealt to its own units.
var friendly_damage: Array[float] = [0.0, 0.0]
## Score each side has lost to friendly fire.
var ff_penalty: Array[int] = [0, 0]
## Shots fired and units killed in the last tick.
var shots: Array[Shot] = []
var deaths: Array[SimUnit] = []
## Units that drove off the field (retreated) in the last tick.
var retreated: Array[SimUnit] = []
## Supply and card cycle per side; deal decks with setup_side.
var sides: Array[SideState] = [SideState.new(), SideState.new()]
## Fog of war and who sees whom, per side.
var vision: Vision
## Who holds each point of interest and who is taking it.
var points: CapturePoints
## GameMap.Side holding each point of interest (map.pois order), or
## CellGroup.NO_OWNER; the same array as points.owner.
var poi_owner: Array[int] = []
## Result of each side's last DEPLOY command.
var last_deploy: Array[Deploy] = [Deploy.OK, Deploy.OK]
## GameMap.Side that won, DRAW, or NO_WINNER while the match runs. Once set,
## step() does nothing more.
var winner: int = NO_WINNER
var end_reason: End = End.NONE
## Each side's HQ (a building unit), null when the map has none. Kept after
## it falls, at 0 health.
var hq: Array[SimUnit] = [null, null]
var bridges: Bridges
## Support cards in play, both sides.
var effects: Array[SupportEffect] = []

var _by_id: Dictionary[int, SimUnit] = {}
var _next_id: int = 1
var _pending: Array[SimCommand] = []
var _pathfinder: Pathfinder
## Sub-cells per tick for 1 m/s on this map.
var _subcells_per_tick_per_mps: float = 0.0
## Score already taken off for friendly damage (whole 100s only).
var _ff_damage_penalised: Array[int] = [0, 0]
## A unit arrived since the last sight pass.
var _vision_dirty: bool = true


func _init(p_map: GameMap, seed_value: int = 1) -> void:
	map = p_map
	rng = SimRng.new(seed_value)
	_pathfinder = Pathfinder.new(map)
	_pathfinder.prepare()
	_subcells_per_tick_per_mps = MapScale.meters_to_cells(1.0, map.config.meters_per_cell) * SUBCELL / TICK_RATE * SPEED_SCALE
	vision = Vision.new(map)
	points = CapturePoints.new(map)
	poi_owner = points.owner
	bridges = Bridges.new(map)
	for g: CellGroup in map.hqs:
		if hq[g.owner] == null:
			var h: SimUnit = spawn(UnitType.hq(), g.owner, Vector2i(g.center.floor()))
			h.pos = Vector2i((g.center * SUBCELL).round())
			h.prev_pos = h.pos
			hq[g.owner] = h
	_claim_start_points()


## Each side starts holding the map's start_points points nearest its spawn
## zone (河城: its rear high ground and its bridgehead square), each with an
## infantry squad on it.
func _claim_start_points() -> void:
	for side: int in 2:
		var home: CellGroup = _spawn_zone(side)
		if home == null:
			continue
		var order: Array[int] = []
		for i: int in map.pois.size():
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool:
			var da: float = map.pois[a].center.distance_squared_to(home.center)
			var db: float = map.pois[b].center.distance_squared_to(home.center)
			return da < db or (da == db and a < b))
		var claimed: int = 0
		for i: int in order:
			if claimed >= map.config.start_points:
				break
			if poi_owner[i] == CellGroup.NO_OWNER:
				poi_owner[i] = side
				claimed += 1
				# Each starting point comes with an infantry squad on it (Peanut,
				# 2026-10-23). It has no card, so it never cools down or refunds.
				var c: Vector2i = Vector2i(map.pois[i].center.floor())
				if Movement.passable(map, c, false):
					spawn(UnitType.infantry(), side, c)


## Shuffles `deck` (from the seeded PRNG) and deals `side` its opening hand
## and supply. Call before the first tick.
func setup_side(side: int, deck: Array[StringName]) -> void:
	sides[side].setup(deck, map.config.hand_size, map.config.start_supply, rng)


func spawn(type: UnitType, side: int, cell: Vector2i) -> SimUnit:
	var u: SimUnit = SimUnit.new()
	u.id = _next_id
	_next_id += 1
	u.type = type
	u.side = side
	u.hp = type.max_hp
	u.org = type.max_org
	u.pos = cell_center(cell)
	u.prev_pos = u.pos
	units.append(u)
	_by_id[u.id] = u
	_vision_dirty = true
	return u


## Null once the unit has died.
func unit(id: int) -> SimUnit:
	return _by_id.get(id)


func issue(cmd: SimCommand) -> void:
	cmd.tick = tick + 1
	_pending.append(cmd)


func step() -> void:
	if winner != NO_WINNER:
		return
	tick += 1
	shots.clear()
	deaths.clear()
	retreated.clear()
	for s: int in sides.size():
		_update_cards(s)
	_update_effects()
	# Hold timers tick before new orders, so a hold takes exactly 4 s from the order.
	for u: SimUnit in units:
		_update_hold(u)
		_update_org(u)
		_update_unload(u)
		_update_buffs(u)
		_update_work(u)
	var later: Array[SimCommand] = []
	for cmd: SimCommand in _pending:
		if cmd.tick == tick:
			_run(cmd)
			command_log.append(cmd)
		else:
			later.append(cmd)
	_pending = later
	for u: SimUnit in units:
		_update_chase(u)
		_update_board(u)
		_update_convoy(u)
	for u: SimUnit in units:
		_move(u)
	_separate()
	_carry()
	points.update(units)
	if tick % TICK_RATE == 0:
		_score_points()
	for b: int in bridges.tick_fuses():
		_break_bridge(b)
	if _vision_dirty or (tick - 1) % VISION_TICKS == 0:
		vision.update(units, poi_owner)
		_vision_dirty = false
	_fire()
	_remove_gone()
	_check_end()


## Tug of war (progress.md): only the side holding more points scores, by
## the difference, each whole second.
func _score_points() -> void:
	var diff: int = points.held_by(GameMap.Side.PLAYER) - points.held_by(GameMap.Side.ENEMY)
	if diff > 0:
		score[GameMap.Side.PLAYER] += SCORE_PER_POINT * diff
	elif diff < 0:
		score[GameMap.Side.ENEMY] -= SCORE_PER_POINT * diff


## Section 11: an HQ destroyed ends it at once; otherwise the first to the
## map's score wins, or the higher score when time runs out. Level scores go
## to the side with more HQ health left; level again is a draw.
func _check_end() -> void:
	var lost: Array[bool] = [hq[0] != null and hq_hp(0) <= 0.0, hq[1] != null and hq_hp(1) <= 0.0]
	if lost[0] or lost[1]:
		end_reason = End.HQ_DESTROYED
		winner = DRAW if lost[0] and lost[1] else (1 if lost[0] else 0)
		return
	var goal: int = map.config.victory_points
	if goal > 0 and (score[0] >= goal or score[1] >= goal):
		end_reason = End.SCORE
		winner = _leader()
		return
	if map.config.time_limit_sec > 0 and tick >= map.config.time_limit_sec * TICK_RATE:
		end_reason = End.TIME
		winner = _leader()


func _leader() -> int:
	if score[0] != score[1]:
		return 0 if score[0] > score[1] else 1
	if hq_hp(0) != hq_hp(1):
		return 0 if hq_hp(0) > hq_hp(1) else 1
	return DRAW


## Health left on `side`'s HQ, 0 when it has none.
func hq_hp(side: int) -> float:
	return maxf(0.0, hq[side].hp) if hq[side] != null else 0.0


## Seconds left before the time limit, or -1 for none.
func time_left_sec() -> float:
	if map.config.time_limit_sec <= 0:
		return -1.0
	return maxf(0.0, map.config.time_limit_sec - float(tick) / TICK_RATE)


## Cells per second `u` covers on plain ground at this map's scale.
func cells_per_sec(u: SimUnit) -> float:
	return MapScale.meters_to_cells(u.type.speed_mps, map.config.meters_per_cell) * SPEED_SCALE


## Standard cells (20 m, the doc's unit for ranges and radii) on this map.
func std_cells(cells: float) -> float:
	return MapScale.meters_to_cells(MapScale.standard_cells_to_meters(cells), map.config.meters_per_cell)


func find_path(from: Vector2i, to: Vector2i, vehicle: bool) -> Array[Vector2i]:
	return _pathfinder.find_path(from, to, vehicle)


## Range of `u` against `t` in cells: hold position +10%, high ground +1 cell.
func range_cells(u: SimUnit, t: SimUnit) -> float:
	var r: float = MapScale.meters_to_cells(u.type.weapon.range_m, map.config.meters_per_cell)
	if u.is_held():
		r *= HOLD_RANGE
	if map.elevation_at(u.cell()) > map.elevation_at(t.cell()):
		r += MapScale.meters_to_cells(HIGH_GROUND_RANGE_M, map.config.meters_per_cell)
	return r


func in_range(u: SimUnit, t: SimUnit) -> bool:
	var r: float = range_cells(u, t) * SUBCELL
	return float((t.pos - u.pos).length_squared()) <= r * r


## In range with a clear line of fire.
func can_hit(u: SimUnit, t: SimUnit) -> bool:
	return in_range(u, t) and line_of_fire(u, t)


## Direct fire cannot pass through forest, buildings or HQs; the cells the
## two units stand on do not count, nor the HQ block when an HQ shoots or is
## shot at. Indirect weapons lob over them.
func line_of_fire(u: SimUnit, t: SimUnit) -> bool:
	if u.type.weapon != null and u.type.weapon.indirect:
		return true
	var a: Vector2 = Vector2(u.pos) / SUBCELL
	var d: Vector2 = Vector2(t.pos) / SUBCELL - a
	var n: int = ceili(d.length() * LOS_SAMPLES)
	var from_cell: Vector2i = u.cell()
	var to_cell: Vector2i = t.cell()
	var skip_hq: bool = u.type.structure or t.type.structure
	for k: int in range(1, n):
		var c: Vector2i = Vector2i((a + d * (float(k) / n)).floor())
		if c == from_cell or c == to_cell:
			continue
		if skip_hq and map.terrain_at(c) == Terrain.Type.HQ:
			continue
		if Terrain.BLOCKS_SIGHT[map.terrain_at(c)]:
			return false
	return true


## Share of `u`'s shots that get through `t`'s armour, 0..1.
func pen_factor(u: SimUnit, t: SimUnit) -> float:
	return Weapon.pen_factor(u.type.weapon.penetration, t.type.armor)


## Damage one shot of `u` deals to `t` before `t`'s own reductions; a
## formation that has lost figures hits for less.
func shot_damage(u: SimUnit, t: SimUnit) -> float:
	var dmg: float = u.type.weapon.damage * DAMAGE_SCALE * u.strength() * pen_factor(u, t)
	var eu: int = map.elevation_at(u.cell())
	var et: int = map.elevation_at(t.cell())
	if eu > et:
		dmg *= HIGH_GROUND_DAMAGE
	elif eu < et:
		dmg *= LOW_GROUND_DAMAGE
	return dmg


## Fraction of incoming damage `t` takes.
func damage_taken(t: SimUnit) -> float:
	if not t.is_held():
		return 1.0
	var m: float = HOLD_DAMAGE_TAKEN
	if _in_cover(t.cell()):
		m *= COVER_DAMAGE_TAKEN
	return m


## Changes whenever any unit's position, orders or health differ, or any
## side's supply or cards; for replay checks.
func state_hash() -> int:
	var parts: Array = [tick, rng.state, score, points.owner, points.taker, points.progress, points.presence, winner,
		bridges.hp, bridges.broken, bridges.fuses]
	for s: SideState in sides:
		parts.append_array([s.supply, s.deck, s.hand, s.cooldowns])
	for e: SupportEffect in effects:
		parts.append_array(e.hash_parts())
	for u: SimUnit in units:
		parts.append_array([u.id, u.side, u.pos, u.path_index, u.path, u.hp, u.org, u.routing, u.hold, u.target_id,
			u.retreating, u.carrier_id, u.board_id, u.unload_ticks, u.convoy_goal, u.convoy_cells, u.aps_ticks,
			u.boost_ticks, u.shield, u.work, u.work_ticks])
	return hash(parts)


# --- Cards and supply -------------------------------------------------------

## Weight of everything `side` has on the field, passengers included.
func field_weight(side: int) -> int:
	var w: int = 0
	for u: SimUnit in units:
		if u.side == side:
			w += u.type.weight
	return w


func points_held(side: int) -> int:
	return poi_owner.count(side)


## Section 6: supply per second, slower the more weight is on the field.
func supply_rate(side: int) -> float:
	var cap: int = map.config.weight_cap
	var load_share: float = clampf(float(field_weight(side)) / cap, 0.0, 1.0) if cap > 0 else 0.0
	return SUPPLY_BASE * (1.0 - SUPPLY_WEIGHT_SLOWDOWN * load_share) + SUPPLY_PER_POINT * points_held(side)


## Whether `side` could play the card in hand slot `slot` at `cell` now.
## A support card must suit its aim (Card.Aim); 運補車隊 also needs `cell2`,
## another point the side holds or its HQ, unless it is left at (-1, -1) to
## check the start only.
func can_deploy(side: int, slot: int, card: StringName, cell: Vector2i, cell2: Vector2i = Vector2i(-1, -1)) -> Deploy:
	var s: SideState = sides[side]
	if card == SideState.EMPTY or slot < 0 or slot >= s.hand.size() or s.hand[slot] != card:
		return Deploy.NOT_IN_HAND
	if s.supply < Card.cost(card):
		return Deploy.NO_SUPPLY
	if not Card.is_unit(card):
		if not Support.can_aim(self, side, card, cell):
			return Deploy.BAD_PLACE
		if card == &"supply_convoy" and cell2 != Vector2i(-1, -1) and convoy_goal_at(side, cell, cell2) == SimUnit.NOT_CONVOY:
			return Deploy.BAD_PLACE
		return Deploy.OK
	if field_weight(side) + Card.weight(card) > map.config.weight_cap:
		return Deploy.OVER_WEIGHT
	if not deploy_cell_ok(side, cell, UnitType.of(card).vehicle):
		return Deploy.BAD_PLACE
	return Deploy.OK


## Section 7: inside the side's own spawn zone, or near a point it holds
## that no enemy stands on, on ground the unit can stand on.
func deploy_cell_ok(side: int, cell: Vector2i, vehicle: bool) -> bool:
	if not Movement.passable(map, cell, vehicle):
		return false
	if map.terrain_at(cell) == _spawn_terrain(side):
		return true
	var at: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	for i: int in map.pois.size():
		if poi_owner[i] == side and not points.under_attack(i, side) and at.distance_to(map.pois[i].center) <= DEPLOY_NEAR_POINT_CELLS:
			return true
	return false


static func _spawn_terrain(side: int) -> int:
	return Terrain.Type.PLAYER_SPAWN if side == GameMap.Side.PLAYER else Terrain.Type.ENEMY_SPAWN


func _spawn_zone(side: int) -> CellGroup:
	return map.player_spawn if side == GameMap.Side.PLAYER else map.enemy_spawn


## Supply and cooldowns, once per tick.
func _update_cards(side: int) -> void:
	var s: SideState = sides[side]
	s.gain(supply_rate(side) * TICK_SEC, map.config.supply_cap)
	s.tick_cooldowns()


## Support cards in play; a finished one goes back to the bottom of the deck.
func _update_effects() -> void:
	var still: Array[SupportEffect] = []
	for e: SupportEffect in effects:
		if Support.update(self, e):
			sides[e.side].return_card(e.card)
		else:
			still.append(e)
	effects = still


func _run_deploy(cmd: SimCommand) -> void:
	var r: Deploy = can_deploy(cmd.side, cmd.slot, cmd.card, cmd.target, cmd.target2)
	if r == Deploy.OK and cmd.card == &"supply_convoy" and cmd.target2 == Vector2i(-1, -1):
		r = Deploy.BAD_PLACE
	last_deploy[cmd.side] = r
	if r != Deploy.OK:
		return
	var s: SideState = sides[cmd.side]
	s.play(cmd.slot)
	s.supply -= Card.cost(cmd.card)
	if Card.is_unit(cmd.card):
		var u: SimUnit = spawn(UnitType.of(cmd.card), cmd.side, cmd.target)
		u.card = cmd.card
		# Card cycle (Peanut, 2026-10-23): the card cools down from the moment
		# it is played, so the same card can be played again while its first
		# unit still lives; weight and supply are the only limits.
		s.start_cooldown(cmd.card, roundi(Card.cooldown_sec(cmd.card) * TICK_RATE))
	elif cmd.card == &"supply_convoy":
		var t: SimUnit = spawn(UnitType.supply_truck(), cmd.side, cmd.target)
		t.card = cmd.card
		t.convoy_from = near_own_point(cmd.side, cmd.target)
		t.convoy_goal = convoy_goal_at(cmd.side, cmd.target, cmd.target2)
	else:
		var e: SupportEffect = Support.play(self, cmd.side, cmd.card, cmd.target)
		if e != null:
			effects.append(e)
		else:
			s.return_card(cmd.card)


# --- 運補車隊 ------------------------------------------------------------------

## Index of a point `side` holds whose centre is within deploy reach of
## `cell`, the nearest one; -1 for none.
func near_own_point(side: int, cell: Vector2i) -> int:
	var at: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	var best: int = -1
	var best_d: float = DEPLOY_NEAR_POINT_CELLS
	for i: int in map.pois.size():
		var d: float = at.distance_to(map.pois[i].center)
		if poi_owner[i] == side and d <= best_d:
			best = i
			best_d = d
	return best


## Where a truck starting at `start` and sent to `dest` drives: another point
## the side holds (its index) or the side's HQ (SimUnit.GOAL_HQ);
## SimUnit.NOT_CONVOY when `dest` is neither.
func convoy_goal_at(side: int, start: Vector2i, dest: Vector2i) -> int:
	var from: int = near_own_point(side, start)
	var at: Vector2 = Vector2(dest) + Vector2(0.5, 0.5)
	if hq[side] != null and at.distance_to(Vector2(hq[side].pos) / SUBCELL) <= CONVOY_HQ_REACH_CELLS:
		return SimUnit.GOAL_HQ
	var p: int = near_own_point(side, dest)
	return p if p >= 0 and p != from else SimUnit.NOT_CONVOY


## Centre of a truck's goal, in cells.
func convoy_goal_centre(u: SimUnit) -> Vector2:
	if u.convoy_goal == SimUnit.GOAL_HQ:
		return Vector2(hq[u.side].pos) / SUBCELL if hq[u.side] != null else Vector2(u.cell())
	return map.pois[u.convoy_goal].center


## Supply a truck that drove `cells` pays out.
static func convoy_payout(cells: float) -> int:
	return clampi(floori(cells / CONVOY_CELLS_PER_SUPPLY), CONVOY_MIN, CONVOY_MAX)


## Keeps a truck driving to its goal; a goal the enemy took is swapped for the
## nearest point the side still holds (other than where it set out), or its HQ.
func _update_convoy(u: SimUnit) -> void:
	if not u.is_convoy() or u.routing:
		return
	if u.convoy_goal >= 0 and poi_owner[u.convoy_goal] != u.side:
		u.convoy_goal = _nearest_convoy_goal(u)
		u.clear_path()
	if not u.is_moving() and not convoy_arrived(u) and (tick + u.id) % CHASE_REPATH_TICKS == 0:
		_path_to(u, Vector2i(convoy_goal_centre(u).floor()))


func _nearest_convoy_goal(u: SimUnit) -> int:
	var at: Vector2 = Vector2(u.pos) / SUBCELL
	var best: int = SimUnit.GOAL_HQ
	var best_d: float = at.distance_to(Vector2(hq[u.side].pos) / SUBCELL) if hq[u.side] != null else INF
	for i: int in map.pois.size():
		if poi_owner[i] == u.side and i != u.convoy_from and at.distance_to(map.pois[i].center) < best_d:
			best = i
			best_d = at.distance_to(map.pois[i].center)
	return best


func convoy_arrived(u: SimUnit) -> bool:
	var reach: float = CONVOY_HQ_REACH_CELLS if u.convoy_goal == SimUnit.GOAL_HQ else CapturePoints.RADIUS_CELLS
	return (Vector2(u.pos) / SUBCELL).distance_to(convoy_goal_centre(u)) <= reach


# --- Retreat and transports -------------------------------------------------

## Section 7: drives home and leaves the field there for half the card's
## cost back. A side without a spawn zone cannot retreat.
func _start_retreat(u: SimUnit) -> void:
	var home: CellGroup = _spawn_zone(u.side)
	if home == null:
		return
	u.retreating = true
	_drop_target(u)
	u.unload_ticks = 0
	var group: Array[SimUnit] = [u]
	_run_move(group, Vector2i(home.center.floor()))


## Infantry heads for `t` and climbs in once next to it.
func _run_board(group: Array[SimUnit], t: SimUnit) -> void:
	if t == null or t.type.transport_capacity <= 0 or t.retreating:
		return
	for u: SimUnit in group:
		if u.side != t.side or u.type.kind != UnitType.Kind.INFANTRY:
			continue
		u.board_id = t.id
		u.chase_cell = Vector2i(-1, -1)
		u.pending_dest = Vector2i(-1, -1)
		u.clear_path()
		if u.hold == SimUnit.Hold.ENTERING:
			u.hold = SimUnit.Hold.NONE
		elif u.hold == SimUnit.Hold.HELD:
			u.hold = SimUnit.Hold.LEAVING
			u.hold_ticks = HOLD_LEAVE_TICKS


func free_capacity(t: SimUnit) -> int:
	var used: int = 0
	for id: int in t.passengers:
		used += unit(id).type.weight
	return t.type.transport_capacity - used


func _update_board(u: SimUnit) -> void:
	if u.board_id == 0:
		return
	var t: SimUnit = unit(u.board_id)
	if t == null or t.retreating or u.routing:
		u.board_id = 0
		u.clear_path()
		return
	if not u.can_move():
		return
	var reach: float = BOARD_RANGE_CELLS * SUBCELL
	if float((t.pos - u.pos).length_squared()) <= reach * reach:
		u.board_id = 0
		u.clear_path()
		if free_capacity(t) >= u.type.weight:
			u.carrier_id = t.id
			u.pos = t.pos
			_drop_target(u)
			t.passengers.append(u.id)
		return
	var c: Vector2i = t.cell()
	if c != u.chase_cell and (not u.is_moving() or (tick + u.id) % CHASE_REPATH_TICKS == 0):
		u.chase_cell = c
		_path_to(u, c)


func _start_unload(t: SimUnit) -> void:
	if t.passengers.is_empty() or t.unload_ticks > 0:
		return
	t.clear_path()
	t.unload_ticks = UNLOAD_TICKS


func _update_unload(t: SimUnit) -> void:
	if t.unload_ticks <= 0:
		return
	t.unload_ticks -= 1
	if t.unload_ticks == 0:
		_eject(t)


## Puts every passenger down on its own cell around the transport.
func _eject(t: SimUnit) -> void:
	var taken: Dictionary[Vector2i, bool] = {}
	var at: Vector2i = t.cell()
	for id: int in t.passengers:
		var p: SimUnit = unit(id)
		var dest: Vector2i = at
		for off: Vector2i in slot_offsets(t.passengers.size() + 8):
			var c: Vector2i = at + off
			if not taken.has(c) and Movement.passable(map, c, false):
				dest = c
				break
		taken[dest] = true
		p.carrier_id = 0
		p.prev_pos = t.pos
		p.pos = cell_center(dest)
	t.passengers = PackedInt32Array()
	t.unload_ticks = 0


## Passengers ride along with their transport.
func _carry() -> void:
	for u: SimUnit in units:
		if not u.on_map():
			var t: SimUnit = unit(u.carrier_id)
			u.pos = t.pos
			u.prev_pos = t.prev_pos


## Retreating units that reached home leave; one that lost its way (a rally
## stops it where it is) sets off again.
func _home_cells_reached() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in units:
		if not u.retreating or not u.on_map() or not u.is_alive():
			continue
		if map.terrain_at(u.cell()) == _spawn_terrain(u.side):
			out.append(u)
		elif not u.is_moving() and not u.routing and u.can_move() and (tick + u.id) % CHASE_REPATH_TICKS == 0:
			_path_to(u, Vector2i(_spawn_zone(u.side).center.floor()))
	return out


static func cell_center(cell: Vector2i) -> Vector2i:
	return cell * SUBCELL + Vector2i(SUBCELL / 2, SUBCELL / 2)


# --- Commands ---------------------------------------------------------------

## Routing and retreating units take no orders, nor do passengers, supply
## trucks or buildings.
func _run(cmd: SimCommand) -> void:
	var own: Array[SimUnit] = []
	for id: int in cmd.unit_ids:
		var u: SimUnit = unit(id)
		if (u != null and u.side == cmd.side and not u.routing and not u.retreating and u.on_map() and not own.has(u)
				and not u.is_convoy() and not u.type.structure):
			own.append(u)
	# Any other order calls off boarding and unloading, and engineer work.
	if cmd.kind != SimCommand.Kind.LOAD and cmd.kind != SimCommand.Kind.UNLOAD:
		for u: SimUnit in own:
			u.board_id = 0
			u.unload_ticks = 0
	if cmd.kind != SimCommand.Kind.ENGINEER:
		for u: SimUnit in own:
			_stop_work(u)
	match cmd.kind:
		SimCommand.Kind.ENGINEER:
			for u: SimUnit in own:
				_start_work(u)
		SimCommand.Kind.DEPLOY:
			_run_deploy(cmd)
		SimCommand.Kind.RETREAT:
			for u: SimUnit in own:
				_start_retreat(u)
		SimCommand.Kind.LOAD:
			_run_board(own, unit(cmd.target_unit))
		SimCommand.Kind.UNLOAD:
			for u: SimUnit in own:
				_start_unload(u)
		SimCommand.Kind.STOP:
			for u: SimUnit in own:
				u.clear_path()
				_drop_target(u)
				u.pending_dest = Vector2i(-1, -1)
		SimCommand.Kind.MOVE:
			for u: SimUnit in own:
				_drop_target(u)
			_run_move(own, cmd.target)
		SimCommand.Kind.ATTACK:
			_run_attack(own, unit(cmd.target_unit))
		SimCommand.Kind.HOLD:
			for u: SimUnit in own:
				_toggle_hold(u)


## Each unit gets its own destination cell near the target so a group does
## not pile onto one cell. Units closest to the target take the closest cells.
func _run_move(group: Array[SimUnit], target: Vector2i) -> void:
	var goal: Vector2i = cell_center(target)
	group.sort_custom(func(a: SimUnit, b: SimUnit) -> bool:
		var da: int = (a.pos - goal).length_squared()
		var db: int = (b.pos - goal).length_squared()
		return da < db or (da == db and a.id < b.id))
	var taken: Dictionary[Vector2i, bool] = {}
	var slots: Array[Vector2i] = slot_offsets(group.size())
	for u: SimUnit in group:
		var dest: Vector2i = target
		for off: Vector2i in slots:
			var c: Vector2i = target + off
			if not taken.has(c) and Movement.passable(map, c, u.type.vehicle):
				dest = c
				break
		taken[dest] = true
		match u.hold:
			SimUnit.Hold.HELD:
				u.hold = SimUnit.Hold.LEAVING
				u.hold_ticks = HOLD_LEAVE_TICKS
				u.pending_dest = dest
			SimUnit.Hold.LEAVING:
				u.pending_dest = dest
			_:
				u.hold = SimUnit.Hold.NONE
				_path_to(u, dest)


## Force-attack: every armed unit in the group chases and shoots `target`,
## friend or foe, until it dies or the unit gets another order.
func _run_attack(group: Array[SimUnit], target: SimUnit) -> void:
	if target == null or not target.on_map():
		return
	for u: SimUnit in group:
		if u.type.weapon == null or u == target or not u.type.weapon.may_target(target.type.kind):
			continue
		u.target_id = target.id
		u.forced_target = true
		u.chase_cell = Vector2i(-1, -1)
		u.pending_dest = Vector2i(-1, -1)
		u.clear_path()


## Infantry only. Ordering it again cancels: digging in stops at once, a held
## unit takes 2 s to get out, and a unit getting out stays put.
func _toggle_hold(u: SimUnit) -> void:
	if not u.type.can_hold():
		return
	match u.hold:
		SimUnit.Hold.NONE:
			u.clear_path()
			u.hold = SimUnit.Hold.ENTERING
			u.hold_ticks = HOLD_ENTER_TICKS
		SimUnit.Hold.ENTERING:
			u.hold = SimUnit.Hold.NONE
		SimUnit.Hold.HELD:
			u.hold = SimUnit.Hold.LEAVING
			u.hold_ticks = HOLD_LEAVE_TICKS
		SimUnit.Hold.LEAVING:
			u.hold = SimUnit.Hold.HELD
			u.pending_dest = Vector2i(-1, -1)


func _drop_target(u: SimUnit) -> void:
	u.target_id = 0
	u.forced_target = false


func _path_to(u: SimUnit, dest: Vector2i) -> void:
	if not Movement.passable(map, u.cell(), u.type.vehicle):
		_unstick(u)
	var from: Vector2i = u.cell()
	# A goal on ground the unit cannot stand on (an HQ) would make the search
	# comb the whole map; aim for the nearest cell it can stand on instead.
	if not Movement.passable(map, dest, u.type.vehicle):
		for off: Vector2i in slot_offsets(48):
			if Movement.passable(map, dest + off, u.type.vehicle):
				dest += off
				break
	u.path = Movement.smooth(map, from, _pathfinder.find_path(from, dest, u.type.vehicle), u.type.vehicle)
	u.path_index = 0


## Cell offsets around a target, nearest first, enough for `count` units
## even when some cells are blocked.
static func slot_offsets(count: int) -> Array[Vector2i]:
	var r: int = int(ceil(sqrt(float(count)))) + 2
	var out: Array[Vector2i] = []
	for y: int in range(-r, r + 1):
		for x: int in range(-r, r + 1):
			out.append(Vector2i(x, y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var la: int = a.length_squared()
		var lb: int = b.length_squared()
		return la < lb or (la == lb and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return out


# --- Per-tick updates -------------------------------------------------------

func _update_hold(u: SimUnit) -> void:
	if u.hold != SimUnit.Hold.ENTERING and u.hold != SimUnit.Hold.LEAVING:
		return
	u.hold_ticks -= 1
	if u.hold_ticks > 0:
		return
	if u.hold == SimUnit.Hold.ENTERING:
		u.hold = SimUnit.Hold.HELD
		return
	u.hold = SimUnit.Hold.NONE
	if u.pending_dest != Vector2i(-1, -1):
		_path_to(u, u.pending_dest)
		u.pending_dest = Vector2i(-1, -1)


## Recovers organization once the unit has not been hit for a while; faster
## held or in forest, slower on the move (but not while routing). A routing
## unit rallies at RALLY_AT and stops where it is.
func _update_org(u: SimUnit) -> void:
	if u.org >= u.type.max_org or tick - u.last_hit_tick < ORG_RECOVER_DELAY_TICKS:
		return
	var rate: float = ORG_RECOVER_PER_SEC
	if u.is_held():
		rate *= ORG_RECOVER_HELD
	if map.terrain_at(u.cell()) == Terrain.Type.FOREST:
		rate *= ORG_RECOVER_FOREST
	if u.is_moving() and not u.routing:
		rate *= ORG_RECOVER_MOVING
	u.org = minf(u.type.max_org, u.org + rate * TICK_SEC)
	if u.routing and u.org >= u.type.max_org * RALLY_AT:
		u.routing = false
		u.clear_path()


## Force-attacking units walk until the target is in range, re-planning as it moves.
func _update_chase(u: SimUnit) -> void:
	if not u.forced_target or u.routing:
		return
	var t: SimUnit = unit(u.target_id)
	if t == null or not t.on_map():
		_drop_target(u)
		u.clear_path()
		return
	# In range is not enough: guns that reach further than they see (artillery,
	# mortars, loitering munitions) keep closing in until their side sees it.
	if can_hit(u, t) and vision.sees(u.side, t):
		u.clear_path()
		return
	if not u.can_move():
		return
	var c: Vector2i = t.cell()
	var due: bool = (tick + u.id) % CHASE_REPATH_TICKS == 0
	if (c != u.chase_cell and (not u.is_moving() or due)) or (not u.is_moving() and due):
		u.chase_cell = c
		_path_to(u, c)


func _move(u: SimUnit) -> void:
	u.prev_pos = u.pos
	if u.type.structure:
		return
	if not Movement.passable(map, u.cell(), u.type.vehicle):
		_unstick(u)
		if u.is_moving():
			_path_to(u, u.destination())
	if not u.is_moving():
		return
	var base: float = u.type.speed_mps * _subcells_per_tick_per_mps
	if u.routing:
		base *= ROUT_SPEED
	elif u.is_suppressed():
		base *= SUPPRESSED_SPEED
	if u.boost_ticks > 0:
		base *= Support.ASSAULT_SPEED
	# Distance left this tick, as a fraction of a full tick at the current speed.
	var time_left: float = 1.0
	var replanned: bool = false
	while time_left > 0.0 and u.is_moving():
		var target: Vector2i = cell_center(u.path[u.path_index])
		# Pushed off its path, a straight walk to the next waypoint can clip a
		# building corner: go back to the middle of the current cell and
		# re-plan from there instead.
		if not replanned and not _straight_ok(u, target):
			replanned = true
			_path_to(u, u.destination())
			u.path.insert(0, u.cell())
			continue
		var d: Vector2 = Vector2(target - u.pos)
		var dist: float = d.length()
		if dist == 0.0:
			u.path_index += 1
			continue
		var speed: float = base * Movement.terrain_speed(map, u.cell(), u.type.vehicle)
		if u.type.vehicle and bridges.slows(u.cell()):
			speed *= Bridges.SLOW_SPEED
		if _climbing(u.pos, d / dist):
			speed *= Movement.UPHILL_FACTOR
		if speed <= 0.0:
			break
		var reach: float = speed * time_left
		if dist <= reach:
			u.pos = target
			time_left -= dist / speed
			u.path_index += 1
		else:
			u.pos += Vector2i((d * (reach / dist)).round())
			time_left = 0.0
	if not u.is_moving():
		u.clear_path()
	if u.is_convoy():
		u.convoy_cells += Vector2(u.pos - u.prev_pos).length() / SUBCELL


## Whether `u` can walk in a straight line from where it stands to `target`
## (sub-cells) without stepping onto ground it cannot cross.
func _straight_ok(u: SimUnit, target: Vector2i) -> bool:
	var a: Vector2 = Vector2(u.pos) / SUBCELL
	var d: Vector2 = Vector2(target) / SUBCELL - a
	var n: int = ceili(d.length() * Movement.LEG_SAMPLES)
	var prev: Vector2i = u.cell()
	for k: int in range(1, n + 1):
		var c: Vector2i = Vector2i((a + d * (float(k) / n)).floor())
		if c == prev:
			continue
		if not Movement.can_step(map, prev, c, u.type.vehicle):
			return false
		prev = c
	return true


## A unit that somehow stands on ground it cannot cross is put on the
## nearest cell it can, so it never gets stuck there.
func _unstick(u: SimUnit, count: int = 24) -> void:
	for off: Vector2i in slot_offsets(count):
		var c: Vector2i = u.cell() + off
		if Movement.passable(map, c, u.type.vehicle):
			u.pos = cell_center(c)
			return


## Whether moving from `pos` along `dir` climbs a ramp: the cell half a cell
## ahead is higher than the cell half a cell behind, so the slow part is the
## centre-to-centre stretch between a low cell and a high one.
func _climbing(pos: Vector2i, dir: Vector2) -> bool:
	var half: Vector2 = dir * (SUBCELL * 0.5)
	var p: Vector2 = Vector2(pos)
	var back: Vector2i = Vector2i(((p - half) / SUBCELL).floor())
	var ahead: Vector2i = Vector2i(((p + half) / SUBCELL).floor())
	return map.in_bounds(back) and map.in_bounds(ahead) and map.elevation_at(ahead) > map.elevation_at(back)


## Pushes overlapping units apart. Units that cannot move (holding) do not
## budge; a push never moves a unit onto ground it could not walk to.
func _separate() -> void:
	for i: int in units.size():
		var a: SimUnit = units[i]
		if not a.on_map() or a.type.structure:
			continue
		for j: int in range(i + 1, units.size()):
			var b: SimUnit = units[j]
			if not b.on_map() or b.type.structure:
				continue
			var min_d: float = (_radius(a) + _radius(b)) * SUBCELL
			var d: Vector2i = b.pos - a.pos
			var ls: int = d.length_squared()
			if float(ls) >= min_d * min_d:
				continue
			var a_moves: bool = a.can_move()
			var b_moves: bool = b.can_move()
			if not a_moves and not b_moves:
				continue
			var dist: float = sqrt(float(ls))
			# Units on the same spot split along x, lower id to the left.
			var n: Vector2 = Vector2(d) / dist if ls > 0 else Vector2(1.0, 0.0)
			var overlap: float = min_d - dist
			var share_a: float = 0.0 if not a_moves else (1.0 if not b_moves else 0.5)
			_nudge(a, Vector2i((-n * overlap * share_a).round()))
			_nudge(b, Vector2i((n * overlap * (1.0 - share_a)).round()))


func _radius(u: SimUnit) -> float:
	return VEHICLE_RADIUS if u.type.vehicle else INFANTRY_RADIUS


func _nudge(u: SimUnit, by: Vector2i) -> void:
	if by == Vector2i.ZERO:
		return
	var to: Vector2i = u.pos + by
	var from_cell: Vector2i = u.cell()
	var to_cell: Vector2i = Vector2i(to.x / SUBCELL, to.y / SUBCELL)
	if to.x < 0 or to.y < 0:
		return
	if to_cell != from_cell and not Movement.can_step(map, from_cell, to_cell, u.type.vehicle):
		return
	u.pos = to


# --- Combat -----------------------------------------------------------------

## Picks targets and fires every ready weapon from the state at the start of
## the phase, then applies all hits, so the order units are listed in does
## not decide who shoots first.
func _fire() -> void:
	var hits: Array = []  # [shooter, target, impact]
	for u: SimUnit in units:
		if u.type.weapon == null:
			continue
		if u.cooldown > 0:
			u.cooldown -= 1
		if u.routing or not u.on_map():
			continue
		var t: SimUnit = _current_target(u)
		if t == null or u.cooldown > 0:
			continue
		var w: Weapon = u.type.weapon
		if u.burst_left <= 0:
			u.burst_left = w.burst
		u.burst_left -= 1
		var wait: float = w.burst_interval_sec if u.burst_left > 0 else w.cooldown_sec
		if u.is_suppressed():
			wait *= SUPPRESSED_COOLDOWN
		u.cooldown = maxi(1, roundi(wait * TICK_RATE))
		hits.append([u, t, t.pos])
		var s: Shot = Shot.new()
		s.side = u.side
		s.from = u.pos
		s.to = t.pos
		s.splash = _splash_subcells(u.type.weapon)
		shots.append(s)
	for h: Array in hits:
		var u: SimUnit = h[0]
		if u.type.weapon.is_area():
			var impact: Vector2i = h[2]
			var r: float = float(_splash_subcells(u.type.weapon))
			for v: SimUnit in units:
				if v.type.kind != UnitType.Kind.AIR and v.on_map() and float((v.pos - impact).length_squared()) <= r * r:
					_hit(u, v)
			if BRIDGE_BREAKERS.has(u.type.id):
				damage_bridges_near(Vector2(impact) / SUBCELL, r / SUBCELL, u.type.weapon.damage * DAMAGE_SCALE * u.strength())
		else:
			_hit(u, h[1])


## The unit `u` shoots at this tick, or null. Forced targets are kept until
## they die; otherwise only idle units pick targets (moving orders come first).
## Only targets its side can see (section 10): long guns need a spotter.
func _current_target(u: SimUnit) -> SimUnit:
	if u.forced_target:
		var f: SimUnit = unit(u.target_id)
		return f if f != null and _can_shoot(u, f) and u.type.weapon.may_target(f.type.kind) else null
	if u.is_moving():
		u.target_id = 0
		return null
	var cur: SimUnit = unit(u.target_id)
	if cur != null and _can_shoot(u, cur):
		return cur
	u.target_id = 0
	var best: SimUnit = null
	var best_mult: float = 0.0
	var best_d: int = 0
	for t: SimUnit in units:
		if t.side == u.side or not u.type.weapon.may_target(t.type.kind) or not _can_shoot(u, t):
			continue
		# Shots that cannot get through the armour are not worth firing.
		var m: float = pen_factor(u, t)
		if m <= 0.0:
			continue
		if u.type.weapon.is_area() and _friend_in_blast(u, t.pos):
			continue
		var d: int = (t.pos - u.pos).length_squared()
		# Best penetration first, then the closest; ids break ties.
		if best == null or m > best_mult or (m == best_mult and d < best_d):
			best = t
			best_mult = m
			best_d = d
	if best != null:
		u.target_id = best.id
	return best


func _can_shoot(u: SimUnit, t: SimUnit) -> bool:
	return t.is_alive() and t.on_map() and vision.sees(u.side, t) and can_hit(u, t)


## Area weapons do not pick targets on their own when the blast would hit a friend.
func _friend_in_blast(u: SimUnit, impact: Vector2i) -> bool:
	var r: float = float(_splash_subcells(u.type.weapon))
	for v: SimUnit in units:
		if v.side == u.side and v.on_map() and float((v.pos - impact).length_squared()) <= r * r:
			return true
	return false


func _splash_subcells(w: Weapon) -> int:
	return roundi(MapScale.meters_to_cells(w.splash_m, map.config.meters_per_cell) * SUBCELL)


## One shot of `src` landing on `v`: damage, and organization lost to
## suppression. Both shrink with cover and with armour the shot cannot pierce.
func _hit(src: SimUnit, v: SimUnit) -> void:
	var w: Weapon = src.type.weapon
	_strike(src.side, v, shot_damage(src, v), w.suppression * src.strength() * pen_factor(src, v),
		w.targets == Weapon.Targets.ARMOR_ONLY, src.pos)


## A support card's shell or missile landing on `v` (Support): the pacing
## ×0.7 and penetration against `v`'s armour apply as for a unit's shot.
## `anti_armor` hits are halved by 主動防護系統.
func support_strike(side: int, v: SimUnit, damage: float, penetration: int, suppression: float, anti_armor: bool, from: Vector2i) -> void:
	var f: float = Weapon.pen_factor(penetration, v.type.armor)
	_strike(side, v, damage * DAMAGE_SCALE * f, suppression * f, anti_armor, from)


## `dmg` and `sup` before `v`'s cover. A building never loses organization;
## a 附加裝甲 shield soaks damage first.
func _strike(side: int, v: SimUnit, dmg: float, sup: float, anti_armor: bool, from: Vector2i) -> void:
	if not v.is_alive():
		return
	var taken: float = damage_taken(v)
	sup *= taken
	if sup > 0.0 and not v.type.structure:
		v.org = maxf(0.0, v.org - sup)
		v.last_hit_tick = tick
		if v.org <= 0.0 and not v.routing:
			_rout(v, from)
	var raw: float = dmg * taken
	if anti_armor and v.aps_ticks > 0:
		raw *= Support.APS_TAKEN
	if v.shield > 0.0:
		var soaked: float = minf(v.shield, raw)
		v.shield -= soaked
		raw -= soaked
	var dealt: float = minf(raw, v.hp)
	v.hp -= dealt
	if side != v.side:
		return
	var s: int = side
	friendly_damage[s] += dealt
	var owed: int = int(friendly_damage[s] / 100.0) * FF_SCORE_PER_100
	if owed > _ff_damage_penalised[s]:
		_penalise(s, owed - _ff_damage_penalised[s])
		_ff_damage_penalised[s] = owed
	if not v.is_alive():
		_penalise(s, v.type.weight * FF_KILL_SCORE_PER_WEIGHT)


## Out of organization: drops every order, leaves its position and walks
## slowly back to its spawn zone (or away from `from`) until it rallies.
## Enemies that keep after it can wipe it out, since it does not fire back.
func _rout(u: SimUnit, from: Vector2i) -> void:
	u.routing = true
	_drop_target(u)
	_stop_work(u)
	u.pending_dest = Vector2i(-1, -1)
	u.hold = SimUnit.Hold.NONE
	_path_to(u, _rout_cell(u, from))


func _rout_cell(u: SimUnit, from: Vector2i) -> Vector2i:
	var home: CellGroup = map.player_spawn if u.side == GameMap.Side.PLAYER else map.enemy_spawn
	if home != null:
		return Vector2i(home.center.round())
	var away: Vector2 = Vector2(u.pos - from)
	away = away.normalized() if away != Vector2.ZERO else Vector2(1.0, 0.0)
	var c: Vector2i = u.cell() + Vector2i((away * ROUT_FALLBACK_CELLS).round())
	return Vector2i(clampi(c.x, 0, map.width - 1), clampi(c.y, 0, map.height - 1))


func _penalise(side: int, points: int) -> void:
	ff_penalty[side] += points
	score[side] = maxi(0, score[side] - points)


## Takes dead and retreated units off the field. A unit card is already
## cycling back from when it was played, so dying costs nothing more and a
## retreat only refunds half its cost (its passengers' too). A destroyed
## transport's passengers get out hurt.
func _remove_gone() -> void:
	var leaving: Dictionary[int, bool] = {}
	for u: SimUnit in _home_cells_reached():
		leaving[u.id] = true
		for id: int in u.passengers:
			leaving[id] = true
	var kept: Array[SimUnit] = []
	for u: SimUnit in units:
		if not u.is_alive():
			deaths.append(u)
			if not u.passengers.is_empty():
				for id: int in u.passengers:
					unit(id).hp *= 1.0 - WRECKED_CARRIER_LOSS
				_eject(u)
			if u.is_convoy():
				# A truck shot up delivers nothing; its card goes straight back.
				sides[u.side].return_card(u.card)
		elif u.is_convoy() and convoy_arrived(u):
			retreated.append(u)
			var cs: SideState = sides[u.side]
			cs.gain(convoy_payout(u.convoy_cells), map.config.supply_cap)
			cs.return_card(u.card)
		elif leaving.has(u.id):
			retreated.append(u)
			if u.card != &"":
				var s: SideState = sides[u.side]
				s.gain(Card.cost(u.card) * RETREAT_REFUND, map.config.supply_cap)
		else:
			kept.append(u)
	for u: SimUnit in deaths:
		_by_id.erase(u.id)
	for u: SimUnit in retreated:
		_by_id.erase(u.id)
	units = kept
	if deaths.is_empty() and retreated.is_empty():
		return
	for u: SimUnit in units:
		if u.target_id != 0 and not _by_id.has(u.target_id):
			if u.forced_target:
				u.clear_path()
			_drop_target(u)


## Forest, or next to a building (section 9 extra cover while holding).
func _in_cover(c: Vector2i) -> bool:
	if map.terrain_at(c) == Terrain.Type.FOREST:
		return true
	for off: Vector2i in Pathfinder.DIRS:
		var n: Vector2i = c + off
		if map.in_bounds(n) and map.terrain_at(n) == Terrain.Type.BUILDING:
			return true
	return false


# --- Support cards, buffs and bridges ----------------------------------------

## Units standing on the ground (not riding, not in the air), buildings too.
func ground_units() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in units:
		if u.on_map() and u.is_alive() and u.type.kind != UnitType.Kind.AIR:
			out.append(u)
	return out


## Middle of `side`'s spawn zone, or of its HQ, in cells.
func home_centre(side: int) -> Vector2:
	var home: CellGroup = _spawn_zone(side)
	if home != null:
		return home.center
	return Vector2(hq[side].pos) / SUBCELL if hq[side] != null else Vector2(map.width, map.height) * 0.5


## A blast for the view to draw (support cards), radius in cells.
func add_blast(side: int, at: Vector2i, radius_cells: float) -> void:
	var s: Shot = Shot.new()
	s.side = side
	s.from = at
	s.to = at
	s.splash = roundi(radius_cells * SUBCELL)
	shots.append(s)


## Standing bridges with a cell within `r` cells of `at` (cells).
func bridges_near(at: Vector2, r: float) -> Array[int]:
	var out: Array[int] = []
	for y: int in range(floori(at.y - r), ceili(at.y + r) + 1):
		for x: int in range(floori(at.x - r), ceili(at.x + r) + 1):
			var c: Vector2i = Vector2i(x, y)
			var b: int = bridges.at(c)
			if b >= 0 and not bridges.broken[b] and not out.has(b) and (Vector2(c) + Vector2(0.5, 0.5)).distance_to(at) <= r + 0.5:
				out.append(b)
	return out


## Shells landing at `at` wear down every bridge within `r` cells once.
func damage_bridges_near(at: Vector2, r: float, amount: float) -> void:
	for b: int in bridges_near(at, r):
		damage_bridge(b, amount)


func damage_bridge(b: int, amount: float) -> void:
	if bridges.damage(b, amount):
		_break_bridge(b)


## Section 4.4: the bridge turns into water. Whoever was on it takes 200 and
## falls in: vehicles are lost, infantry that lives is washed to the nearest
## bank.
func _break_bridge(b: int) -> void:
	if bridges.broken[b]:
		return
	var on_it: Array[SimUnit] = []
	for u: SimUnit in units:
		if u.on_map() and u.is_alive() and not u.type.structure and bridges.at(u.cell()) == b:
			on_it.append(u)
	bridges.set_broken(b)
	_pathfinder.refresh(map.bridges[b].cells)
	for u: SimUnit in on_it:
		_stop_work(u)
		u.hp = 0.0 if u.type.vehicle else maxf(0.0, u.hp - Bridges.FALL_DAMAGE)
		if u.is_alive():
			_drop_target(u)
			u.hold = SimUnit.Hold.NONE
			u.pending_dest = Vector2i(-1, -1)
			u.clear_path()
			_unstick(u, 200)
	_vision_dirty = true


## 主動防護系統 and 裝甲突擊 wear off.
func _update_buffs(u: SimUnit) -> void:
	if u.aps_ticks > 0:
		u.aps_ticks -= 1
	if u.boost_ticks > 0:
		u.boost_ticks -= 1


## Engineers (section 4.4): on a standing bridge they plant a charge, next to
## a broken one they rebuild it for 3 supply. They stop where they are.
func _start_work(u: SimUnit) -> void:
	if u.type.id != &"engineer" or u.work != SimUnit.Work.NONE:
		return
	var b: int = bridges.at(u.cell())
	if b >= 0 and not bridges.broken[b]:
		u.work = SimUnit.Work.DEMOLISH
		u.work_ticks = Bridges.PLANT_TICKS
	else:
		b = bridges.broken_near(u.cell())
		if b < 0 or sides[u.side].supply < Bridges.REPAIR_COST:
			return
		sides[u.side].supply -= Bridges.REPAIR_COST
		u.work = SimUnit.Work.REPAIR
		u.work_ticks = Bridges.REPAIR_TICKS
	u.work_bridge = b
	u.work_since = tick
	u.clear_path()
	_drop_target(u)
	u.pending_dest = Vector2i(-1, -1)


## Calls work off; an unfinished repair gives its supply back.
func _stop_work(u: SimUnit) -> void:
	if u.work == SimUnit.Work.REPAIR:
		sides[u.side].gain(Bridges.REPAIR_COST, map.config.supply_cap)
	u.work = SimUnit.Work.NONE
	u.work_ticks = 0
	u.work_bridge = -1


## Getting hit or the bridge changing under them calls the work off.
func _update_work(u: SimUnit) -> void:
	if u.work == SimUnit.Work.NONE:
		return
	var want_broken: bool = u.work == SimUnit.Work.REPAIR
	if u.last_hit_tick >= u.work_since or u.routing or bridges.broken[u.work_bridge] != want_broken:
		_stop_work(u)
		return
	u.work_ticks -= 1
	if u.work_ticks > 0:
		return
	var b: int = u.work_bridge
	if u.work == SimUnit.Work.DEMOLISH:
		bridges.fuses.append([b, Bridges.FUSE_TICKS])
	else:
		bridges.rebuild(b)
		_pathfinder.refresh(map.bridges[b].cells)
		_vision_dirty = true
	u.work = SimUnit.Work.NONE
	u.work_ticks = 0
	u.work_bridge = -1
