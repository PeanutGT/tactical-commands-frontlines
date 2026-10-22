extends TestCase
## Support cards (section 8 支援卡效果) and the 運補車隊 truck.

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
## Player HQ in the corner; two 3×3 points centred (6.5, 2.5) and (33.5, 2.5).
const ROWS: Array[String] = [
	"hhh.....................................",
	"hhh..yyy........................yyy.....",
	"hhh..yyy........................yyy.....",
	"ppp..yyy........................yyy..eee",
	"ppp..................................eee",
	"ppp..................................eee",
]


func _sim() -> Simulation:
	var map: GameMap = map_from_rows(ROWS)
	map.config.supply_cap = 20
	map.config.weight_cap = 30
	return Simulation.new(map, 6)


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


## Puts `card` alone in the player's hand with plenty of supply.
func _hand(sim: Simulation, card: StringName, side: int = P) -> SideState:
	var s: SideState = sim.sides[side]
	s.hand = [card, SideState.EMPTY] as Array[StringName]
	s.deck = []
	s.supply = 15.0
	return s


func _dummy(kind: UnitType.Kind = UnitType.Kind.INFANTRY, armor: int = 0, vision_cells: float = 0.0) -> UnitType:
	var t: UnitType = UnitType.new(&"dummy", "dummy", kind, 0.0)
	t.max_hp = 10000.0
	t.armor = armor
	t.vision_m = MapScale.standard_cells_to_meters(vision_cells)
	return t


func _lost(u: SimUnit) -> float:
	return u.type.max_hp - u.hp


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


# --- 運補車隊 ------------------------------------------------------------------

func test_convoy_payout_steps() -> void:
	check_eq(Simulation.convoy_payout(4.0), 1, "at least 1")
	check_eq(Simulation.convoy_payout(25.0), 2, "+1 per 10 cells")
	check_eq(Simulation.convoy_payout(200.0), 6, "at most 6")


func test_convoy_needs_a_held_start_and_another_goal() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"supply_convoy")
	check_eq(sim.can_deploy(P, 0, &"supply_convoy", Vector2i(33, 4)), Simulation.Deploy.BAD_PLACE, "point not held")
	sim.poi_owner[1] = P
	check_eq(sim.can_deploy(P, 0, &"supply_convoy", Vector2i(33, 4)), Simulation.Deploy.OK, "held point")
	check_eq(sim.can_deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(34, 2)), Simulation.Deploy.BAD_PLACE, "same point")
	check_eq(sim.can_deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(6, 2)), Simulation.Deploy.BAD_PLACE, "point not held")
	check_eq(sim.can_deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(1, 1)), Simulation.Deploy.OK, "own HQ")
	sim.issue(SimCommand.deploy(P, 0, &"supply_convoy", Vector2i(33, 4)))
	sim.step()
	check_eq(sim.last_deploy[P], Simulation.Deploy.BAD_PLACE, "the command needs a goal")


func test_convoy_drives_home_and_pays_by_distance() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[1] = P
	var s: SideState = _hand(sim, &"supply_convoy")
	s.supply = 5.0
	sim.issue(SimCommand.deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(1, 1)))
	sim.step()
	check_eq(sim.units.size(), 2, "a truck next to the HQ")
	var truck: SimUnit = sim.units[1]
	check(truck.is_convoy() and truck.convoy_goal == SimUnit.GOAL_HQ, "driving to the HQ")
	check_eq(sim.field_weight(P), 0, "weighs nothing")
	var done: bool = false
	for i: int in 60 * Simulation.TICK_RATE:
		var before: float = s.supply
		var rate: float = sim.supply_rate(P)
		sim.step()
		if sim.unit(truck.id) == null:
			check(truck.convoy_cells > 25.0 and truck.convoy_cells < 35.0, "drove about 30 cells, %f" % truck.convoy_cells)
			check(_near(s.supply, before + rate * Simulation.TICK_SEC + 2.0), "+2 for 20-odd cells")
			done = true
			break
	check(done, "arrived")
	check_eq(s.hand[0], &"supply_convoy", "card back at the bottom (straight into the empty slot)")
	check(sim.deaths.is_empty(), "arrived, not destroyed")


func test_shot_up_truck_brings_nothing() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[1] = P
	var s: SideState = _hand(sim, &"supply_convoy")
	sim.issue(SimCommand.deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(1, 1)))
	sim.step()
	var truck: SimUnit = sim.units[1]
	var before: float = s.supply
	truck.hp = 0.0
	sim.step()
	check(_near(s.supply, before + sim.supply_rate(P) * Simulation.TICK_SEC), "no pay-out")
	check_eq(s.hand[0], &"supply_convoy", "card goes straight back (straight into the empty slot)")
	check(s.cooldowns.is_empty(), "no cooldown")


