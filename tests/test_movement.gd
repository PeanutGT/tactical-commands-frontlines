extends TestCase

const SUB: float = Simulation.SUBCELL


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


## Cells travelled along x since spawning at the centre of `start`.
func _moved_x(u: SimUnit, start: Vector2i) -> float:
	return float(u.pos.x - Simulation.cell_center(start).x) / SUB


## One player unit at (0, 0) ordered to the right end of row 0.
func _one_unit(rows: Array[String], type: UnitType, heights: Array[String] = [], mpc: float = 20.0) -> Simulation:
	var sim: Simulation = Simulation.new(map_from_rows(rows, heights, mpc), 7)
	sim.spawn(type, GameMap.Side.PLAYER, Vector2i(0, 0))
	sim.issue(SimCommand.move(GameMap.Side.PLAYER, PackedInt32Array([1]), Vector2i(rows[0].length() - 1, 0)))
	return sim


func _check_moved(sim: Simulation, expected: float, msg: String) -> void:
	var got: float = _moved_x(sim.unit(1), Vector2i(0, 0))
	check(absf(got - expected) < 0.01, "%s: expected %f cells, got %f" % [msg, expected, got])


func test_command_runs_on_next_tick() -> void:
	var sim: Simulation = _one_unit(["........"], UnitType.infantry())
	check(not sim.unit(1).is_moving(), "not moving before the tick")
	sim.step()
	check_eq(sim.tick, 1, "tick")
	check(sim.unit(1).is_moving(), "moving after the tick")
	check_eq(sim.command_log.size(), 1, "logged")


func test_infantry_speed_on_plain() -> void:
	var sim: Simulation = _one_unit(["............"], UnitType.infantry())
	_run(sim, Simulation.TICK_RATE)
	_check_moved(sim, 1.5, "1 s on plain")


func test_speed_scales_with_map() -> void:
	var sim: Simulation = _one_unit(["............"], UnitType.infantry(), [], 10.0)
	_run(sim, Simulation.TICK_RATE)
	_check_moved(sim, 3.0, "10 m/cell map")


func test_road_is_faster() -> void:
	var sim: Simulation = _one_unit(["rrrrrrrrrrrr"], UnitType.infantry())
	_run(sim, Simulation.TICK_RATE)
	_check_moved(sim, 1.95, "road 130%")


func test_vehicle_slow_in_forest() -> void:
	var sim: Simulation = _one_unit(["ffffffffffff"], UnitType.tank())
	_run(sim, Simulation.TICK_RATE)
	_check_moved(sim, 1.0, "tank in forest 50%")


func test_uphill_is_slower() -> void:
	# Each step climbs one level, so the first legs are all uphill.
	var flat: Simulation = _one_unit(["...."], UnitType.infantry())
	var hill: Simulation = _one_unit(["...."], UnitType.infantry(), ["0123"])
	_run(flat, 10)
	_run(hill, 10)
	var f: float = _moved_x(flat.unit(1), Vector2i(0, 0))
	var h: float = _moved_x(hill.unit(1), Vector2i(0, 0))
	check(absf(h - f * 0.7) < 0.01, "uphill 70%%: flat %f hill %f" % [f, h])


func test_arrives_and_stops() -> void:
	var sim: Simulation = _one_unit(["....."], UnitType.scout_car())
	_run(sim, 40)
	var u: SimUnit = sim.unit(1)
	check_eq(u.pos, Simulation.cell_center(Vector2i(4, 0)), "at destination centre")
	check(not u.is_moving(), "idle")
	check_eq(u.prev_pos, u.pos, "no interpolation drift when idle")


func test_stop_command() -> void:
	var sim: Simulation = _one_unit(["............"], UnitType.infantry())
	_run(sim, 5)
	sim.issue(SimCommand.stop(GameMap.Side.PLAYER, PackedInt32Array([1])))
	sim.step()
	var at: Vector2i = sim.unit(1).pos
	_run(sim, 10)
	check(not sim.unit(1).is_moving(), "stopped")
	check_eq(sim.unit(1).pos, at, "stays put")


func test_enemy_command_cannot_move_our_unit() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(["....."]), 1)
	sim.spawn(UnitType.infantry(), GameMap.Side.PLAYER, Vector2i(0, 0))
	sim.issue(SimCommand.move(GameMap.Side.ENEMY, PackedInt32Array([1]), Vector2i(4, 0)))
	_run(sim, 5)
	check(not sim.unit(1).is_moving(), "ignored")


func test_group_gets_distinct_destinations() -> void:
	var rows: Array[String] = [
		"..........",
		"..........",
		"..........",
		"..........",
		"..........",
	]
	var sim: Simulation = Simulation.new(map_from_rows(rows), 1)
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in 6:
		ids.append(sim.spawn(UnitType.infantry(), GameMap.Side.PLAYER, Vector2i(i / 5, i % 5)).id)
	sim.issue(SimCommand.move(GameMap.Side.PLAYER, ids, Vector2i(7, 2)))
	_run(sim, 200)
	var seen: Dictionary[Vector2i, bool] = {}
	for u: SimUnit in sim.units:
		check(not u.is_moving(), "unit %d arrived" % u.id)
		check(not seen.has(u.cell()), "unit %d shares cell %s" % [u.id, u.cell()])
		seen[u.cell()] = true
		check(Vector2(u.cell()).distance_to(Vector2(7, 2)) <= 2.0, "unit %d near the target" % u.id)


func test_same_seed_and_commands_replay_identically() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = Simulation.new(MapLoader.load_map("res://maps/hecheng"), 42)
		var start: Vector2i = passable_near(sim.map, Vector2i(sim.map.player_spawn.center.round()) + Vector2i(4, 0), true)
		var ids: PackedInt32Array = PackedInt32Array()
		var types: Array[UnitType] = [UnitType.infantry(), UnitType.tank(), UnitType.scout_car()]
		for i: int in types.size():
			ids.append(sim.spawn(types[i], GameMap.Side.PLAYER, start + Vector2i(i, 0)).id)
		sim.issue(SimCommand.move(GameMap.Side.PLAYER, ids, Vector2i(64, 64)))
		_run(sim, 60)
		sim.issue(SimCommand.move(GameMap.Side.PLAYER, PackedInt32Array([ids[0]]), Vector2i(sim.map.enemy_spawn.center.round())))
		_run(sim, 60)
		check(sim.unit(ids[0]).cell() != start, "run %d: units moved" % run)
		hashes.append(sim.state_hash())
	check_eq(hashes[0], hashes[1], "replay hash")


func test_rng_is_seeded() -> void:
	var a: SimRng = SimRng.new(123)
	var b: SimRng = SimRng.new(123)
	var c: SimRng = SimRng.new(124)
	var sa: Array[int] = []
	var sb: Array[int] = []
	var sc: Array[int] = []
	for i: int in 5:
		sa.append(a.next_u32())
		sb.append(b.next_u32())
		sc.append(c.next_u32())
	check_eq(sa, sb, "same seed")
	check(sa != sc, "different seed")
	for i: int in 100:
		var f: float = a.next_float()
		check(f >= 0.0 and f < 1.0, "float range")
		check(a.next_int(6) < 6, "int range")
