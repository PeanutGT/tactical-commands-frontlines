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
