extends TestCase
## Formations, penetration vs armour, and organization (suppression).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func _sim(rows: Array[String]) -> Simulation:
	return Simulation.new(map_from_rows(rows), 3)


## Unarmed target with lots of health, so it neither dies nor shoots back.
func _dummy(kind: UnitType.Kind = UnitType.Kind.INFANTRY, armor: int = 0) -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", kind, 0.0)
	t.max_hp = 10000.0
	t.armor = armor
	return t


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _lost(u: SimUnit) -> float:
	return u.type.max_hp - u.hp


func test_every_card_has_unit_model_stats() -> void:
	var ids: Array[StringName] = UnitType.ids()
	check_eq(ids.size(), 26, "26 unit cards")
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		check(not seen.has(id), "unique id %s" % id)
		seen[id] = true
		var t: UnitType = UnitType.of(id)
		check(t.figures >= 1 and t.max_org > 0.0 and t.max_hp > 0.0, "%s has figures, org and hp" % id)
		if t.kind == UnitType.Kind.INFANTRY:
			check_eq(t.armor, 0, "%s infantry is unarmoured" % id)
		if t.weapon != null:
			check(t.weapon.suppression > 0.0 and t.weapon.cooldown_sec > 0.0, "%s weapon suppresses and reloads" % id)
	check(UnitType.of(&"nope") == null, "unknown id")


func test_figures_shrink_with_strength() -> void:
	var t: UnitType = UnitType.infantry()
	check_eq(t.figures_at(100.0), 9, "full squad")
	check_eq(t.figures_at(50.0), 5, "half strength rounds up")
	check_eq(t.figures_at(1.0), 1, "last man")
	check_eq(t.figures_at(0.0), 0, "gone")


func test_figure_layout_is_centred() -> void:
	var offs: Array[Vector2] = UnitLayer.figure_offsets(9, 4, Vector2(1.0, 1.0))
	check_eq(offs.size(), 9, "one offset per figure")
	var lo: Vector2 = offs[0]
	var hi: Vector2 = offs[0]
	for o: Vector2 in offs:
		lo = lo.min(o)
		hi = hi.max(o)
	check(_near(lo.x, -hi.x) and _near(lo.y, -hi.y), "block centred, %s..%s" % [lo, hi])
	check(_near(offs[8].x, 0.0), "a short last row is centred too")


func test_penetration_falloff() -> void:
	check_eq(Weapon.pen_factor(18, 14), 1.0, "pierces")
	check_eq(Weapon.pen_factor(14, 14), 1.0, "equal pierces")
	check(_near(Weapon.pen_factor(13, 14), 2.0 / 3.0), "one short")
	check(_near(Weapon.pen_factor(12, 14), 1.0 / 3.0), "two short")
	check_eq(Weapon.pen_factor(11, 14), 0.0, "three short does nothing")
	check_eq(Weapon.pen_factor(1, 14), 0.0, "rifle vs tank")


func test_rifles_cannot_hurt_tanks() -> void:
	var sim: Simulation = _sim(["........"])
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 14), E, Vector2i(4, 0))
	_run(sim, 5)
	check_eq(sim.shots.size() + int(_lost(t)), 0, "idle rifles do not waste fire on a tank")
	sim.issue(SimCommand.attack(P, PackedInt32Array([u.id]), t.id))
	_run(sim, 2)
	check_eq(_lost(t), 0.0, "forced fire bounces off")
	check_eq(t.org, t.type.max_org, "and does not suppress")


func test_rifles_partly_hurt_light_armour() -> void:
	var sim: Simulation = _sim(["........"])
	sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 2), E, Vector2i(4, 0))
	sim.step()
	check(_near(_lost(t), 10.0 * 2.0 / 3.0), "pen 1 vs armour 2, lost %f" % _lost(t))


func test_anti_tank_pierces() -> void:
	var sim: Simulation = _sim([".......", "......."])
	sim.spawn(UnitType.of(&"bazooka"), P, Vector2i(0, 0))
	var mbt: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 14), E, Vector2i(4, 0))
	sim.step()
	check(_near(_lost(mbt), 40.0), "pen 16 vs MBT armour 14, lost %f" % _lost(mbt))
	var sim2: Simulation = _sim(["......."])
	sim2.spawn(UnitType.of(&"bazooka"), P, Vector2i(0, 0))
	var heavy: SimUnit = sim2.spawn(_dummy(UnitType.Kind.ARMOR, 18), E, Vector2i(4, 0))
	sim2.step()
	check(_near(_lost(heavy), 40.0 / 3.0), "two short vs heavy tank, lost %f" % _lost(heavy))


func test_anti_armour_weapons_ignore_infantry() -> void:
	var sim: Simulation = _sim(["........"])
	var j: SimUnit = sim.spawn(UnitType.of(&"javelin"), P, Vector2i(0, 0))
	var inf: SimUnit = sim.spawn(_dummy(), E, Vector2i(4, 0))
	sim.issue(SimCommand.attack(P, PackedInt32Array([j.id]), inf.id))
	_run(sim, 5)
	check_eq(_lost(inf), 0.0, "javelin will not shoot infantry, even when ordered")
	check(not j.forced_target, "order refused")


