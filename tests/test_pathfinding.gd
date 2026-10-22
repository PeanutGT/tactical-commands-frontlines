extends TestCase


func _path(map: GameMap, from: Vector2i, to: Vector2i, vehicle: bool = false) -> Array[Vector2i]:
	return Pathfinder.new(map).find_path(from, to, vehicle)


func _check_walkable(map: GameMap, from: Vector2i, path: Array[Vector2i], vehicle: bool, msg: String) -> void:
	var prev: Vector2i = from
	for c: Vector2i in path:
		check(absi(c.x - prev.x) <= 1 and absi(c.y - prev.y) <= 1, "%s: %s -> %s is not a neighbour" % [msg, prev, c])
		check(Movement.can_step(map, prev, c, vehicle), "%s: illegal step %s -> %s" % [msg, prev, c])
		prev = c


func test_straight_line_on_plain() -> void:
	var map: GameMap = map_from_rows([".....", ".....", "....."])
	var p: Array[Vector2i] = _path(map, Vector2i(0, 1), Vector2i(4, 1))
	var expected: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	check_eq(p, expected, "path")


func test_same_cell_is_empty() -> void:
	var map: GameMap = map_from_rows(["..."])
	check(_path(map, Vector2i(1, 0), Vector2i(1, 0)).is_empty(), "no steps")


func test_goes_around_water_and_buildings() -> void:
	var map: GameMap = map_from_rows([
		".....",
		".~~#.",
		".~~#.",
		".....",
	])
	var from: Vector2i = Vector2i(0, 1)
	var p: Array[Vector2i] = _path(map, from, Vector2i(4, 2))
	check_eq(p.back(), Vector2i(4, 2), "reaches goal")
	_check_walkable(map, from, p, false, "around")
	# No corner cutting: over the top, then down the right side.
	check_eq(p.size(), 7, "shortest detour")


func test_no_diagonal_corner_cutting() -> void:
	var map: GameMap = map_from_rows([
		".#",
		"..",
	])
	var p: Array[Vector2i] = _path(map, Vector2i(0, 0), Vector2i(1, 1))
	var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
	check_eq(p, expected, "goes round the corner")


func test_cliff_blocks_ramp_allows() -> void:
	var terrain: Array[String] = [".....", ".....", "....."]
	# The right side is 2 higher than the left: a cliff, except on row 2 where
	# a height-1 cell makes a ramp.
	var heights: Array[String] = [
		"00222",
		"00222",
		"01222",
	]
	var map: GameMap = map_from_rows(terrain, heights)
	check(not Movement.can_step(map, Vector2i(1, 0), Vector2i(2, 0), false), "cliff 0->2 blocked")
	check(Movement.can_step(map, Vector2i(1, 2), Vector2i(2, 2), false), "ramp 1->2 passable")
	var from: Vector2i = Vector2i(0, 0)
	var p: Array[Vector2i] = _path(map, from, Vector2i(4, 0))
	check_eq(p.back(), Vector2i(4, 0), "reaches high ground")
	check(p.has(Vector2i(1, 2)), "uses the ramp")
	_check_walkable(map, from, p, false, "ramp route")


func test_unreachable_goal_stops_at_nearest_cell() -> void:
	var map: GameMap = map_from_rows([
		"..~..",
		"..~..",
	])
	var p: Array[Vector2i] = _path(map, Vector2i(0, 0), Vector2i(4, 0))
	check_eq(p.back(), Vector2i(1, 0), "stops at the bank")


func test_ford_infantry_only() -> void:
	var map: GameMap = map_from_rows([
		"~~~",
		".o.",
		"~~~",
	])
	var foot: Array[Vector2i] = _path(map, Vector2i(0, 1), Vector2i(2, 1), false)
	check_eq(foot.back(), Vector2i(2, 1), "infantry crosses the ford")
	var car: Array[Vector2i] = _path(map, Vector2i(0, 1), Vector2i(2, 1), true)
	check(car.is_empty(), "vehicle cannot move past the ford")


func test_prefers_road_detour() -> void:
	# Straight through the forest is 5 steps at 50% for a vehicle; the road one
	# row up is longer but faster.
	var map: GameMap = map_from_rows([
		"rrrrrr",
		".ffff.",
	])
	var car: Array[Vector2i] = _path(map, Vector2i(0, 1), Vector2i(5, 1), true)
	check(car.has(Vector2i(2, 0)) and car.has(Vector2i(3, 0)), "vehicle takes the road: %s" % [car])


func test_uphill_costs_more_than_downhill() -> void:
	var map: GameMap = map_from_rows(["..."], ["012"])
	var pf: Pathfinder = Pathfinder.new(map)
	check(is_equal_approx(pf.step_cost(Vector2i(0, 0), Vector2i(1, 0), false), 1.0 / 0.7), "uphill step")
	check(is_equal_approx(pf.step_cost(Vector2i(1, 0), Vector2i(0, 0), false), 1.0), "downhill step")


func test_hecheng_crosses_river() -> void:
	var map: GameMap = MapLoader.load_map("res://maps/hecheng")
	for vehicle: bool in [false, true]:
		# Spawn centres are HQ cells, which nobody can stand on.
		var from: Vector2i = passable_near(map, Vector2i(map.player_spawn.center.round()), vehicle)
		var to: Vector2i = passable_near(map, Vector2i(map.enemy_spawn.center.round()), vehicle)
		var p: Array[Vector2i] = _path(map, from, to, vehicle)
		check(not p.is_empty() and p.back() == to, "vehicle=%s reaches the enemy spawn" % vehicle)
		_check_walkable(map, from, p, vehicle, "hecheng vehicle=%s" % vehicle)


func test_smoothing_cuts_open_ground() -> void:
	var map: GameMap = map_from_rows(["......", "......", "......"])
	var from: Vector2i = Vector2i(0, 0)
	var raw: Array[Vector2i] = _path(map, from, Vector2i(5, 2))
	var smooth: Array[Vector2i] = Movement.smooth(map, from, raw, false)
	check_eq(smooth, [Vector2i(5, 2)] as Array[Vector2i], "one straight leg")


func test_smoothing_keeps_out_of_slow_and_blocked_cells() -> void:
	var map: GameMap = map_from_rows([
		".......",
		".##ff..",
		".......",
	])
	var from: Vector2i = Vector2i(0, 0)
	var raw: Array[Vector2i] = _path(map, from, Vector2i(6, 2))
	var smooth: Array[Vector2i] = Movement.smooth(map, from, raw, true)
	check_eq(smooth.back(), Vector2i(6, 2), "same goal")
	var prev: Vector2i = from
	for c: Vector2i in smooth:
		check(Movement.straight_leg_ok(map, prev, c, true, 1.0), "leg %s -> %s crosses a building or forest" % [prev, c])
		prev = c
