class_name Movement
extends RefCounted
## Ground movement rules shared by the pathfinder and the simulation
## (sections 4.1 and 4.2): passability and speed per terrain, ramps and cliffs.

## Uphill over a ramp (height difference 1) moves at 70%.
const UPHILL_FACTOR: float = 0.7
## A height difference of this much or more is a cliff.
const CLIFF_STEP: int = 2


static func passable(map: GameMap, cell: Vector2i, vehicle: bool) -> bool:
	if not map.in_bounds(cell):
		return false
	var t: int = map.terrain_at(cell)
	return Terrain.VEHICLE_OK[t] if vehicle else Terrain.INFANTRY_OK[t]


## Terrain speed multiplier of `cell` (1.0 = plain).
static func terrain_speed(map: GameMap, cell: Vector2i, vehicle: bool) -> float:
	var t: int = map.terrain_at(cell)
	return Terrain.SPEED_VEHICLE[t] if vehicle else Terrain.SPEED_INFANTRY[t]


## Whether a unit may step from `from` to the neighbouring cell `to`. Diagonal
## steps also need both cells they squeeze between, so units never cut a
## corner of a building or a cliff.
static func can_step(map: GameMap, from: Vector2i, to: Vector2i, vehicle: bool) -> bool:
	if not passable(map, to, vehicle):
		return false
	if absi(map.elevation_at(to) - map.elevation_at(from)) >= CLIFF_STEP:
		return false
	if from.x != to.x and from.y != to.y:
		for side: Vector2i in [Vector2i(to.x, from.y), Vector2i(from.x, to.y)]:
			if not passable(map, side, vehicle):
				return false
			if absi(map.elevation_at(side) - map.elevation_at(from)) >= CLIFF_STEP:
				return false
			if absi(map.elevation_at(side) - map.elevation_at(to)) >= CLIFF_STEP:
				return false
	return true


static func uphill(map: GameMap, from: Vector2i, to: Vector2i) -> bool:
	return map.elevation_at(to) > map.elevation_at(from)


## Most cells a single straight leg may span after smoothing.
const MAX_LEG: int = 12
## Samples per cell when walking a straight leg.
const LEG_SAMPLES: int = 8


## Turns a cell-by-cell path into straight legs so units cut across open
## ground instead of zig-zagging through cell centres. A leg is only used when
## every cell it crosses is a legal step and no slower than the slowest cell
## of the stretch it replaces, so units never shortcut through forest or past
## a cliff.
static func smooth(map: GameMap, from: Vector2i, path: Array[Vector2i], vehicle: bool) -> Array[Vector2i]:
	if path.size() < 2:
		return path
	var out: Array[Vector2i] = []
	var anchor: Vector2i = from
	var anchor_i: int = -1
	var slowest: float = terrain_speed(map, from, vehicle)
	var i: int = 0
	while i < path.size():
		var s: float = minf(slowest, terrain_speed(map, path[i], vehicle))
		if i - anchor_i <= 1 or (i - anchor_i <= MAX_LEG and straight_leg_ok(map, anchor, path[i], vehicle, s)):
			slowest = s
			i += 1
			continue
		anchor = path[i - 1]
		anchor_i = i - 1
		out.append(anchor)
		slowest = minf(terrain_speed(map, anchor, vehicle), terrain_speed(map, path[i], vehicle))
	out.append(path[path.size() - 1])
	return out


## Whether a unit can walk straight from the centre of `a` to the centre of `b`.
static func straight_leg_ok(map: GameMap, a: Vector2i, b: Vector2i, vehicle: bool, min_speed: float) -> bool:
	var start: Vector2 = Vector2(a) + Vector2(0.5, 0.5)
	var d: Vector2 = Vector2(b - a)
	var n: int = int(ceil(d.length() * LEG_SAMPLES))
	var prev: Vector2i = a
	for k: int in range(1, n + 1):
		var c: Vector2i = Vector2i((start + d * (float(k) / n)).floor())
		if c == prev:
			continue
		if not can_step(map, prev, c, vehicle) or terrain_speed(map, c, vehicle) < min_speed:
			return false
		prev = c
	return true
