extends TestCase
## The rule-based opponent (section 12).

const P: int = GameMap.Side.PLAYER
const E: int = GameMap.Side.ENEMY
## Two HQs, two points centred (6.5, 2.5) and (33.5, 2.5).
const ROWS: Array[String] = [
	"hhh..................................hhh",
	"hhh..yyy........................yyy..hhh",
	"hhh..yyy........................yyy..hhh",
	"ppp..yyy........................yyy..eee",
	"ppp..................................eee",
	"ppp..................................eee",
]
const DECK: Array[StringName] = [
	&"infantry", &"apc", &"tank", &"scout_car", &"javelin", &"bazooka", &"mortar", &"supply_convoy",
]


func _sim(seed_value: int = 2) -> Simulation:
	var map: GameMap = map_from_rows(ROWS)
	map.config.weight_cap = 40
	map.config.hand_size = 4
	map.config.start_supply = 5
	map.config.supply_cap = 10
	var sim: Simulation = Simulation.new(map, seed_value)
	sim.setup_side(P, DECK)
	sim.setup_side(E, DECK)
	return sim


func _play(sim: Simulation, ai: AiPlayer, ticks: int) -> void:
	for i: int in ticks:
		sim.step()
		ai.update()


func test_plays_cards_and_takes_points() -> void:
	var sim: Simulation = _sim()
	var ai: AiPlayer = AiPlayer.new(sim, E, AiPlayer.Difficulty.HARD, 2)
	_play(sim, ai, 90 * Simulation.TICK_RATE)
	check(sim.field_weight(E) > 0, "has units on the field")
	check_eq(sim.poi_owner, [E, E] as Array[int], "took both points from an empty field")
	for c: SimCommand in sim.command_log:
		check_eq(c.side, E, "orders only its own side")


func test_pushes_for_the_hq_when_the_points_are_its() -> void:
	var sim: Simulation = _sim()
	var ai: AiPlayer = AiPlayer.new(sim, E, AiPlayer.Difficulty.HARD, 2)
	_play(sim, ai, 240 * Simulation.TICK_RATE)
	check(sim.hq_hp(P) < 2000.0 or sim.winner == E, "the player's HQ came under fire")


func test_easy_answers_later_than_hard() -> void:
	var first_deploy: Array[int] = []
	for d: AiPlayer.Difficulty in [AiPlayer.Difficulty.HARD, AiPlayer.Difficulty.EASY]:
		var sim: Simulation = _sim()
		var ai: AiPlayer = AiPlayer.new(sim, E, d, 2)
		_play(sim, ai, 5 * Simulation.TICK_RATE)
		first_deploy.append(sim.command_log[0].tick if not sim.command_log.is_empty() else 1 << 30)
	check(first_deploy[0] < first_deploy[1], "hard %d before easy %d" % first_deploy)


func test_ai_matches_replay() -> void:
	var hashes: Array[int] = []
	for run: int in 2:
		var sim: Simulation = _sim(11)
		var ai: AiPlayer = AiPlayer.new(sim, E, AiPlayer.Difficulty.NORMAL, 11)
		_play(sim, ai, 60 * Simulation.TICK_RATE)
		hashes.append(sim.state_hash())
	check_eq(hashes[0], hashes[1], "same seed, same match")


func test_does_not_see_through_fog() -> void:
	var sim: Simulation = _sim()
	var ai: AiPlayer = AiPlayer.new(sim, E, AiPlayer.Difficulty.HARD, 2)
	var hidden: SimUnit = sim.spawn(UnitType.tank(), P, Vector2i(18, 4))
	sim.step()
	check(not sim.vision.sees(E, hidden), "out of the AI's sight")
	check(not ai._seen_enemies().has(hidden), "so the AI does not know about it")
