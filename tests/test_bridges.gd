extends TestCase
## Destructible bridges (section 4.4).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
## A river across the middle with one short bridge (x 5..6, y 3..5).
const ROWS: Array[String] = [
	"pppp........",
	"............",
	"............",
	"~~~~~bb~~~~~",
	"~~~~~bb~~~~~",
	"~~~~~bb~~~~~",
	"............",
	"............",
	"........eeee",
]


func _sim() -> Simulation:
	var map: GameMap = map_from_rows(ROWS)
	map.config.supply_cap = 20
	return Simulation.new(map, 8)


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _tough_infantry() -> UnitType:
	var t: UnitType = UnitType.of(&"infantry")
	t.max_hp = 1000.0
	return t


func test_bridge_durability_by_size() -> void:
	var sim: Simulation = _sim()
	check_eq(sim.bridges.max_hp, [Bridges.SMALL_HP] as Array[float], "6 cells: a short bridge")
	var hecheng: Bridges = Bridges.new(MapLoader.load_map("res://maps/hecheng"))
	var big: int = 0
	for h: float in hecheng.max_hp:
		if h == Bridges.BIG_HP:
			big += 1
	check_eq(big, 2, "河城: north and south bridges are big")


func test_damaged_bridge_slows_vehicles() -> void:
	var sim: Simulation = _sim()
	check(not sim.bridges.slows(Vector2i(5, 4)), "intact")
	sim.damage_bridge(0, 301.0)
	check(sim.bridges.slows(Vector2i(5, 4)), "under half")


func test_broken_bridge_drops_what_is_on_it() -> void:
	var sim: Simulation = _sim()
	var tank: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(5, 4))
	var squad: SimUnit = sim.spawn(_tough_infantry(), P, Vector2i(6, 4))
	var path_before: Array[Vector2i] = sim.find_path(Vector2i(5, 1), Vector2i(5, 7), true)
	check_eq(path_before.back(), Vector2i(5, 7), "vehicles cross while it stands")
	sim.damage_bridge(0, Bridges.SMALL_HP)
	check(sim.bridges.broken[0], "down")
	check_eq(sim.map.terrain_at(Vector2i(5, 4)), Terrain.Type.WATER, "water now")
	sim.step()
	check(sim.unit(tank.id) == null, "the tank went in")
	check_eq(squad.hp, 1000.0 - Bridges.FALL_DAMAGE, "infantry takes 200")
	check(Movement.passable(sim.map, squad.cell(), false), "and is washed ashore at %s" % squad.cell())
	var path: Array[Vector2i] = sim.find_path(Vector2i(5, 1), Vector2i(5, 7), true)
	check(path.is_empty() or path.back().y < 3, "no way across any more")


func test_artillery_wears_a_bridge_down() -> void:
	var sim: Simulation = _sim()
	sim.spawn(UnitType.scout_car(), P, Vector2i(2, 1))
	var s: SideState = sim.sides[P]
	s.hand = [&"artillery"] as Array[StringName]
	s.supply = 10.0
	sim.bridges.hp[0] = 50.0
	sim.step()
	sim.issue(SimCommand.deploy(P, 0, &"artillery", Vector2i(5, 4)))
	_run(sim, roundi(Support.ARTILLERY_DELAY_SEC * Simulation.TICK_RATE) + 1)
	check(sim.bridges.broken[0], "84 damage took the last 50")


func test_engineers_blow_a_bridge() -> void:
	var sim: Simulation = _sim()
	var eng: SimUnit = sim.spawn(UnitType.of(&"engineer"), P, Vector2i(5, 4))
	sim.issue(SimCommand.engineer(P, PackedInt32Array([eng.id])))
	sim.step()
	check_eq(eng.work, SimUnit.Work.DEMOLISH, "planting")
	_run(sim, Bridges.PLANT_TICKS)
	check_eq(eng.work, SimUnit.Work.NONE, "charge set")
	check_eq(sim.bridges.fuses.size(), 1, "fuse burning")
	sim.issue(SimCommand.move(P, PackedInt32Array([eng.id]), Vector2i(5, 0)))
	_run(sim, Bridges.FUSE_TICKS - 2)
	check(not sim.bridges.broken[0], "not yet")
	_run(sim, 2)
	check(sim.bridges.broken[0], "5 s later it goes")
	check(sim.unit(eng.id) != null and eng.cell().y < 3, "the engineers got off in time")


func test_getting_hit_stops_the_planting() -> void:
	var sim: Simulation = _sim()
	var eng: SimUnit = sim.spawn(UnitType.of(&"engineer"), P, Vector2i(5, 4))
	sim.issue(SimCommand.engineer(P, PackedInt32Array([eng.id])))
	_run(sim, 40)
	sim.support_strike(E, eng, 1.0, 1, 5.0, false, Vector2i.ZERO)
	sim.step()
	check_eq(eng.work, SimUnit.Work.NONE, "called off")
	_run(sim, Bridges.PLANT_TICKS + Bridges.FUSE_TICKS)
	check(not sim.bridges.broken[0], "still standing")


func test_engineers_rebuild_a_broken_bridge() -> void:
	var sim: Simulation = _sim()
	sim.damage_bridge(0, Bridges.SMALL_HP)
	var eng: SimUnit = sim.spawn(UnitType.of(&"engineer"), P, Vector2i(5, 2))
	var s: SideState = sim.sides[P]
	s.supply = 2.0
	sim.issue(SimCommand.engineer(P, PackedInt32Array([eng.id])))
	sim.step()
	check_eq(eng.work, SimUnit.Work.NONE, "not enough supply")
	s.supply = 5.0
	sim.issue(SimCommand.engineer(P, PackedInt32Array([eng.id])))
	sim.step()
	check_eq(eng.work, SimUnit.Work.REPAIR, "repairing")
	check(absf(s.supply - 2.0) < 0.01, "3 supply paid")
	_run(sim, Bridges.REPAIR_TICKS)
	check(not sim.bridges.broken[0], "back up")
	check_eq(sim.bridges.hp[0], Bridges.SMALL_HP * Bridges.REPAIR_SHARE, "at 30%")
	check_eq(sim.map.terrain_at(Vector2i(5, 4)), Terrain.Type.BRIDGE, "bridge deck again")
	check_eq(sim.find_path(Vector2i(5, 1), Vector2i(5, 7), true).back(), Vector2i(5, 7), "vehicles cross again")


func test_moving_off_refunds_an_unfinished_repair() -> void:
	var sim: Simulation = _sim()
	sim.damage_bridge(0, Bridges.SMALL_HP)
	var eng: SimUnit = sim.spawn(UnitType.of(&"engineer"), P, Vector2i(5, 2))
	sim.sides[P].supply = 5.0
	sim.issue(SimCommand.engineer(P, PackedInt32Array([eng.id])))
	sim.step()
	var paid: float = sim.sides[P].supply
	sim.issue(SimCommand.move(P, PackedInt32Array([eng.id]), Vector2i(1, 1)))
	sim.step()
	check_eq(eng.work, SimUnit.Work.NONE, "stopped")
	check(sim.sides[P].supply > paid + 2.9, "3 back")
