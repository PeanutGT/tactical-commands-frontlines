class_name Pathfinder
extends RefCounted
## A* over the cell grid for ground units, 8 directions. The cost of a step is
## the time it takes: length × (half the step on each cell ÷ its terrain speed),
## ÷ 0.7 when it climbs a ramp. Cliffs and impassable terrain are walls.

const DIAGONAL: float = 1.4142135623730951
## Fastest terrain (road); dividing the heuristic by it keeps it admissible.
const MAX_TERRAIN_SPEED: float = 1.3
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var _map: GameMap
## Per movement class (0 infantry, 1 vehicle), built on first use: a bit per
## DIRS entry saying whether that step is allowed, and 1 / terrain speed.
var _step_mask: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
var _inv_speed: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]


func _init(map: GameMap) -> void:
	_map = map


## Cells to walk through after `from`, ending at `to`. When `to` cannot be
## reached the path ends at the reachable cell closest to it; empty when the
## unit is already there or cannot move at all.
func find_path(from: Vector2i, to: Vector2i, vehicle: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _map.in_bounds(from) or from == to:
		return result
	var goal: Vector2i = Vector2i(clampi(to.x, 0, _map.width - 1), clampi(to.y, 0, _map.height - 1))
	var n: int = _map.width * _map.height
	var g: PackedFloat64Array = PackedFloat64Array()
	g.resize(n)
	g.fill(INF)
	var came: PackedInt32Array = PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(n)

	var cls: int = 1 if vehicle else 0
	_ensure_tables(cls)
	var mask: PackedByteArray = _step_mask[cls]
	var inv: PackedFloat64Array = _inv_speed[cls]
	var elev: PackedByteArray = _map.elevation
	var w: int = _map.width
	var start: int = _map.index_of(from)
	var goal_i: int = _map.index_of(goal)
	g[start] = 0.0
	var heap: _Heap = _Heap.new()
	heap.push(_heuristic(from, goal), start)
	var best: int = start
	var best_h: float = _heuristic(from, goal)

	while not heap.is_empty():
		var cur: int = heap.pop()
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		if cur == goal_i:
			best = cur
			break
		var cell: Vector2i = Vector2i(cur % w, cur / w)
		var h: float = _heuristic(cell, goal)
		if h < best_h:
			best_h = h
			best = cur
		var bits: int = mask[cur]
		for k: int in DIRS.size():
			if bits & (1 << k) == 0:
				continue
			var d: Vector2i = DIRS[k]
			var ni: int = cur + d.y * w + d.x
			if closed[ni] == 1:
				continue
			var t: float = (DIAGONAL if k >= 4 else 1.0) * 0.5 * (inv[cur] + inv[ni])
			if elev[ni] > elev[cur]:
				t /= Movement.UPHILL_FACTOR
			var cost: float = g[cur] + t
			if cost < g[ni]:
				g[ni] = cost
				came[ni] = cur
				heap.push(cost + _heuristic(cell + d, goal), ni)

	var i: int = best
	while i != start:
		result.append(Vector2i(i % _map.width, i / _map.width))
		i = came[i]
	result.reverse()
	return result


## Time (in plain-cell units) to step between two neighbouring cells.
func step_cost(from: Vector2i, to: Vector2i, vehicle: bool) -> float:
	var length: float = DIAGONAL if from.x != to.x and from.y != to.y else 1.0
	var t: float = length * 0.5 * (1.0 / Movement.terrain_speed(_map, from, vehicle) + 1.0 / Movement.terrain_speed(_map, to, vehicle))
	if Movement.uphill(_map, from, to):
		t /= Movement.UPHILL_FACTOR
	return t


## Total cost of a path as returned by find_path, starting at `from`.
func path_cost(from: Vector2i, path: Array[Vector2i], vehicle: bool) -> float:
	var total: float = 0.0
	var prev: Vector2i = from
	for c: Vector2i in path:
		total += step_cost(prev, c, vehicle)
		prev = c
	return total


## Builds the lookup tables for both movement classes now rather than on the
## first order (about half a second on a 128×128 map).
func prepare() -> void:
	_ensure_tables(0)
	_ensure_tables(1)


## Re-reads the ground around `cells` after it changed (a bridge fell or was
## rebuilt).
func refresh(cells: Array[Vector2i]) -> void:
	for cls: int in 2:
		if _step_mask[cls].is_empty():
			continue
		# Packed arrays are values: change a local copy and put it back.
		var mask: PackedByteArray = _step_mask[cls]
		var inv: PackedFloat64Array = _inv_speed[cls]
		_step_mask[cls] = PackedByteArray()
		_inv_speed[cls] = PackedFloat64Array()
		for c: Vector2i in cells:
			for y: int in range(-1, 2):
				for x: int in range(-1, 2):
					var n: Vector2i = c + Vector2i(x, y)
					if _map.in_bounds(n):
						var i: int = _map.index_of(n)
						inv[i] = _inv_of(n, cls == 1)
						mask[i] = _mask_of(n, cls == 1)
		_step_mask[cls] = mask
		_inv_speed[cls] = inv


func _ensure_tables(cls: int) -> void:
	if not _step_mask[cls].is_empty():
		return
	var vehicle: bool = cls == 1
	var n: int = _map.width * _map.height
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(n)
	var inv: PackedFloat64Array = PackedFloat64Array()
	inv.resize(n)
	for i: int in n:
		var cell: Vector2i = Vector2i(i % _map.width, i / _map.width)
		inv[i] = _inv_of(cell, vehicle)
		mask[i] = _mask_of(cell, vehicle)
	_step_mask[cls] = mask
	_inv_speed[cls] = inv


func _inv_of(cell: Vector2i, vehicle: bool) -> float:
	var speed: float = Movement.terrain_speed(_map, cell, vehicle)
	return 1.0 / speed if speed > 0.0 else INF


## A bit per DIRS entry saying whether that step is allowed.
func _mask_of(cell: Vector2i, vehicle: bool) -> int:
	var bits: int = 0
	for k: int in DIRS.size():
		if Movement.can_step(_map, cell, cell + DIRS[k], vehicle):
			bits |= 1 << k
	return bits


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return (float(maxi(dx, dy) - mini(dx, dy)) + DIAGONAL * float(mini(dx, dy))) / MAX_TERRAIN_SPEED


## Binary min-heap of (priority, cell index); ties go to the lower index so the
## search order, and therefore the path, is deterministic.
class _Heap:
	var _pri: PackedFloat64Array = PackedFloat64Array()
	var _val: PackedInt32Array = PackedInt32Array()

	func is_empty() -> bool:
		return _val.is_empty()

	func push(priority: float, value: int) -> void:
		_pri.append(priority)
		_val.append(value)
		var i: int = _val.size() - 1
		while i > 0:
			var parent: int = (i - 1) / 2
			if not _less(i, parent):
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top: int = _val[0]
		var last: int = _val.size() - 1
		_swap(0, last)
		_pri.resize(last)
		_val.resize(last)
		var i: int = 0
		while true:
			var l: int = 2 * i + 1
			var r: int = l + 1
			var m: int = i
			if l < last and _less(l, m):
				m = l
			if r < last and _less(r, m):
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _less(a: int, b: int) -> bool:
		return _pri[a] < _pri[b] or (_pri[a] == _pri[b] and _val[a] < _val[b])

	func _swap(a: int, b: int) -> void:
		var p: float = _pri[a]
		_pri[a] = _pri[b]
		_pri[b] = p
		var v: int = _val[a]
		_val[a] = _val[b]
		_val[b] = v
