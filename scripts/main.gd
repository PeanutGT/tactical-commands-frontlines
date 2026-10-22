extends Node2D
## Map view: loads a map, lets the player build a deck and pick the AI's
## difficulty, then runs the simulation and the AI at a fixed tick rate,
## builds the render layers and wires input, the hand and the HUD.

signal map_loaded(map: GameMap)
signal cursor_cell_changed(cell: Vector2i)

@export_dir var map_dir: String = "res://maps/hecheng"
@export var sim_seed: int = 1

## Most ticks run in one frame, so a long hitch does not spiral.
const MAX_TICKS_PER_FRAME: int = 5
const DEPLOY_REFUSED: Dictionary[Simulation.Deploy, String] = {
	Simulation.Deploy.NOT_IN_HAND: "這張卡已不在手上",
	Simulation.Deploy.NO_SUPPLY: "補給不足",
	Simulation.Deploy.OVER_WEIGHT: "超過權重上限",
	Simulation.Deploy.BAD_PLACE: "只能出在己方出兵區或沒有敵人的己方據點附近",
}
## Why a support card could not be dropped there, per Card.Aim.
const AIM_REFUSED: Array[String] = [
	"不能出在地圖外",
	"要落在己方看得到的地方",
	"運補車隊要從沒有敵人的己方據點出發",
	"要點在看得到的敵方單位或橋上",
	"要點在己方裝甲單位上",
]
const CONVOY_PROMPT: String = "運補車隊：點另一個己方據點或總部當終點（右鍵取消）"
const RESULT_TEXT: Array[String] = ["勝利", "敗北", "平手"]
const END_TEXT: Dictionary[Simulation.End, String] = {
	Simulation.End.HQ_DESTROYED: "總部被摧毀",
	Simulation.End.SCORE: "積分先到門檻",
	Simulation.End.TIME: "時間到",
}

@onready var _terrain: TerrainLayer = $TerrainLayer
@onready var _markers: MapMarkers = $Markers
@onready var _grid: GridOverlay = $Grid
@onready var _units: UnitLayer = $Units
@onready var _fog: FogLayer = $Fog
@onready var _deploy: DeployOverlay = $Deploy
@onready var _selection: SelectionController = $Selection
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $Hud
@onready var _hand: HandBar = $Hud/Hand
@onready var _deck_builder: DeckBuilder = $Hud/DeckBuilder

var map: GameMap
## Null until the player has picked a deck.
var sim: Simulation
var ai: AiPlayer
var style: StylePack = StylePack.dev()
var _cursor: Vector2i = Vector2i(-1, -1)
var _tick_time: float = 0.0
var _bridge_revision: int = 0
## 運補車隊 dropped and waiting for its destination: [slot, card, start cell].
var _convoy: Array = []


func _ready() -> void:
	map_loaded.connect(_hud.show_map)
	cursor_cell_changed.connect(_hud.set_cursor)
	_selection.selection_changed.connect(_hud.set_selection)
	_camera.zoom_changed.connect(_hud.set_zoom)

	map = MapLoader.load_map(map_dir)
	if map == null:
		return
	if not map.unknown_colors.is_empty():
		var first: MapParser.UnknownColor = map.unknown_colors[0]
		push_warning("%s: %d unrecognised colours, first at %s rgb %s" % [map.config.id, map.unknown_colors.size(), first.pos, first.rgb])

	_terrain.build(map, style)
	_markers.setup(map, style)
	_grid.setup(map, style)
	_grid.visible = false
	map_loaded.emit(map)
	_camera.setup(Vector2(map.width, map.height) * style.cell_px)
	_deck_builder.deck_confirmed.connect(start_match)
	_deck_builder.setup(map.config.deck_size, DeckStore.load_deck(map.config.deck_size))


## Starts the match with the player's `deck` against the AI, which plays the
## starter deck.
func start_match(deck: Array[StringName], difficulty: AiPlayer.Difficulty) -> void:
	DeckStore.save_deck(deck)
	sim = Simulation.new(map, sim_seed)
	sim.setup_side(GameMap.Side.PLAYER, deck)
	sim.setup_side(GameMap.Side.ENEMY, DeckStore.starter(map.config.deck_size))
	ai = AiPlayer.new(sim, GameMap.Side.ENEMY, difficulty, sim_seed)
	_hud.set_difficulty(AiPlayer.NAMES[difficulty])
	_units.setup(sim, style)
	_fog.setup(sim, style)
	_markers.sim = sim
	_bridge_revision = sim.bridges.revision
	_deploy.setup(sim, style)
	_selection.setup(sim, _units, style)
	_hand.setup(sim)
	_hand.drag_changed.connect(_deploy.set_card)
	_hand.card_dropped.connect(_on_card_dropped)


