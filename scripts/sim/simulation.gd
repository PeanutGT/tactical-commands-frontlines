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
const INFANTRY_RADIUS: float = 0.3
const VEHICLE_RADIUS: float = 0.45


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

var _by_id: Dictionary[int, SimUnit] = {}
var _next_id: int = 1
var _pending: Array[SimCommand] = []
var _pathfinder: Pathfinder
## Sub-cells per tick for 1 m/s on this map.
var _subcells_per_tick_per_mps: float = 0.0
## Score already taken off for friendly damage (whole 100s only).
var _ff_damage_penalised: Array[int] = [0, 0]


func _init(p_map: GameMap, seed_value: int = 1) -> void:
	map = p_map
	rng = SimRng.new(seed_value)
	_pathfinder = Pathfinder.new(map)
	_pathfinder.prepare()
	_subcells_per_tick_per_mps = MapScale.meters_to_cells(1.0, map.config.meters_per_cell) * SUBCELL / TICK_RATE


func spawn(type: UnitType, side: int, cell: Vector2i) -> SimUnit:
	var u: SimUnit = SimUnit.new()
	u.id = _next_id
	_next_id += 1
	u.type = type
	u.side = side
	u.hp = type.max_hp
	u.pos = cell_center(cell)
	u.prev_pos = u.pos
	units.append(u)
	_by_id[u.id] = u
	return u


## Null once the unit has died.
func unit(id: int) -> SimUnit:
	return _by_id.get(id)


func issue(cmd: SimCommand) -> void:
	cmd.tick = tick + 1
	_pending.append(cmd)


func step() -> void:
	tick += 1
	shots.clear()
	deaths.clear()
	# Hold timers tick before new orders, so a hold takes exactly 4 s from the order.
	for u: SimUnit in units:
		_update_hold(u)
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
	for u: SimUnit in units:
		_move(u)
	_separate()
	_fire()
	_remove_dead()


## Cells per second `u` covers on plain ground at this map's scale.
func cells_per_sec(u: SimUnit) -> float:
	return MapScale.meters_to_cells(u.type.speed_mps, map.config.meters_per_cell)


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


## Damage one shot of `u` deals to `t` before `t`'s own reductions.
func shot_damage(u: SimUnit, t: SimUnit) -> float:
	var dmg: float = u.type.weapon.damage * u.type.weapon.multiplier(t.type.kind)
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


## Changes whenever any unit's position, orders or health differ; for replay checks.
func state_hash() -> int:
	var parts: Array = [tick, rng.state, score]
	for u: SimUnit in units:
		parts.append_array([u.id, u.side, u.pos, u.path_index, u.path, u.hp, u.hold, u.target_id])
	return hash(parts)


static func cell_center(cell: Vector2i) -> Vector2i:
	return cell * SUBCELL + Vector2i(SUBCELL / 2, SUBCELL / 2)


# --- Commands ---------------------------------------------------------------

func _run(cmd: SimCommand) -> void:
	var own: Array[SimUnit] = []
	for id: int in cmd.unit_ids:
		var u: SimUnit = unit(id)
		if u != null and u.side == cmd.side and not own.has(u):
			own.append(u)
	match cmd.kind:
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
	if target == null:
		return
	for u: SimUnit in group:
		if u.type.weapon == null or u == target:
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
	var from: Vector2i = u.cell()
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


## Force-attacking units walk until the target is in range, re-planning as it moves.
func _update_chase(u: SimUnit) -> void:
	if not u.forced_target:
		return
	var t: SimUnit = unit(u.target_id)
	if t == null:
		_drop_target(u)
		u.clear_path()
		return
	if in_range(u, t):
		u.clear_path()
		return
	if not u.can_move():
		return
	var c: Vector2i = t.cell()
	if c != u.chase_cell and (not u.is_moving() or (tick + u.id) % CHASE_REPATH_TICKS == 0):
		u.chase_cell = c
		_path_to(u, c)


