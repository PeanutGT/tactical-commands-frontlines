extends TestCase
## Capturing points of interest (section 6), score (section 11) and what
## holding points gives (supply, deploying near them).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
## One 3×3 point; its centre is (8.5, 2.5).
const ROWS: Array[String] = [
	"p..................",
	"p......yyy.........",
	"p......yyy........e",
	"p......yyy........e",
	"p.................e",
]
const CENTRE: Vector2i = Vector2i(8, 2)


func _sim() -> Simulation:
	return Simulation.new(map_from_rows(ROWS), 9)


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _dummy() -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", UnitType.Kind.INFANTRY, 0.0)
	t.max_hp = 10000.0
	return t


func test_taken_after_five_seconds_alone() -> void:
	var sim: Simulation = _sim()
	sim.spawn(_dummy(), P, CENTRE)
	_run(sim, Simulation.TICK_RATE * 5 - 1)
	check_eq(sim.poi_owner[0], CellGroup.NO_OWNER, "not yet at 4.95 s")
	check_eq(sim.points.taker[0], P, "being taken")
	sim.step()
	check_eq(sim.poi_owner[0], P, "taken at 5 s")
	check_eq(sim.points_held(P), 1, "counts as held")


func test_enemies_on_the_point_pause_the_count() -> void:
	var sim: Simulation = _sim()
	sim.spawn(_dummy(), P, CENTRE)
	_run(sim, Simulation.TICK_RATE * 3)
	var foe: SimUnit = sim.spawn(_dummy(), E, CENTRE + Vector2i(1, 1))
	_run(sim, Simulation.TICK_RATE * 10)
	check_eq(sim.poi_owner[0], CellGroup.NO_OWNER, "contested: nobody takes it")
	check_eq(sim.points.progress[0], Simulation.TICK_RATE * 3, "count paused at 3 s")
	foe.pos = Simulation.cell_center(Vector2i(17, 4))
	_run(sim, Simulation.TICK_RATE * 2)
	check_eq(sim.poi_owner[0], P, "resumes and finishes 2 s later")


func test_leaving_resets_the_count() -> void:
	var sim: Simulation = _sim()
	var u: SimUnit = sim.spawn(_dummy(), P, CENTRE)
	_run(sim, Simulation.TICK_RATE * 3)
	u.pos = Simulation.cell_center(Vector2i(1, 4))
	sim.step()
	check_eq(sim.points.progress[0], 0, "reset once nobody is there")


func test_enemy_point_can_be_taken_over() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[0] = E
	sim.spawn(_dummy(), P, CENTRE + Vector2i(0, 2))
	_run(sim, Simulation.TICK_RATE * 5)
	check_eq(sim.poi_owner[0], P, "3 cells from the centre still counts; flipped in 5 s")


func test_routing_units_do_not_count() -> void:
	var sim: Simulation = _sim()
	var u: SimUnit = sim.spawn(_dummy(), P, CENTRE)
	u.routing = true
	_run(sim, Simulation.TICK_RATE * 6)
	check_eq(sim.poi_owner[0], CellGroup.NO_OWNER, "a routing unit takes nothing")


func test_one_score_per_point_per_second() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[0] = E
	_run(sim, Simulation.TICK_RATE * 10)
	check_eq(sim.score[E], 10, "10 s holding one point")
	check_eq(sim.score[P], 0, "nothing for no points")


func test_held_points_add_supply_and_a_deploy_zone() -> void:
	var sim: Simulation = _sim()
	sim.setup_side(P, [&"infantry", &"tank", &"scout_car", &"apc"] as Array[StringName])
	var before: float = sim.supply_rate(P)
	check(not sim.deploy_cell_ok(P, CENTRE + Vector2i(0, 2), false), "not near an unheld point")
	sim.spawn(_dummy(), P, CENTRE)
	_run(sim, Simulation.TICK_RATE * 5)
	check(absf(sim.supply_rate(P) - (before + Simulation.SUPPLY_PER_POINT)) < 0.02, "+0.15/s for the point")
	check(sim.deploy_cell_ok(P, CENTRE + Vector2i(0, 2), false), "may deploy near it once held")


func test_replay_with_captures_matches() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = _sim()
		var a: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(1, 2))
		var b: SimUnit = sim.spawn(UnitType.infantry(), E, Vector2i(17, 2))
		sim.issue(SimCommand.move(P, PackedInt32Array([a.id]), CENTRE))
		sim.issue(SimCommand.move(E, PackedInt32Array([b.id]), CENTRE))
		_run(sim, Simulation.TICK_RATE * 20)
		hashes.append(sim.state_hash())
	check_eq(hashes[0], hashes[1], "same seed, same orders, same state")
