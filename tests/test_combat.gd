extends TestCase

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _sim(rows: Array[String], heights: Array[String] = [], mpc: float = 20.0) -> Simulation:
	return Simulation.new(map_from_rows(rows, heights, mpc), 3)


## Unarmed target with lots of health, so it neither dies nor shoots back.
func _dummy(kind: UnitType.Kind = UnitType.Kind.INFANTRY, hp: float = 10000.0) -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", kind, 0.0)
	t.max_hp = hp
	return t


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _lost(u: SimUnit) -> float:
	return u.type.max_hp - u.hp


func test_idle_unit_shoots_enemy_in_range() -> void:
	var sim: Simulation = _sim(["............"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(5, 0))
	sim.step()
	check(_near(_lost(t), 10.0), "rifle hits for 10, lost %f" % _lost(t))
	_run(sim, Simulation.TICK_RATE)
	check(_near(_lost(t), 20.0), "one more shot after the 1 s cooldown, lost %f" % _lost(t))


func test_out_of_range_is_ignored() -> void:
	var sim: Simulation = _sim(["............"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 0))
	_run(sim, 5)
	check_eq(_lost(t), 0.0, "6 cells is beyond 5")


func test_range_scales_with_map() -> void:
	# 100 m of range is 10 cells on a 10 m/cell map.
	var sim: Simulation = _sim(["............"], [], 10.0)
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(10, 0))
	sim.step()
	check(_near(_lost(t), 10.0), "hit at 10 cells")


func test_no_friendly_auto_target() -> void:
	var sim: Simulation = _sim(["......"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var f: SimUnit = sim.spawn(_dummy(), P, Vector2i(3, 0))
	_run(sim, 5)
	check_eq(_lost(f), 0.0, "friend untouched")


func test_tank_gun_hits_infantry_in_full() -> void:
	# No class multipliers any more: unarmoured targets take full damage.
	var sim: Simulation = _sim(["......"])
	sim.spawn(UnitType.tank(), P, Vector2i(0, 0))
	var inf: SimUnit = sim.spawn(_dummy(UnitType.Kind.INFANTRY), E, Vector2i(4, 0))
	sim.step()
	check(_near(_lost(inf), 50.0), "tank vs infantry, lost %f" % _lost(inf))


func test_high_ground_damage_and_range() -> void:
	var sim: Simulation = _sim([".........."], ["1000000000"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(6, 0))
	sim.step()
	check(_near(_lost(t), 11.5), "+15%% damage and reaches 6 cells, lost %f" % _lost(t))


func test_low_ground_damage() -> void:
	var sim: Simulation = _sim(["......"], ["000001"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(5, 0))
	sim.step()
	check(_near(_lost(t), 8.5), "-15%% shooting uphill, lost %f" % _lost(t))
	check(_near(sim.range_cells(sim.unit(1), t), 5.0), "no range bonus uphill")


func test_hold_position_timing() -> void:
	var sim: Simulation = _sim([".........."])
	var u: SimUnit = sim.spawn(_dummy(), P, Vector2i(0, 0))
	sim.issue(SimCommand.hold(P, PackedInt32Array([u.id])))
	_run(sim, 80)
	check_eq(u.hold, SimUnit.Hold.ENTERING, "still digging in just before 4 s")
	sim.step()
	check_eq(u.hold, SimUnit.Hold.HELD, "held after 4 s")
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(9, 0)))
	sim.step()
	check_eq(u.hold, SimUnit.Hold.LEAVING, "move order starts leaving")
	_run(sim, 39)
	check(not u.is_moving() and u.pos == Simulation.cell_center(Vector2i(0, 0)), "does not move while leaving")
	sim.step()
	check_eq(u.hold, SimUnit.Hold.NONE, "left after 2 s")
	check(u.is_moving(), "then runs the move order")


func test_vehicles_cannot_hold() -> void:
	var sim: Simulation = _sim(["...."])
	var u: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(0, 0))
	sim.issue(SimCommand.hold(P, PackedInt32Array([u.id])))
	sim.step()
	check_eq(u.hold, SimUnit.Hold.NONE, "tank ignores hold")


func test_held_unit_takes_less_damage_and_shoots_further() -> void:
	var sim: Simulation = _sim(["..........", "f........."])
	var open: SimUnit = sim.spawn(_dummy(), P, Vector2i(0, 0))
	var wood: SimUnit = sim.spawn(_dummy(), P, Vector2i(0, 1))
	var shooter: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(9, 0))
	open.hold = SimUnit.Hold.HELD
	wood.hold = SimUnit.Hold.HELD
	check(_near(sim.damage_taken(open), 0.6), "-40%% held")
	check(_near(sim.damage_taken(wood), 0.48), "a further -20%% in forest")
	shooter.hold = SimUnit.Hold.HELD
	check(_near(sim.range_cells(shooter, open), 5.5), "+10%% range held")