func _move(u: SimUnit) -> void:
	u.prev_pos = u.pos
	if not u.is_moving():
		return
	var base: float = u.type.speed_mps * _subcells_per_tick_per_mps
	# Distance left this tick, as a fraction of a full tick at the current speed.
	var time_left: float = 1.0
	while time_left > 0.0 and u.is_moving():
		var target: Vector2i = cell_center(u.path[u.path_index])
		var d: Vector2 = Vector2(target - u.pos)
		var dist: float = d.length()
		if dist == 0.0:
			u.path_index += 1
			continue
		var speed: float = base * Movement.terrain_speed(map, u.cell(), u.type.vehicle)
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
		for j: int in range(i + 1, units.size()):
			var b: SimUnit = units[j]
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
		var t: SimUnit = _current_target(u)
		if t == null or u.cooldown > 0:
			continue
		u.cooldown = maxi(1, roundi(u.type.weapon.cooldown_sec * TICK_RATE))
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
				if float((v.pos - impact).length_squared()) <= r * r:
					_damage(u, v, shot_damage(u, v))
		else:
			var t: SimUnit = h[1]
			_damage(u, t, shot_damage(u, t))


## The unit `u` shoots at this tick, or null. Forced targets are kept until
## they die; otherwise only idle units pick targets (moving orders come first).
func _current_target(u: SimUnit) -> SimUnit:
	if u.forced_target:
		var f: SimUnit = unit(u.target_id)
		return f if f != null and f.is_alive() and in_range(u, f) else null
	if u.is_moving():
		u.target_id = 0
		return null
	var cur: SimUnit = unit(u.target_id)
	if cur != null and cur.is_alive() and in_range(u, cur):
		return cur
	u.target_id = 0
	var best: SimUnit = null
	var best_mult: float = 0.0
	var best_d: int = 0
	for t: SimUnit in units:
		if t.side == u.side or not t.is_alive() or not in_range(u, t):
			continue
		if u.type.weapon.is_area() and _friend_in_blast(u, t.pos):
			continue
		var m: float = u.type.weapon.multiplier(t.type.kind)
		var d: int = (t.pos - u.pos).length_squared()
		# Most effective target first, then the closest; ids break ties.
		if best == null or m > best_mult or (m == best_mult and d < best_d):
			best = t
			best_mult = m
			best_d = d
	if best != null:
		u.target_id = best.id
	return best


## Area weapons do not pick targets on their own when the blast would hit a friend.
func _friend_in_blast(u: SimUnit, impact: Vector2i) -> bool:
	var r: float = float(_splash_subcells(u.type.weapon))
	for v: SimUnit in units:
		if v.side == u.side and float((v.pos - impact).length_squared()) <= r * r:
			return true
	return false


func _splash_subcells(w: Weapon) -> int:
	return roundi(MapScale.meters_to_cells(w.splash_m, map.config.meters_per_cell) * SUBCELL)


func _damage(src: SimUnit, v: SimUnit, amount: float) -> void:
	if not v.is_alive():
		return
	var dealt: float = minf(amount * damage_taken(v), v.hp)
	v.hp -= dealt
	if src.side != v.side:
		return
	var s: int = src.side
	friendly_damage[s] += dealt
	var owed: int = int(friendly_damage[s] / 100.0) * FF_SCORE_PER_100
	if owed > _ff_damage_penalised[s]:
		_penalise(s, owed - _ff_damage_penalised[s])
		_ff_damage_penalised[s] = owed
	if not v.is_alive():
		_penalise(s, v.type.weight * FF_KILL_SCORE_PER_WEIGHT)


func _penalise(side: int, points: int) -> void:
	ff_penalty[side] += points
	score[side] = maxi(0, score[side] - points)


func _remove_dead() -> void:
	var alive: Array[SimUnit] = []
	for u: SimUnit in units:
		if u.is_alive():
			alive.append(u)
		else:
			deaths.append(u)
			_by_id.erase(u.id)
	units = alive
	if deaths.is_empty():
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
