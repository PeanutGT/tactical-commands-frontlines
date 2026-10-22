extends TestCase

static var _cached: GameMap

var map: GameMap = _load()


static func _load() -> GameMap:
	if _cached == null:
		_cached = MapLoader.load_map("res://maps/hecheng")
	return _cached


func test_size_and_colours() -> void:
	check_eq(Vector2i(map.width, map.height), Vector2i(128, 128), "size")
	check_eq(map.unknown_colors.size(), 0, "unknown colours")
	check_eq(map.config.meters_per_cell, 20.0, "metres per cell")


func test_seven_3x3_pois() -> void:
	check_eq(map.pois.size(), 7, "POI count")
	for p: CellGroup in map.pois:
		check_eq(p.cells.size(), 9, "POI %d size" % p.id)


func test_one_hq_per_side() -> void:
	check_eq(map.hqs.size(), 2, "HQ count")
	var owners: Array[int] = []
	for h: CellGroup in map.hqs:
		owners.append(h.owner)
		check_eq(h.cells.size(), 9, "HQ size")
		if h.owner == GameMap.Side.PLAYER:
			check(h.center.x < 64.0, "player HQ is on the west side")
	owners.sort()
	check_eq(owners, [GameMap.Side.PLAYER, GameMap.Side.ENEMY], "owners")


func test_four_bridges_and_spawns() -> void:
	# POIs on the north and south bridges must not split them in two.
	check_eq(map.bridges.size(), 4, "bridge count")
	check(map.player_spawn != null, "player spawn")
	check(map.enemy_spawn != null, "enemy spawn")


func test_all_heights_no_cliffs() -> void:
	var levels: Dictionary = {}
	var cliffs: int = 0
	for y: int in map.height:
		for x: int in map.width:
			var h: int = map.elevation_at(Vector2i(x, y))
			levels[h] = true
			if x + 1 < map.width and absi(h - map.elevation_at(Vector2i(x + 1, y))) > 1:
				cliffs += 1
			if y + 1 < map.height and absi(h - map.elevation_at(Vector2i(x, y + 1))) > 1:
				cliffs += 1
	check_eq(levels.size(), 4, "height levels used")
	check_eq(cliffs, 0, "cliff edges")
	check_eq(map.elevation_at(Vector2i(91, 104)), 2, "fixed cliff cell (91,104)")