func test_force_attack_chases_and_kills() -> void:
	var sim: Simulation = _sim(["...................."])
	var u: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 100.0), E, Vector2i(15, 0))
	sim.issue(SimCommand.attack(P, PackedInt32Array([u.id]), t.id))
	sim.step()
	check(u.is_moving(), "drives towards an out-of-range target")
	var died: bool = false
	for i: int in 400:
		sim.step()
		if sim.unit(t.id) == null:
			died = true
			check(sim.deaths.has(t), "reported as a death")
			break
	check(died, "target destroyed")
	check(not sim.units.has(t), "removed from the unit list")
	check(not u.forced_target and u.target_id == 0, "order cleared after the kill")
	check(u.cell().x <= 7, "stopped once in range, at %s" % u.cell())


func test_move_order_beats_auto_attack() -> void:
	var sim: Simulation = _sim(["............"])
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(3, 0))
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(0, 0) + Vector2i(11, 0)))
	_run(sim, 10)
	check_eq(_lost(t), 0.0, "moving units hold fire")


func test_area_weapon_friendly_fire_and_penalty() -> void:
	var sim: Simulation = _sim(["..........", ".........."])
	var m: SimUnit = sim.spawn(UnitType.mortar(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR), E, Vector2i(8, 0))
	var f: SimUnit = sim.spawn(_dummy(UnitType.Kind.INFANTRY, 100.0), P, Vector2i(8, 1))
	f.type.weight = 2
	sim.score[P] = 100
	_run(sim, 3)
	check_eq(sim.shots.size() + _lost(t), 0.0, "mortar will not auto-fire with a friend in the blast")
	sim.issue(SimCommand.attack(P, PackedInt32Array([m.id]), t.id))
	sim.step()
	check(_near(_lost(t), 40.0), "unarmoured dummy takes the full 40, lost %f" % _lost(t))
	check(_near(_lost(f), 40.0), "friend in the blast hit too, lost %f" % _lost(f))
	check_eq(sim.score[P], 100, "no penalty under 100 damage")
	_run(sim, 80)
	check(_near(sim.friendly_damage[P], 80.0), "two shots of friendly damage")
	_run(sim, 80)
	check(sim.unit(f.id) == null, "friend killed by the third shot")
	# 100 friendly damage: −5; killing a weight-2 friend: −10.
	check_eq(sim.ff_penalty[P], 15, "penalty")
	check_eq(sim.score[P], 85, "score")


func test_score_never_below_zero() -> void:
	var sim: Simulation = _sim([".........."])
	var m: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var f: SimUnit = sim.spawn(_dummy(UnitType.Kind.INFANTRY, 10.0), P, Vector2i(3, 0))
	f.type.weight = 4
	sim.issue(SimCommand.attack(P, PackedInt32Array([m.id]), f.id))
	sim.step()
	check(sim.unit(f.id) == null, "force-attacked friend killed")
	check_eq(sim.ff_penalty[P], 20, "kill penalty weight × 5")
	check_eq(sim.score[P], 0, "clamped at 0")


func test_units_on_one_spot_are_pushed_apart() -> void:
	var sim: Simulation = _sim([".....", ".....", "....."])
	var a: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(2, 1))
	var b: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(2, 1))
	_run(sim, 3)
	var d: float = Vector2(b.pos - a.pos).length() / Simulation.SUBCELL
	check(d >= 0.59, "at least two infantry radii apart, got %f" % d)


func test_held_unit_is_not_pushed() -> void:
	var sim: Simulation = _sim([".....", ".....", "....."])
	var a: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(2, 1))
	a.hold = SimUnit.Hold.HELD
	var start: Vector2i = a.pos
	var b: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(2, 1))
	_run(sim, 3)
	check_eq(a.pos, start, "held unit stays")
	check(b.pos != start, "the other unit moved aside")


func test_push_respects_walls() -> void:
	var sim: Simulation = _sim(["~.~"])
	var a: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(1, 0))
	var b: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(1, 0))
	_run(sim, 5)
	check_eq(a.cell(), Vector2i(1, 0), "a stays on land")
	check_eq(b.cell(), Vector2i(1, 0), "b stays on land")


func test_combat_replays_identically() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = _sim(["....................", "....ff..............", "....................", "...................."], ["00000000001111111111", "00000000001111111111", "00000000001111111111", "00000000001111111111"])
		for y: int in 3:
			sim.spawn(UnitType.infantry(), P, Vector2i(1, y))
			sim.spawn(UnitType.infantry(), E, Vector2i(18, y))
		sim.spawn(UnitType.tank(), P, Vector2i(0, 3))
		sim.spawn(UnitType.mortar(), E, Vector2i(19, 3))
		sim.issue(SimCommand.move(P, PackedInt32Array([1, 3, 5]), Vector2i(12, 1)))
		_run(sim, 20)
		sim.issue(SimCommand.hold(E, PackedInt32Array([2, 4, 6])))
		sim.issue(SimCommand.attack(P, PackedInt32Array([7]), 8))
		_run(sim, 400)
		hashes.append(sim.state_hash())
	check_eq(hashes[0], hashes[1], "same seed and commands give the same state")
