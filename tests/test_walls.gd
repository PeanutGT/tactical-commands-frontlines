extends TestCase
## Buildings block direct fire, and units never end up inside them.

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
const WALL: Array[String] = [
	"...........",
	"...........",
	".....#.....",
	".....#.....",
	".....#.....",
	"...........",
	"...........",
]


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _dummy() -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", UnitType.Kind.INFANTRY, 0.0)
	t.max_hp = 10000.0
	return t


func test_building_blocks_direct_fire() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var rifle: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(3, 3))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(7, 3))
	check(sim.in_range(rifle, t), "in range")
	check(not sim.line_of_fire(rifle, t), "wall in between")
	_run(sim, Simulation.TICK_RATE * 2)
	check_eq(t.hp, t.type.max_hp, "no shots through the wall")
	var open: SimUnit = sim.spawn(_dummy(), E, Vector2i(5, 6))
	check(sim.line_of_fire(rifle, open), "clear line past the wall's end")
	_run(sim, 2)
	check(open.hp < open.type.max_hp, "fires at the target it can see")


func test_standing_next_to_a_building_still_shoots_past_it() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var rifle: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(4, 1))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(4, 5))
	check(sim.line_of_fire(rifle, t), "line runs alongside the wall")


func test_artillery_fires_over_buildings() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var mortar: SimUnit = sim.spawn(UnitType.mortar(), P, Vector2i(1, 3))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(9, 3))
	check(UnitType.mortar().weapon.indirect and UnitType.of(&"spg").weapon.indirect and UnitType.of(&"mrl").weapon.indirect, "artillery is indirect")
	check(not UnitType.tank().weapon.indirect, "tanks fire direct")
	check(sim.line_of_fire(mortar, t), "lobs over")
	_run(sim, 2)
	check(t.hp < t.type.max_hp, "hit behind the wall")


func test_force_attack_behind_a_wall_walks_around_it() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var rifle: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(3, 3))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(7, 3))
	sim.issue(SimCommand.attack(P, PackedInt32Array([rifle.id]), t.id))
	_run(sim, Simulation.TICK_RATE * 6)
	check(t.hp < t.type.max_hp, "got a clear shot after moving")


func test_unit_inside_a_building_gets_out() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(5, 3))
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(9, 3)))
	_run(sim, Simulation.TICK_RATE * 6)
	check(Movement.passable(sim.map, u.cell(), false), "stepped off the building")
	check_eq(u.cell(), Vector2i(9, 3), "and reached its goal")


func test_unit_pushed_off_its_path_never_clips_a_building() -> void:
	var sim: Simulation = Simulation.new(map_from_rows(WALL), 3)
	var u: SimUnit = sim.spawn(UnitType.scout_car(), P, Vector2i(4, 5))
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(6, 0)))
	sim.step()
	# Shoved to the other side of the wall's foot, as unit separation can do over a few ticks.
	u.pos = Vector2i(6 * Simulation.SUBCELL + 100, 5 * Simulation.SUBCELL + 20)
	for i: int in Simulation.TICK_RATE * 8:
		sim.step()
		check(sim.map.terrain_at(u.cell()) != Terrain.Type.BUILDING, "tick %d inside the building at %s" % [i, u.cell()])
		if not u.is_moving():
			break
	check_eq(u.cell(), Vector2i(6, 0), "still arrives")
