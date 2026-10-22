class_name Simulation
extends RefCounted
## Fixed-rate simulation (section 3): 20 ticks per second, driven only by
## commands, all randomness from a seeded PRNG. No nodes, no engine physics.
## A command issued now runs at the start of the next tick.

const TICK_RATE: int = 20
const TICK_SEC: float = 1.0 / TICK_RATE
## Sub-cell steps per cell for unit positions.
const SUBCELL: int = 1024

var map: GameMap
var rng: SimRng
var tick: int = 0
var units: Array[SimUnit] = []
## Every command in the order it ran; with the seed this replays the match.
var command_log: Array[SimCommand] = []

var _by_id: Dictionary[int, SimUnit] = {}
var _next_id: int = 1
var _pending: Array[SimCommand] = []
var _pathfinder: Pathfinder
## Sub-cells per tick for 1 m/s on this map.
var _subcells_per_tick_per_mps: float = 0.0


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
	u.pos = cell_center(cell)
	u.prev_pos = u.pos
	u.leg_from = cell
	units.append(u)
	_by_id[u.id] = u
	return u


func unit(id: int) -> SimUnit:
	return _by_id.get(id)


func issue(cmd: SimCommand) -> void:
	cmd.tick = tick + 1
	_pending.append(cmd)


func step() -> void:
	tick += 1
	var later: Array[SimCommand] = []
	for cmd: SimCommand in _pending:
		if cmd.tick == tick:
			_run(cmd)
			command_log.append(cmd)
		else:
			later.append(cmd)
	_pending = later
	for u: SimUnit in units:
		_move(u)


## Cells per second `u` covers on plain ground at this map's scale.
func cells_per_sec(u: SimUnit) -> float:
	return MapScale.meters_to_cells(u.type.speed_mps, map.config.meters_per_cell)


func find_path(from: Vector2i, to: Vector2i, vehicle: bool) -> Array[Vector2i]:
	return _pathfinder.find_path(from, to, vehicle)


## Changes whenever any unit's position or orders differ; for replay checks.
func state_hash() -> int:
	var parts: Array = [tick, rng.state]
	for u: SimUnit in units:
		parts.append_array([u.id, u.side, u.pos, u.path_index, u.path])
	return hash(parts)


static func cell_center(cell: Vector2i) -> Vector2i:
	return cell * SUBCELL + Vector2i(SUBCELL / 2, SUBCELL / 2)


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
		SimCommand.Kind.MOVE:
			_run_move(own, cmd.target)


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
		var from: Vector2i = u.cell()
		u.path = _pathfinder.find_path(from, dest, u.type.vehicle)
		u.path_index = 0
		u.leg_from = from


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


func _move(u: SimUnit) -> void:
	u.prev_pos = u.pos
	if not u.is_moving():
		return
	var base: float = u.type.speed_mps * _subcells_per_tick_per_mps
	# Distance left this tick, as a fraction of a full tick at the current speed.
	var time_left: float = 1.0
	while time_left > 0.0 and u.is_moving():
		var next: Vector2i = u.path[u.path_index]
		var speed: float = base * Movement.terrain_speed(map, u.cell(), u.type.vehicle)
		if Movement.uphill(map, u.leg_from, next):
			speed *= Movement.UPHILL_FACTOR
		if speed <= 0.0:
			break
		var target: Vector2i = cell_center(next)
		var d: Vector2 = Vector2(target - u.pos)
		var dist: float = d.length()
		var reach: float = speed * time_left
		if dist <= reach:
			u.pos = target
			time_left -= dist / speed
			u.leg_from = next
			u.path_index += 1
		else:
			u.pos += Vector2i((d * (reach / dist)).round())
			time_left = 0.0
	if not u.is_moving():
		u.clear_path()
