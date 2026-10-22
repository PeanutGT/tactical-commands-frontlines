class_name Terrain
extends RefCounted
## Terrain types and their rules (design doc section 4.1). Pure data: no scene code.

enum Type { PLAIN, FOREST, ROAD, WATER, BUILDING, POI, ENEMY_SPAWN, PLAYER_SPAWN, HQ, BRIDGE, FORD }

const COUNT: int = 11

## Palette colour per Type, in enum order.
const RGB: Array[Vector3i] = [
	Vector3i(0, 200, 0),
	Vector3i(0, 100, 0),
	Vector3i(128, 128, 128),
	Vector3i(0, 0, 255),
	Vector3i(0, 0, 0),
	Vector3i(255, 255, 0),
	Vector3i(255, 0, 0),
	Vector3i(0, 200, 255),
	Vector3i(255, 0, 255),
	Vector3i(160, 82, 45),
	Vector3i(120, 170, 200),
]

const INFANTRY_OK: Array[bool] = [true, true, true, false, false, true, true, true, false, true, true]
const VEHICLE_OK: Array[bool] = [true, true, true, false, false, true, true, true, false, true, false]
const SPEED_INFANTRY: Array[float] = [1.0, 0.8, 1.3, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.4]
const SPEED_VEHICLE: Array[float] = [1.0, 0.5, 1.3, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0]
const BLOCKS_SIGHT: Array[bool] = [false, true, false, false, true, false, false, false, true, false, false]

## Max RGB distance still considered a match (absorbs JPEG / resampling noise).
const COLOR_TOLERANCE: float = 60.0

## Grey levels of the height PNG (section 4.2).
const HEIGHT_LEVELS: Array[int] = [0, 85, 170, 255]


## Nearest palette colour.
static func nearest(r: int, g: int, b: int) -> int:
	var best: int = Type.PLAIN
	var best_d: int = 1 << 30
	for t: int in COUNT:
		var d: int = _dist2(t, r, g, b)
		if d < best_d:
			best_d = d
			best = t
	return best


## Euclidean RGB distance from (r, g, b) to the palette colour of `type`.
static func color_distance(type: int, r: int, g: int, b: int) -> float:
	return sqrt(float(_dist2(type, r, g, b)))


static func classify_height(grey: int) -> int:
	var best: int = 0
	for i: int in range(1, HEIGHT_LEVELS.size()):
		if absi(grey - HEIGHT_LEVELS[i]) < absi(grey - HEIGHT_LEVELS[best]):
			best = i
	return best


static func _dist2(type: int, r: int, g: int, b: int) -> int:
	var p: Vector3i = RGB[type]
	return (r - p.x) * (r - p.x) + (g - p.y) * (g - p.y) + (b - p.z) * (b - p.z)
