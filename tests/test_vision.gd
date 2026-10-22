extends TestCase
## Section 10 fog of war and section 4.2 sight rules.

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
const OPEN: Array[String] = [
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
]


func _sim(rows: Array[String], heights: Array[String] = []) -> Simulation:
	return Simulation.new(map_from_rows(rows, heights), 5)


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _dummy() -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", UnitType.Kind.INFANTRY, 0.0)
	t.max_hp = 10000.0
	return t


func _seen(sim: Simulation, viewer_side: int, t: SimUnit) -> bool:
	return sim.vision.sees(viewer_side, t)


func test_three_fog_states() -> void:
	var sim: Simulation = _sim(OPEN)
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(1, 2))
	check_eq(sim.vision.fog_at(P, Vector2i(14, 2)), Vision.Fog.UNEXPLORED, "far cell unexplored before any tick")
	sim.step()
	check_eq(sim.vision.fog_at(P, Vector2i(5, 2)), Vision.Fog.VISIBLE, "4 cells away in sight")
	check_eq(sim.vision.fog_at(P, Vector2i(14, 2)), Vision.Fog.UNEXPLORED, "13 cells away beyond 7-cell sight")
	check_eq(sim.vision.fog_at(E, Vector2i(1, 2)), Vision.Fog.UNEXPLORED, "the other side sees nothing")
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(13, 2)))
	_run(sim, Simulation.TICK_RATE * 12)
	check_eq(u.cell(), Vector2i(13, 2), "walked across")
	check_eq(sim.vision.fog_at(P, Vector2i(1, 2)), Vision.Fog.EXPLORED, "left behind: explored")
	check_eq(sim.vision.fog_at(P, Vector2i(14, 2)), Vision.Fog.VISIBLE, "now in sight")


func test_buildings_block_sight() -> void:
	_check_blocks(["...#......", "...#......", "..........", "..........", ".........."], "building")


func test_forest_blocks_sight() -> void:
	_check_blocks(["...f......", "...f......", "..........", "..........", ".........."], "forest")


func _check_blocks(rows: Array[String], what: String) -> void:
	var sim: Simulation = _sim(rows)
	sim.spawn(UnitType.infantry(), P, Vector2i(1, 1))
	var behind: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 1))
	var open: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 4))
	sim.step()
	check(sim.vision.cell_visible(P, Vector2i(3, 1)), "the %s itself is seen" % what)
	check(not sim.vision.cell_visible(P, Vector2i(5, 1)), "cell behind the %s hidden" % what)
	check(not _seen(sim, P, behind), "unit behind the %s unseen" % what)
	check(_seen(sim, P, open), "unit past its end seen")


func test_ridge_blocks_sight() -> void:
	var rows: Array[String] = ["..........", ".........."]
	var sim: Simulation = _sim(rows, ["0003000000", "0003000330"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 1))
	sim.step()
	check(sim.vision.cell_visible(P, Vector2i(3, 0)), "the ridge top is seen")
	check(not sim.vision.cell_visible(P, Vector2i(5, 0)), "low ground behind the ridge hidden")
	check(sim.vision.cell_visible(P, Vector2i(7, 1)), "ground as high as the ridge behind it is seen")


func test_height_adds_two_cells_of_sight_per_level() -> void:
	var rows: Array[String] = ["...............", "..............."]
	var sim: Simulation = _sim(rows, ["100000000000000", "000000000000000"])
	var high: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	check_eq(sim.vision.sight_cells(high), 9.0, "7 + 2 on level 1")
	sim.step()
	check(sim.vision.cell_visible(P, Vector2i(9, 0)), "9 cells out from level 1")
	check(not sim.vision.cell_visible(P, Vector2i(10, 0)), "but not 10")


func test_high_ground_hides_units_until_close() -> void:
	var rows: Array[String] = ["..........", ".........."]
	var sim: Simulation = _sim(rows, ["0000002222", "0000002222"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var far: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 0))
	sim.step()
	check(sim.vision.cell_visible(P, Vector2i(6, 0)), "the high cell itself is in view")
	check(not _seen(sim, P, far), "two levels up and 6 cells away: hidden")
	sim.spawn(UnitType.infantry(), P, Vector2i(3, 1))
	sim.step()
	check(_seen(sim, P, far), "4 cells or closer: seen")


func test_units_in_forest_are_seen_only_within_three_cells() -> void:
	var sim: Simulation = _sim(["..........", ".......fff", "......f.f."])
	sim.spawn(UnitType.infantry(), P, Vector2i(1, 1))
	var hidden: SimUnit = sim.spawn(_dummy(), E, Vector2i(7, 1))
	sim.step()
	check(sim.vision.cell_visible(P, Vector2i(7, 1)), "forest edge in view")
	check(not _seen(sim, P, hidden), "but the unit in it is hidden 6 cells away")
	var scout: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(4, 1))
	sim.step()
	check(_seen(sim, P, hidden), "3 cells away: spotted")
	scout.pos = Simulation.cell_center(Vector2i(3, 0))
	_run(sim, Simulation.VISION_TICKS)
	check(not _seen(sim, P, hidden), "4 cells away again: lost")


func test_sight_updates_every_four_ticks() -> void:
	var sim: Simulation = _sim(OPEN)
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 2))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(12, 2))
	sim.step()
	check(not _seen(sim, P, t), "12 cells out")
	t.pos = Simulation.cell_center(Vector2i(5, 2))
	sim.step()
	sim.step()
	check(not _seen(sim, P, t), "not before the next sight pass")
	_run(sim, 2)
	check(_seen(sim, P, t), "seen after the pass on tick 5")


func test_only_visible_targets_are_shot() -> void:
	var sim: Simulation = _sim(["..........", "......f...", "......f..."])
	var rifle: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(2, 1))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 1))
	_run(sim, Simulation.TICK_RATE * 2)
	check(sim.can_hit(rifle, t), "in range with a clear line into the forest edge")
	check_eq(t.hp, t.type.max_hp, "but hidden in the forest, so no shots")
	rifle.pos = Simulation.cell_center(Vector2i(3, 1))
	_run(sim, Simulation.TICK_RATE)
	check(t.hp < t.type.max_hp, "3 cells away it is spotted and shot")


func test_artillery_needs_a_spotter() -> void:
	var sim: Simulation = _sim(["...................."])
	sim.spawn(UnitType.mortar(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(10, 0))
	_run(sim, Simulation.TICK_RATE * 2)
	check_eq(t.hp, t.type.max_hp, "10 cells: in mortar range, beyond its 6-cell sight")
	sim.spawn(UnitType.scout_car(), P, Vector2i(4, 0))
	_run(sim, Simulation.TICK_RATE * 2)
	check(t.hp < t.type.max_hp, "a scout car's sight lets it fire")


func test_forest_blocks_direct_fire() -> void:
	var sim: Simulation = _sim(["........", "...f....", "........", "........"])
	var tank: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(1, 1))
	var through: SimUnit = sim.spawn(_dummy(), E, Vector2i(5, 1))
	var past: SimUnit = sim.spawn(_dummy(), E, Vector2i(5, 3))
	check(not sim.line_of_fire(tank, through), "through the forest")
	check(sim.line_of_fire(tank, past), "past it")
