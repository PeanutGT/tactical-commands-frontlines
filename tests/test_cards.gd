extends TestCase
## Deck, hand, supply, card cycle, retreat and transports (sections 6, 7, 9).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
const ROWS: Array[String] = [
	"pppp....................",
	"pppp....................",
	"pppp..........yy........",
	"pppp..........yy........",
	"pppp....................",
	"........................",
	"....................eeee",
	"....................eeee",
	"....................eeee",
]
const DECK: Array[StringName] = [
	&"infantry", &"apc", &"tank", &"scout_car", &"javelin", &"bazooka", &"mortar", &"supply_convoy",
]


func _run(sim: Simulation, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


## Hecheng's card settings on a small test map; both sides dealt DECK.
func _sim(seed_value: int = 5) -> Simulation:
	var map: GameMap = map_from_rows(ROWS)
	map.config.weight_cap = 30
	map.config.deck_size = 8
	map.config.hand_size = 4
	map.config.start_supply = 5
	map.config.supply_cap = 10
	var sim: Simulation = Simulation.new(map, seed_value)
	sim.setup_side(P, DECK)
	sim.setup_side(E, DECK)
	return sim


## Replaces the shuffled hand and deck with known ones.
func _deal(sim: Simulation, hand: Array[StringName], deck: Array[StringName], supply: float = 10.0) -> SideState:
	var s: SideState = sim.sides[P]
	s.hand = hand.duplicate()
	s.deck = deck.duplicate()
	s.supply = supply
	return s


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _card_unit(sim: Simulation, card: StringName, side: int, cell: Vector2i) -> SimUnit:
	var u: SimUnit = sim.spawn(UnitType.of(card), side, cell)
	u.card = card
	return u


func test_pool_and_deck_rules() -> void:
	var pool: Array[StringName] = Card.pool()
	check(pool.has(&"infantry") and pool.has(&"supply_convoy"), "pool has unit and support cards")
	check(not pool.has(&"attack_heli") and not pool.has(&"transport_heli"), "air units wait for M7")
	check_eq(Card.validate_deck(DECK, 8), "", "legal deck")
	check(Card.validate_deck(DECK, 6) != "", "wrong size")
	var dup: Array[StringName] = DECK.duplicate()
	dup[1] = &"infantry"
	check(Card.validate_deck(dup, 8) != "", "duplicate card")
	var air: Array[StringName] = DECK.duplicate()
	air[1] = &"attack_heli"
	check(Card.validate_deck(air, 8) != "", "card outside the pool")
	check_eq(Card.cooldown_sec(&"tank"), 18.0, "cooldown is cost x 3 s")
	check_eq(Card.weight(&"supply_convoy"), 0, "support cards weigh nothing")
	check_eq(DeckStore.starter(8).size(), 8, "starter deck fills the deck size")
	check_eq(Card.validate_deck(DeckStore.starter(10), 10), "", "starter deck is legal for 10")


func test_setup_shuffles_and_deals_the_hand() -> void:
	var a: Simulation = _sim(5)
	var s: SideState = a.sides[P]
	check_eq(s.hand.size(), 4, "hand size from the map")
	check_eq(s.deck.size(), 4, "rest stays in the deck")
	var all: Array[StringName] = s.hand + s.deck
	all.sort()
	var want: Array[StringName] = DECK.duplicate()
	want.sort()
	check_eq(all, want, "every card dealt once")
	check_eq(s.supply, 5.0, "start supply from the map")
	var b: Simulation = _sim(5)
	check_eq(b.sides[P].hand + b.sides[P].deck, s.hand + s.deck, "same seed, same order")
	var differs: bool = false
	for seed_value: int in range(6, 12):
		var c: Simulation = _sim(seed_value)
		if c.sides[P].hand + c.sides[P].deck != s.hand + s.deck:
			differs = true
	check(differs, "other seeds shuffle differently")


func test_supply_rate_follows_weight_and_points() -> void:
	var sim: Simulation = _sim()
	check(_near(sim.supply_rate(P), 0.2), "empty field: 0.2/s")
	for i: int in 3:
		sim.spawn(UnitType.tank(), P, Vector2i(6 + i, 5))  # 3 x weight 5 = 15
	check(_near(sim.supply_rate(P), 0.15), "15/30: 0.15/s")
	for i: int in 3:
		sim.spawn(UnitType.tank(), P, Vector2i(6 + i, 6))
	check(_near(sim.supply_rate(P), 0.1), "30/30: 0.1/s")
	sim.poi_owner[0] = P
	check(_near(sim.supply_rate(P), 0.15), "one point held: +0.05/s")
	check(_near(sim.supply_rate(E), 0.2), "the other side is unaffected")


func test_supply_grows_and_caps() -> void:
	var sim: Simulation = _sim()
	_run(sim, Simulation.TICK_RATE * 4)
	check(_near(sim.sides[P].supply, 5.8), "5 + 4 s x 0.2")
	_run(sim, Simulation.TICK_RATE * 40)
	check_eq(sim.sides[P].supply, 10.0, "stops at the map's cap")


func test_deploy_in_spawn_zone_draws_from_the_deck() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _deal(sim, [&"infantry", &"apc", &"tank", &"scout_car"], [&"javelin", &"mortar"], 5.0)
	check_eq(sim.can_deploy(P, 2, &"tank", Vector2i(1, 1)), Simulation.Deploy.NO_SUPPLY, "tank costs 6")
	sim.issue(SimCommand.deploy(P, 0, &"infantry", Vector2i(1, 1)))
	sim.step()
	check_eq(sim.last_deploy[P], Simulation.Deploy.OK, "played")
	check_eq(sim.units.size(), 1, "unit on the field")
	var u: SimUnit = sim.units[0]
	check_eq(u.type.id, &"infantry", "right unit")
	check_eq(u.card, &"infantry", "remembers its card")
	check_eq(u.cell(), Vector2i(1, 1), "where it was dropped")
	check(_near(s.supply, 5.0 - 2.0 + Simulation.SUPPLY_BASE * Simulation.TICK_SEC), "cost paid after this tick's supply")
	check_eq(s.hand, [&"javelin", &"apc", &"tank", &"scout_car"] as Array[StringName], "slot refilled from the top")
	check_eq(s.deck, [&"mortar"] as Array[StringName], "deck shrinks")
	check_eq(sim.field_weight(P), 2, "weight counts it")


func test_deploy_is_refused_where_and_when_it_should_be() -> void:
	var sim: Simulation = _sim()
	_deal(sim, [&"infantry", &"apc", &"tank", &"supply_convoy"], [&"javelin"])
	check_eq(sim.can_deploy(P, 0, &"infantry", Vector2i(10, 1)), Simulation.Deploy.BAD_PLACE, "open ground")
	check_eq(sim.can_deploy(P, 0, &"infantry", Vector2i(21, 7)), Simulation.Deploy.BAD_PLACE, "enemy spawn")
	check_eq(sim.can_deploy(P, 0, &"tank", Vector2i(1, 1)), Simulation.Deploy.NOT_IN_HAND, "slot holds another card")
	check_eq(sim.can_deploy(P, 9, &"infantry", Vector2i(1, 1)), Simulation.Deploy.NOT_IN_HAND, "no such slot")
	check_eq(sim.can_deploy(P, 3, &"supply_convoy", Vector2i(10, 1)), Simulation.Deploy.BAD_PLACE, "a convoy starts at a held point")
	sim.issue(SimCommand.deploy(P, 0, &"infantry", Vector2i(10, 1)))
	sim.step()
	check_eq(sim.last_deploy[P], Simulation.Deploy.BAD_PLACE, "sim re-checks the command")
	check(sim.units.is_empty(), "nothing spawned")
	sim.map.config.weight_cap = 7
	sim.spawn(UnitType.tank(), P, Vector2i(10, 5))
	check_eq(sim.can_deploy(P, 0, &"infantry", Vector2i(1, 1)), Simulation.Deploy.OK, "5 + 2 fits 7")
	check_eq(sim.can_deploy(P, 1, &"apc", Vector2i(1, 1)), Simulation.Deploy.OVER_WEIGHT, "5 + 3 is over 7")


func test_deploy_near_a_held_point() -> void:
	var sim: Simulation = _sim()
	_deal(sim, [&"infantry", &"apc", &"tank", &"scout_car"], [])
	var near: Vector2i = Vector2i(12, 2)
	check_eq(sim.can_deploy(P, 0, &"infantry", near), Simulation.Deploy.BAD_PLACE, "nobody holds the point")
	sim.poi_owner[0] = P
	check_eq(sim.can_deploy(P, 0, &"infantry", near), Simulation.Deploy.OK, "held by us")
	check_eq(sim.can_deploy(P, 0, &"infantry", Vector2i(21, 3)), Simulation.Deploy.BAD_PLACE, "too far from it")
	sim.poi_owner[0] = E
	check_eq(sim.can_deploy(P, 0, &"infantry", near), Simulation.Deploy.BAD_PLACE, "held by the enemy")


func test_dead_unit_card_cools_down_then_returns_to_the_bottom() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _deal(sim, [&"apc", &"tank", &"scout_car", &"javelin"], [&"mortar"])
	var u: SimUnit = _card_unit(sim, &"infantry", P, Vector2i(10, 4))
	u.hp = 0.0
	sim.step()
	check(sim.unit(u.id) == null, "dead")
	check_eq(s.cooldowns.size(), 1, "card cooling")
	_run(sim, roundi(Card.cooldown_sec(&"infantry") * Simulation.TICK_RATE) - 1)
	check_eq(s.deck, [&"mortar"] as Array[StringName], "not back yet after 6 s minus a tick")
	sim.step()
	check_eq(s.deck, [&"mortar", &"infantry"] as Array[StringName], "back at the bottom")
	check(s.cooldowns.is_empty(), "cooldown done")


func test_empty_deck_leaves_the_slot_empty_until_a_card_returns() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _deal(sim, [&"infantry", &"apc", &"tank", &"scout_car"], [])
	sim.issue(SimCommand.deploy(P, 0, &"infantry", Vector2i(1, 1)))
	sim.step()
	check_eq(s.hand[0], SideState.EMPTY, "nothing to draw")
	var u: SimUnit = sim.units[0]
	u.hp = 0.0
	_run(sim, roundi(Card.cooldown_sec(&"infantry") * Simulation.TICK_RATE) + 1)
	check_eq(s.hand[0], &"infantry", "the returning card fills the empty slot")
	check(s.deck.is_empty(), "and does not wait in the deck")


func test_retreat_drives_home_and_refunds_half() -> void:
	var sim: Simulation = _sim()
	var s: SideState = _deal(sim, [&"apc", &"tank", &"scout_car", &"javelin"], [&"mortar"], 3.0)
	var u: SimUnit = _card_unit(sim, &"infantry", P, Vector2i(9, 3))
	sim.issue(SimCommand.retreat(P, PackedInt32Array([u.id])))
	sim.step()
	check(u.retreating and u.is_moving(), "heading home")
	sim.issue(SimCommand.move(P, PackedInt32Array([u.id]), Vector2i(15, 8)))
	var gone_at: float = -1.0
	for i: int in 400:
		var before: float = s.supply
		var rate: float = sim.supply_rate(P)
		sim.step()
		if sim.unit(u.id) == null:
			check(_near(s.supply, before + rate * Simulation.TICK_SEC + 1.0), "half of cost 2 back")
			gone_at = i
			break
	check(gone_at > 0.0, "left the field")
	check(u.cell().x <= 3, "inside the spawn zone, not where the later move pointed")
	check_eq(sim.retreated.size(), 1, "reported as retreated, not dead")
	check(sim.deaths.is_empty(), "no wreck")
	check_eq(s.deck.back(), &"infantry", "card straight to the bottom")
	check(s.cooldowns.is_empty(), "no cooldown")


func test_held_infantry_gets_out_before_retreating() -> void:
	var sim: Simulation = _sim()
	var u: SimUnit = _card_unit(sim, &"infantry", P, Vector2i(8, 3))
	u.hold = SimUnit.Hold.HELD
	sim.issue(SimCommand.retreat(P, PackedInt32Array([u.id])))
	_run(sim, Simulation.HOLD_LEAVE_TICKS - 1)
	check(not u.is_moving() and u.retreating, "still getting out")
	_run(sim, 2)
	check(u.is_moving(), "now driving home")


## An APC and three infantry squads ordered to board it, 6 s later.
class Rig:
	var sim: Simulation
	var apc: SimUnit
	var a: SimUnit
	var b: SimUnit
	var c: SimUnit


func _transport_setup() -> Rig:
	var t: Rig = Rig.new()
	t.sim = _sim()
	t.apc = _card_unit(t.sim, &"apc", P, Vector2i(12, 5))
	t.a = _card_unit(t.sim, &"infantry", P, Vector2i(10, 5))
	t.b = _card_unit(t.sim, &"infantry", P, Vector2i(9, 5))
	t.c = _card_unit(t.sim, &"infantry", P, Vector2i(6, 5))
	t.sim.issue(SimCommand.board(P, PackedInt32Array([t.a.id, t.b.id, t.c.id]), t.apc.id))
	_run(t.sim, Simulation.TICK_RATE * 6)
	return t


func test_infantry_boards_up_to_capacity() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	check_eq(apc.passengers, PackedInt32Array([t.a.id, t.b.id]), "the two nearest squads got in")
	check(not t.a.on_map() and not t.b.on_map(), "riders are off the map")
	check(t.c.on_map() and t.c.board_id == 0, "third squad turned away: APC carries weight 4")
	check_eq(sim.free_capacity(apc), 0, "full")
	check_eq(sim.field_weight(P), 3 + 2 + 2 + 2, "riders still count as weight")
	sim.issue(SimCommand.move(P, PackedInt32Array([apc.id, t.a.id]), Vector2i(16, 5)))
	_run(sim, Simulation.TICK_RATE * 3)
	check(apc.cell().x > 12, "APC drove off")
	check_eq(t.a.pos, apc.pos, "riders ride along")
	check(not t.a.is_moving(), "riders ignore orders")


func test_passengers_cannot_be_shot() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	t.c.hp = 0.0  # the squad left outside
	var rifle: SimUnit = sim.spawn(UnitType.infantry(), E, Vector2i(14, 5))
	_run(sim, Simulation.TICK_RATE * 2)
	check_eq(rifle.target_id, 0, "rifles cannot hurt the APC and cannot see the riders")
	check_eq(t.a.hp, t.a.type.max_hp, "rider untouched")
	check(apc.target_id == rifle.id, "the APC fires back")


func test_unload_takes_two_seconds() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	sim.issue(SimCommand.unload(P, PackedInt32Array([apc.id])))
	_run(sim, Simulation.UNLOAD_TICKS)
	check_eq(apc.passengers.size(), 2, "still inside after 2 s minus a tick")
	sim.step()
	check(apc.passengers.is_empty(), "out")
	check(t.a.on_map() and t.b.on_map(), "back on the map")
	check(t.a.cell() != t.b.cell(), "each on its own cell")
	check((t.a.pos - apc.pos).length() <= 3 * Simulation.SUBCELL, "next to the APC")


func test_moving_calls_off_an_unload() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	sim.issue(SimCommand.unload(P, PackedInt32Array([apc.id])))
	_run(sim, 10)
	sim.issue(SimCommand.move(P, PackedInt32Array([apc.id]), Vector2i(16, 5)))
	_run(sim, Simulation.UNLOAD_TICKS)
	check_eq(apc.passengers.size(), 2, "still carrying")


func test_wrecked_transport_throws_out_hurt_passengers() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	apc.hp = 0.0
	sim.step()
	check(sim.unit(apc.id) == null, "APC gone")
	for r: SimUnit in [t.a, t.b]:
		check(r.on_map(), "rider %d out" % r.id)
		check(_near(r.hp, r.type.max_hp * 0.5), "rider %d lost half its health" % r.id)
	check_eq(sim.sides[P].cooldowns.size(), 1, "only the APC card cools down")


func test_retreating_transport_takes_its_riders_home() -> void:
	var t: Rig = _transport_setup()
	var sim: Simulation = t.sim
	var apc: SimUnit = t.apc
	var s: SideState = sim.sides[P]
	s.deck = []
	s.hand = [&"tank", &"scout_car", &"javelin", &"mortar"]
	s.supply = 0.0
	sim.issue(SimCommand.retreat(P, PackedInt32Array([apc.id])))
	for i: int in 400:
		sim.step()
		if sim.unit(apc.id) == null:
			break
	check(sim.unit(apc.id) == null and sim.unit(t.a.id) == null and sim.unit(t.b.id) == null, "all three left")
	check_eq(s.deck, [&"apc", &"infantry", &"infantry"] as Array[StringName], "their cards return")
	check(s.supply >= 1.5 + 1.0 + 1.0, "half refunds for all three")


func test_replay_with_cards_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = _sim(9)
		var s: SideState = sim.sides[P]
		for i: int in Simulation.TICK_RATE * 20:
			if i % 60 == 0:
				for slot: int in s.hand.size():
					var id: StringName = s.hand[slot]
					if sim.can_deploy(P, slot, id, Vector2i(2, 2)) == Simulation.Deploy.OK:
						sim.issue(SimCommand.deploy(P, slot, id, Vector2i(2, 2)))
						break
			if i == 200 and not sim.units.is_empty():
				sim.issue(SimCommand.retreat(P, PackedInt32Array([sim.units[0].id])))
			sim.step()
		hashes.append(sim.state_hash())
		check(sim.units.size() > 1, "run %d deployed several cards" % run)
	check_eq(hashes[0], hashes[1], "same seed and commands, same state")