func test_convoy_reroutes_when_its_goal_falls() -> void:
	var sim: Simulation = _sim()
	sim.poi_owner[0] = P
	sim.poi_owner[1] = P
	_hand(sim, &"supply_convoy")
	sim.issue(SimCommand.deploy(P, 0, &"supply_convoy", Vector2i(33, 4), Vector2i(6, 4)))
	sim.step()
	var truck: SimUnit = sim.units[1]
	check_eq(truck.convoy_goal, 0, "off to the other point")
	sim.poi_owner[0] = E
	sim.step()
	check_eq(truck.convoy_goal, SimUnit.GOAL_HQ, "nearest place still held, not where it set out")


# --- Other support cards -----------------------------------------------------

func test_artillery_lands_after_three_seconds() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _hand(sim, &"artillery")
	sim.spawn(_dummy(UnitType.Kind.INFANTRY, 0, 8.0), P, Vector2i(15, 4))
	var foe: SimUnit = sim.spawn(_dummy(), E, Vector2i(20, 4))
	var far: SimUnit = sim.spawn(_dummy(), E, Vector2i(24, 4))
	check_eq(sim.can_deploy(P, 0, &"artillery", Vector2i(20, 4)), Simulation.Deploy.BAD_PLACE, "not seen before the first sight pass")
	sim.step()
	check_eq(sim.can_deploy(P, 0, &"artillery", Vector2i(30, 4)), Simulation.Deploy.BAD_PLACE, "out of sight")
	sim.issue(SimCommand.deploy(P, 0, &"artillery", Vector2i(20, 4)))
	sim.step()
	check_eq(sim.effects.size(), 1, "shells on the way")
	_run(sim, roundi(Support.ARTILLERY_DELAY_SEC * Simulation.TICK_RATE) - 1)
	check_eq(_lost(foe), 0.0, "not yet")
	sim.step()
	check(_near(_lost(foe), 120.0 * Simulation.DAMAGE_SCALE), "120 × 0.7, lost %f" % _lost(foe))
	check_eq(_lost(far), 0.0, "4 cells off is outside the 3-cell blast")
	check(sim.effects.is_empty(), "over")
	check_eq(s.hand[0], &"artillery", "card back at the bottom (straight into the empty slot)")


func test_smoke_hides_what_is_inside() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"smoke")
	sim.spawn(_dummy(UnitType.Kind.INFANTRY, 0, 10.0), P, Vector2i(12, 4))
	var foe: SimUnit = sim.spawn(_dummy(), E, Vector2i(19, 4))
	sim.step()
	check(sim.vision.sees(P, foe), "seen in the open")
	sim.issue(SimCommand.deploy(P, 0, &"smoke", Vector2i(18, 4)))
	_run(sim, Simulation.VISION_TICKS + 1)
	check(not sim.vision.sees(P, foe), "hidden in the smoke")
	_run(sim, roundi(Support.SMOKE_SEC * Simulation.TICK_RATE))
	check(sim.vision.sees(P, foe), "seen again once it clears")
	check(sim.vision.smoke_zones.is_empty(), "cloud gone")


func test_drone_lights_up_an_area_for_a_while() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"drone_recon")
	var foe: SimUnit = sim.spawn(_dummy(), E, Vector2i(25, 4))
	sim.issue(SimCommand.deploy(P, 0, &"drone_recon", Vector2i(22, 3)))
	_run(sim, Simulation.VISION_TICKS + 1)
	check(sim.vision.sees(P, foe), "seen from above")
	_run(sim, roundi(Support.DRONE_SEC * Simulation.TICK_RATE))
	check(not sim.vision.sees(P, foe), "gone after 15 s")


