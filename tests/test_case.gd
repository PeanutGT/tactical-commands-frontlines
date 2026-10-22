class_name TestCase
extends RefCounted
## Minimal test base: every method named test_* is run by tests/run_tests.gd.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


## RGBA8 pixels from rows of palette keys, e.g. ["gx"] with {"g": Vector3i(0, 200, 0), ...}.
static func rgba_from_rows(rows: Array[String], palette: Dictionary) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for row: String in rows:
		for ch: String in row:
			var c: Vector3i = palette[ch]
			out.append_array(PackedByteArray([c.x, c.y, c.z, 255]))
	return out


## Small map for sim tests. Terrain keys: . plain, f forest, r road, ~ water,
## # building, b bridge, o ford. Height rows use digits 0..3 (empty = flat).
static func map_from_rows(terrain_rows: Array[String], height_rows: Array[String] = [], meters_per_cell: float = 20.0) -> GameMap:
	var keys: Dictionary = {
		".": Terrain.RGB[Terrain.Type.PLAIN], "f": Terrain.RGB[Terrain.Type.FOREST],
		"r": Terrain.RGB[Terrain.Type.ROAD], "~": Terrain.RGB[Terrain.Type.WATER],
		"#": Terrain.RGB[Terrain.Type.BUILDING], "b": Terrain.RGB[Terrain.Type.BRIDGE],
		"o": Terrain.RGB[Terrain.Type.FORD],
	}
	var w: int = terrain_rows[0].length()
	var h: int = terrain_rows.size()
	var config: MapConfig = MapConfig.new()
	config.id = "test"
	config.size = Vector2i(w, h)
	config.meters_per_cell = meters_per_cell
	var heights: PackedByteArray = PackedByteArray()
	for row: String in height_rows:
		for ch: String in row:
			var g: int = Terrain.HEIGHT_LEVELS[int(ch)]
			heights.append_array(PackedByteArray([g, g, g, 255]))
	return GameMap.build(config, rgba_from_rows(terrain_rows, keys), w, h, heights)


## Nearest cell to `cell` a unit of that movement class can stand on.
static func passable_near(map: GameMap, cell: Vector2i, vehicle: bool) -> Vector2i:
	for off: Vector2i in Simulation.slot_offsets(64):
		if Movement.passable(map, cell + off, vehicle):
			return cell + off
	return cell
