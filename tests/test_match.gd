extends TestCase
## HQs, the ways a match ends (section 11), tug-of-war scoring and the
## points each side starts with (pacing decisions in progress.md).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
## Two HQs, two spawn zones, two 3×3 points centred (6.5, 2.5) and (33.5, 2.5).
const ROWS: Array[String] = [
	"hhh..................................hhh",
	"hhh..yyy........................yyy..hhh",
	"hhh..yyy........................yyy..hhh",
	"ppp..yyy........................yyy..eee",
	"ppp..................................eee",
	"ppp..................................eee",
]


func _sim(start_points: int = 0) -> Simulation:
	var map: GameMap = map_from_rows(ROWS)
	map.config.start_points = start_points
	return Simulation.new(map, 4)


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _dummy(hp: float = 10000.0) -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", UnitType.Kind.INFANTRY, 0.0)
	t.max_hp = hp
	return t


func test_each_side_gets_an_hq_building() -> void:
	var sim: Simulation = _sim()
	check(sim.hq[P] != null and sim.hq[E] != null, "both HQs")
	check_eq(sim.hq_hp(P), 2000.0, "2000 health")
	check(sim.hq[P].type.structure and not sim.hq[P].can_move(), "a building that never moves")
	check_eq(sim.field_weight(P), 0, "weighs nothing")
	check(sim.vision.sees(E, sim.hq[P]), "always known to the enemy")
	sim.issue(SimCommand.move(P, PackedInt32Array([sim.hq[P].id]), Vector2i(10, 4)))
	_run(sim, 10)
	check_eq(sim.hq[P].pos, Vector2i(roundi(1.5 * Simulation.SUBCELL), roundi(1.5 * Simulation.SUBCELL)), "takes no orders")


func test_hq_gun_shoots_nearby_enemies() -> void:
	var sim: Simulation = _sim()
	var foe: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 1))
	var far: SimUnit = sim.spawn(_dummy(), E, Vector2i(14, 1))
	sim.step()
	check(absf(foe.type.max_hp - foe.hp - 30.0 * Simulation.DAMAGE_SCALE) < 0.001, "30 × 0.7 at 4.5 cells, lost %f" % (foe.type.max_hp - foe.hp))
	check_eq(far.hp, far.type.max_hp, "12.5 cells is beyond its 8")


func test_units_can_shoot_the_hq() -> void:
	var sim: Simulation = _sim()
	var tank: SimUnit = sim.spawn(UnitType.tank(), E, Vector2i(9, 1))
	tank.hp = 100000.0
	sim.step()
	check(absf(sim.hq_hp(P) - (2000.0 - 50.0 * Simulation.DAMAGE_SCALE)) < 0.001, "tank shell through the HQ's own block, hp %f" % sim.hq_hp(P))


func test_destroying_the_hq_wins() -> void:
	var sim: Simulation = _sim()
	sim.hq[E].hp = 0.0
	sim.step()
	check_eq(sim.winner, P, "player wins")
	check_eq(sim.end_reason, Simulation.End.HQ_DESTROYED, "by HQ")
	var t: int = sim.tick
	sim.step()
	check_eq(sim.tick, t, "nothing runs after the end")


func test_tug_of_war_scoring() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[0] = P
	sim.poi_owner[1] = P
	_run(sim, Simulation.TICK_RATE * 10)
	check_eq(sim.score, [20, 0] as Array[int], "2 points to 0: +2 a second")
	sim.poi_owner[1] = E
	_run(sim, Simulation.TICK_RATE * 10)
	check_eq(sim.score, [20, 0] as Array[int], "level: nobody scores")


func test_first_to_the_goal_wins() -> void:
	var sim: Simulation = _sim()
	sim.map.config.victory_points = 10
	sim.poi_owner[1] = E
	_run(sim, Simulation.TICK_RATE * 10 - 1)
	check_eq(sim.winner, Simulation.NO_WINNER, "9 points")
	sim.step()
	check_eq(sim.winner, E, "10 points wins")
	check_eq(sim.end_reason, Simulation.End.SCORE, "by score")


func test_time_runs_out() -> void:
	var sim: Simulation = _sim()
	sim.map.config.time_limit_sec = 2
	sim.hq[E].hp -= 100.0
	_run(sim, Simulation.TICK_RATE * 2)
	check_eq(sim.winner, P, "level score: more HQ health left wins")
	check_eq(sim.end_reason, Simulation.End.TIME, "by time")
	var level: Simulation = _sim()
	level.map.config.time_limit_sec = 1
	_run(level, Simulation.TICK_RATE)
	check_eq(level.winner, Simulation.DRAW, "all level: draw")
	check_eq(level.time_left_sec(), 0.0, "clock at zero")


func test_sides_start_with_the_points_nearest_home() -> void:
	var sim: Simulation = _sim(1)
	check_eq(sim.poi_owner, [P, E] as Array[int], "one each")
	check_eq(_sim(0).poi_owner, [CellGroup.NO_OWNER, CellGroup.NO_OWNER] as Array[int], "none by default")


func test_held_points_give_sight() -> void:
	var rows: Array[String] = []
	for r: String in ROWS:
		rows.append(r.replace("h", "."))
	var sim: Simulation = Simulation.new(map_from_rows(rows), 4)
	var foe: SimUnit = sim.spawn(_dummy(), E, Vector2i(14, 2))
	sim.step()
	check(not sim.vision.sees(P, foe), "nobody near")
	sim.poi_owner[0] = P
	_run(sim, Simulation.VISION_TICKS)
	check(sim.vision.sees(P, foe), "7.5 cells from a held point, inside its 10")


func test_hecheng_start_points() -> void:
	var sim: Simulation = Simulation.new(MapLoader.load_map("res://maps/hecheng"), 1)
	var mine: Array[float] = []
	for i: int in sim.map.pois.size():
		if sim.poi_owner[i] == P:
			mine.append(sim.map.elevation_at(Vector2i(sim.map.pois[i].center.floor())))
	mine.sort()
	check_eq(mine, [1.0, 3.0] as Array[float], "player: the square (1) and the high ground (3)")
	check_eq(sim.points_held(E), 2, "enemy: two as well")
	check_eq(sim.map.config.weight_cap, 40, "weight cap 40")


func test_starting_points_come_with_infantry() -> void:
	var sim: Simulation = _sim(1)
	var squads: Array[int] = [0, 0]
	for u: SimUnit in sim.units:
		if u.type.id == &"infantry":
			squads[u.side] += 1
			check(Vector2(u.pos).distance_to(sim.map.pois[u.side].center * Simulation.SUBCELL) < Simulation.SUBCELL,
				"squad %d stands on its side's point" % u.id)
			check_eq(u.card, &"", "no card behind it")
	check_eq(squads, [1, 1] as Array[int], "one squad per starting point")