func test_precision_missile_and_active_protection() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"precision_missile")
	_hand(sim, &"aps", E)
	sim.spawn(_dummy(UnitType.Kind.INFANTRY, 0, 8.0), P, Vector2i(15, 4))
	var a: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 14), E, Vector2i(20, 4))
	var b: SimUnit = sim.spawn(_dummy(UnitType.Kind.ARMOR, 14), E, Vector2i(20, 1))
	sim.step()
	sim.issue(SimCommand.deploy(P, 0, &"precision_missile", Vector2i(20, 4)))
	sim.step()
	check(_near(_lost(a), 250.0 * Simulation.DAMAGE_SCALE), "250 × 0.7 at once, lost %f" % _lost(a))
	sim.issue(SimCommand.deploy(E, 0, &"aps", Vector2i(20, 1)))
	sim.sides[P].hand[0] = &"precision_missile"
	sim.step()
	check(b.aps_ticks > 0, "protected")
	sim.issue(SimCommand.deploy(P, 0, &"precision_missile", Vector2i(20, 1)))
	sim.step()
	check(_near(_lost(b), 250.0 * Simulation.DAMAGE_SCALE * Support.APS_TAKEN), "halved, lost %f" % _lost(b))


func test_barrage_hits_a_line_across_the_front() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"barrage")
	sim.spawn(_dummy(UnitType.Kind.INFANTRY, 0, 12.0), P, Vector2i(14, 3))
	var on_line: SimUnit = sim.spawn(_dummy(), E, Vector2i(20, 0))
	var off_line: SimUnit = sim.spawn(_dummy(), E, Vector2i(24, 3))
	sim.step()
	sim.issue(SimCommand.deploy(P, 0, &"barrage", Vector2i(20, 3)))
	_run(sim, roundi(Support.BARRAGE_DELAY_SEC * Simulation.TICK_RATE) + 1)
	check(_near(_lost(on_line), 90.0 * Simulation.DAMAGE_SCALE), "on the line, lost %f" % _lost(on_line))
	check_eq(_lost(off_line), 0.0, "4 cells behind it")


func test_call_reserves_halves_cooldowns() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _hand(sim, &"call_reserves")
	s.cooldowns = [[&"tank", 100], [&"apc", 41]]
	sim.issue(SimCommand.deploy(P, 0, &"call_reserves", Vector2i(10, 4)))
	sim.step()
	check_eq(s.cooldowns, [[&"tank", 50], [&"apc", 20]], "halved (rounded up) after this tick's count")
	check_eq(s.hand[0], &"call_reserves", "card back at once (straight into the empty slot)")


func test_repair_and_add_on_armour() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _hand(sim, &"field_repair")
	var tank: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(15, 4))
	tank.hp = 100.0
	check_eq(sim.can_deploy(P, 0, &"field_repair", Vector2i(25, 4)), Simulation.Deploy.BAD_PLACE, "needs own armour")
	sim.issue(SimCommand.deploy(P, 0, &"field_repair", Vector2i(15, 4)))
	sim.step()
	check_eq(tank.hp, 400.0, "+300")
	s.hand[0] = &"addon_armor"
	sim.issue(SimCommand.deploy(P, 0, &"addon_armor", Vector2i(16, 4)))
	sim.step()
	check_eq(tank.shield, Support.ADDON_SHIELD, "200 shield")
	sim.support_strike(E, tank, 100.0, 30, 0.0, false, Vector2i.ZERO)
	check(_near(tank.shield, 200.0 - 70.0) and tank.hp == 400.0, "the shield soaks it")
	_run(sim, roundi(Support.ADDON_SEC * Simulation.TICK_RATE))
	check_eq(tank.shield, 0.0, "gone after 30 s")
	check_eq(s.hand[0], &"addon_armor", "card back (straight into the empty slot)")


func test_armored_assault_speeds_up_armour() -> void:
	var sim: Simulation = _sim()
	_hand(sim, &"armored_assault")
	var tank: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(10, 4))
	sim.issue(SimCommand.deploy(P, 0, &"armored_assault", Vector2i(12, 4)))
	sim.issue(SimCommand.move(P, PackedInt32Array([tank.id]), Vector2i(30, 4)))
	sim.step()
	var start: int = tank.pos.x
	_run(sim, Simulation.TICK_RATE)
	var moved: float = float(tank.pos.x - start) / Simulation.SUBCELL
	check(absf(moved - 2.0 * Simulation.SPEED_SCALE * Support.ASSAULT_SPEED) < 0.02, "+40%%, %f cells in 1 s" % moved)


func test_replay_with_support_cards_matches() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = _sim()
		_hand(sim, &"artillery")
		sim.spawn(UnitType.infantry(), P, Vector2i(15, 4))
		sim.spawn(UnitType.infantry(), E, Vector2i(22, 4))
		sim.step()
		sim.issue(SimCommand.deploy(P, 0, &"artillery", Vector2i(22, 4)))
		_run(sim, Simulation.TICK_RATE * 6)
		hashes.append(sim.state_hash())
	check_eq(hashes[0], hashes[1], "same seed, same orders, same state")