func test_hits_cost_organization() -> void:
	var sim: Simulation = _sim(["..........", "f........."])
	sim.spawn(UnitType.infantry(), P, Vector2i(5, 0))
	var open: SimUnit = sim.spawn(_dummy(), E, Vector2i(2, 0))
	sim.step()
	check(_near(open.org, 85.0), "rifle suppression 15, org %f" % open.org)
	var sim2: Simulation = _sim(["..........", "f........."])
	sim2.spawn(UnitType.infantry(), P, Vector2i(3, 1))
	var wood: SimUnit = sim2.spawn(_dummy(), E, Vector2i(0, 1))
	wood.hold = SimUnit.Hold.HELD
	sim2.step()
	check(_near(wood.org, 100.0 - 15.0 * 0.48), "held in forest takes 48%%, org %f" % wood.org)


func test_suppressed_unit_reloads_slower() -> void:
	var sim: Simulation = _sim(["........"])
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(4, 0))
	u.org = 40.0
	u.last_hit_tick = 0
	check(u.is_suppressed(), "under half")
	sim.step()
	_run(sim, 29)
	check(_near(_lost(t), 10.0), "no second shot before 1.5 s, lost %f" % _lost(t))
	sim.step()
	check(_near(_lost(t), 20.0), "second shot at 1.5 s, lost %f" % _lost(t))


func test_zero_organization_routs_until_rally() -> void:
	var sim: Simulation = _sim(["...................."])
	var shooter: SimUnit = sim.spawn(UnitType.infantry(), E, Vector2i(5, 0))
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(2, 0))
	u.org = 5.0
	u.hold = SimUnit.Hold.HELD
	sim.step()
	check(u.routing and u.org == 0.0, "routs at 0")
	check(u.hold == SimUnit.Hold.NONE, "leaves its position at once")
	check(u.is_moving() and u.destination().x < 2, "heads away from the shooter, to %s" % u.destination())
	# Take the shooter away so the routing unit can recover.
	shooter.hp = 0.0
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(19, 0)))
	var start: Vector2i = u.pos
	_run(sim, Simulation.TICK_RATE)
	check(u.destination().x < 2, "ignores orders")
	check_eq(sim.shots.size(), 0, "and does not fire")
	var walked: float = float(start.x - u.pos.x) / Simulation.SUBCELL
	check(absf(walked - 0.75) < 0.05, "half speed, %f cells in 1 s" % walked)
	# 4 s before recovery starts, then 3/s (no moving penalty) up to 30.
	var rallied_at: int = -1
	for i: int in 20 * Simulation.TICK_RATE:
		sim.step()
		if not u.routing:
			rallied_at = sim.tick
			break
	check(absi(rallied_at - (1 + 4 * Simulation.TICK_RATE + 10 * Simulation.TICK_RATE)) <= 2, "rallies after about 14 s, tick %d" % rallied_at)
	check(not u.is_moving(), "and stops where it is")


func test_routing_unit_heads_for_its_spawn() -> void:
	var sim: Simulation = _sim(["...................."])
	sim.map.player_spawn = CellGroup.new()
	sim.map.player_spawn.center = Vector2(18.0, 0.0)
	sim.spawn(UnitType.infantry(), E, Vector2i(0, 0))
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(4, 0))
	u.org = 1.0
	sim.step()
	check(u.routing and u.destination() == Vector2i(18, 0), "routs home, to %s" % u.destination())


func test_firepower_follows_strength() -> void:
	var sim: Simulation = _sim(["........"])
	var u: SimUnit = sim.spawn(UnitType.infantry(), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(4, 0))
	u.hp = 50.0
	sim.step()
	check(_near(_lost(t), 10.0 * 5.0 / 9.0), "5 of 9 men fire, lost %f" % _lost(t))
	check(_near(t.org, 100.0 - 15.0 * 5.0 / 9.0), "and suppress, org %f" % t.org)


func test_recovery_is_faster_held_in_forest() -> void:
	var sim: Simulation = _sim(["f."])
	var wood: SimUnit = sim.spawn(_dummy(), P, Vector2i(0, 0))
	var open: SimUnit = sim.spawn(_dummy(), P, Vector2i(1, 0))
	wood.hold = SimUnit.Hold.HELD
	for u: SimUnit in [wood, open]:
		u.org = 50.0
		u.last_hit_tick = 0
	_run(sim, 4 * Simulation.TICK_RATE - 1)
	check_eq(open.org, 50.0, "nothing during the first 4 s")
	_run(sim, Simulation.TICK_RATE)
	check(_near(open.org, 53.0), "3 per second in the open, org %f" % open.org)
	check(_near(wood.org, 50.0 + 3.0 * 2.25), "×1.5 held ×1.5 forest, org %f" % wood.org)


func test_rocket_launcher_fires_volleys() -> void:
	var sim: Simulation = _sim(["......................"])
	sim.spawn(UnitType.of(&"mrl"), P, Vector2i(0, 0))
	var t: SimUnit = sim.spawn(_dummy(), E, Vector2i(18, 0))
	# Unarmed spotter 3 cells from the target, outside the blast: artillery needs eyes.
	sim.spawn(_dummy(), P, Vector2i(15, 0))
	var shots: Array[int] = []
	for i: int in 13 * Simulation.TICK_RATE:
		sim.step()
		if not sim.shots.is_empty():
			shots.append(sim.tick)
	check_eq(shots.size(), 7, "six rockets then the next volley")
	check_eq(shots[5] - shots[0], 5 * 10, "0.5 s apart")
	check_eq(shots[6] - shots[5], 10 * Simulation.TICK_RATE, "10 s reload")
	check(_near(_lost(t), 35.0 * 7), "35 each")