func _process(delta: float) -> void:
	if map == null:
		return
	if sim != null:
		_tick_time += delta
		var ticks: int = 0
		while _tick_time >= Simulation.TICK_SEC and ticks < MAX_TICKS_PER_FRAME and sim.winner == Simulation.NO_WINNER:
			sim.step()
			ai.update()
			_units.capture_tick()
			_tick_time -= Simulation.TICK_SEC
			ticks += 1
		if ticks > 0:
			_selection.prune_dead()
			var held: Array[int] = [sim.points_held(GameMap.Side.PLAYER), sim.points_held(GameMap.Side.ENEMY)]
			_hud.set_score(sim.score, held, sim.ff_penalty[GameMap.Side.PLAYER])
			_hud.set_match(sim.time_left_sec(), [sim.hq_hp(0), sim.hq_hp(1)] as Array[float])
			if sim.bridges.revision != _bridge_revision:
				_bridge_revision = sim.bridges.revision
				_terrain.build(sim.map, style)
			if sim.winner != Simulation.NO_WINNER:
				_show_result()
		if ticks == MAX_TICKS_PER_FRAME:
			_tick_time = minf(_tick_time, Simulation.TICK_SEC)
		_units.alpha = _tick_time / Simulation.TICK_SEC

	var cell: Vector2i = Vector2i((get_global_mouse_position() / float(style.cell_px)).floor())
	if not map.in_bounds(cell):
		cell = Vector2i(-1, -1)
	if cell != _cursor:
		_cursor = cell
		cursor_cell_changed.emit(cell)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_G:
			_grid.visible = not _grid.visible
		KEY_F, KEY_HOME:
			_camera.fit()


func _show_result() -> void:
	var r: String = RESULT_TEXT[sim.winner] if sim.winner != Simulation.DRAW else RESULT_TEXT[2]
	_hud.show_result("%s｜%s\n積分 我方 %d：敵方 %d" % [r, END_TEXT[sim.end_reason], sim.score[0], sim.score[1]])


func _screen_cell(screen_pos: Vector2) -> Vector2i:
	var world: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	return Vector2i((world / float(style.cell_px)).floor())


## A card from the hand let go over the map: play it there, or say why not.
## 運補車隊 then waits for a click on its destination.
func _on_card_dropped(slot: int, card: StringName, screen_pos: Vector2) -> void:
	var cell: Vector2i = _screen_cell(screen_pos)
	var r: Simulation.Deploy = sim.can_deploy(GameMap.Side.PLAYER, slot, card, cell)
	if r != Simulation.Deploy.OK:
		_hand.flash(AIM_REFUSED[Card.aim(card)] if r == Simulation.Deploy.BAD_PLACE and Card.is_support(card) else DEPLOY_REFUSED[r])
	elif card == &"supply_convoy":
		_convoy = [slot, card, cell]
		_hand.set_prompt(CONVOY_PROMPT)
		_deploy.set_convoy(cell)
	else:
		sim.issue(SimCommand.deploy(GameMap.Side.PLAYER, slot, card, cell))


## While a 運補車隊 waits for its destination, a left click picks it and a
## right click calls it off.
func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if _convoy.is_empty() or mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var dest: Vector2i = _screen_cell(mb.position)
		var r: Simulation.Deploy = sim.can_deploy(GameMap.Side.PLAYER, _convoy[0], _convoy[1], _convoy[2], dest)
		if r == Simulation.Deploy.OK:
			sim.issue(SimCommand.deploy(GameMap.Side.PLAYER, _convoy[0], _convoy[1], _convoy[2], dest))
		else:
			_hand.flash("終點要是另一個己方據點或總部" if r == Simulation.Deploy.BAD_PLACE else DEPLOY_REFUSED[r])
	elif mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_convoy = []
	_hand.set_prompt("")
	_deploy.set_convoy(Vector2i(-1, -1))
	get_viewport().set_input_as_handled()
