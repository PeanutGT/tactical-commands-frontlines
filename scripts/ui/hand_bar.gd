class_name HandBar
extends Control
## Bottom-of-screen hand (section 7): one card per hand slot, with supply,
## field weight, the draw pile and cooling cards above it. Press a card and
## drag it onto the map to play it, or press F1-F4 to pick a card up and click
## the map; right-click or drop it back on the bar to cancel. Reads the
## simulation, never changes it. Layout lives in hand_bar.tscn; one
## hand_card.tscn is added per hand slot.

signal card_dropped(slot: int, card: StringName, screen_pos: Vector2)
## `card` is SideState.EMPTY when the drag ends.
signal drag_changed(card: StringName)

const CARD_SCENE: PackedScene = preload("res://scenes/ui/hand_card.tscn")
const MESSAGE_SEC: float = 2.0
## Keys that pick up hand slots 1-4 (number keys belong to control groups).
const SLOT_KEYS: Array[Key] = [KEY_F1, KEY_F2, KEY_F3, KEY_F4]

var side: int = GameMap.Side.PLAYER
var dragging_slot: int = -1

@onready var _status: Label = %Status
@onready var _queue: Label = %Queue
@onready var _gauge: SupplyGauge = %Gauge
@onready var _bar: HBoxContainer = %Cards
@onready var _ghost: Label = %Ghost

var _sim: Simulation
var _cards: Array[HandCard] = []
var _drag_card: StringName = SideState.EMPTY
var _message: String = ""
var _message_left: float = 0.0
## Standing instruction (picking a 運補車隊 destination), empty for none.
var _prompt: String = ""
## Last cards shown, so a card is only redrawn when the hand changes.
var _shown: Array[StringName] = []


func setup(sim: Simulation) -> void:
	_sim = sim
	for i: int in sim.sides[side].hand.size():
		var card: HandCard = CARD_SCENE.instantiate() as HandCard
		_bar.add_child(card)
		card.set_key(OS.get_keycode_string(SLOT_KEYS[i]) if i < SLOT_KEYS.size() else "")
		card.gui_input.connect(_on_card_input.bind(i))
		_cards.append(card)
		_shown.append(&"?")


## Shows `text` over the hand for a moment (why a card could not be played).
func flash(text: String) -> void:
	_message = text
	_message_left = MESSAGE_SEC


## Shows `text` over the hand until it is cleared with "".
func set_prompt(text: String) -> void:
	_prompt = text


func _process(delta: float) -> void:
	if _sim == null:
		return
	_message_left = maxf(0.0, _message_left - delta)
	var s: SideState = _sim.sides[side]
	var cap: int = _sim.map.config.weight_cap
	var weight: int = _sim.field_weight(side)
	_gauge.supply = s.supply
	_gauge.cap = _sim.map.config.supply_cap
	_gauge.rate = _sim.supply_rate(side)
	_gauge.weight = weight
	_gauge.weight_cap = cap
	_gauge.pending_cost = Card.cost(_drag_card) if _drag_card != SideState.EMPTY else 0
	_status.visible = _message_left > 0.0 or _prompt != ""
	_status.text = _message if _message_left > 0.0 else _prompt
	_status.add_theme_color_override("font_color", UiTheme.BAD if _message_left > 0.0 else UiTheme.GOOD)

	var cooling: PackedStringArray = PackedStringArray()
	for c: Array in s.cooldowns:
		cooling.append("%s %d 秒" % [Card.display_name(c[0]), ceili(float(c[1]) / Simulation.TICK_RATE)])
	for e: SupportEffect in _sim.effects:
		if e.side == side:
			cooling.append("%s 生效中" % Card.display_name(e.card))
	for u: SimUnit in _sim.units:
		if u.side == side and u.is_convoy():
			cooling.append("運補卡車在路上（%d 格）" % floori(u.convoy_cells))
	var next: String = Card.display_name(s.deck[0]) if not s.deck.is_empty() else "（空）"
	_queue.text = "牌庫 %d 張，下一張 %s" % [s.deck.size(), next]
	if not cooling.is_empty():
		_queue.text += "｜冷卻 " + "、".join(cooling)

	for i: int in s.hand.size():
		var id: StringName = s.hand[i]
		if id != _shown[i]:
			_shown[i] = id
			_cards[i].show_card(id)
		var affordable: bool = id != SideState.EMPTY and s.supply >= Card.cost(id)
		var playable: bool = affordable and weight + Card.weight(id) <= cap and _sim.winner == Simulation.NO_WINNER
		_cards[i].set_state(affordable, playable, i == dragging_slot)
	if dragging_slot >= 0:
		_ghost.position = get_local_mouse_position() + Vector2(14, -10)


func _on_card_input(event: InputEvent, slot: int) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pick_up(slot):
		accept_event()


## Starts carrying the card in `slot`; false when there is none to carry.
func _pick_up(slot: int) -> bool:
	if _sim == null or slot >= _sim.sides[side].hand.size():
		return false
	var id: StringName = _sim.sides[side].hand[slot]
	if id == SideState.EMPTY or _sim.winner != Simulation.NO_WINNER:
		return false
	dragging_slot = slot
	_drag_card = id
	_ghost.text = Card.display_name(id)
	_ghost.visible = true
	drag_changed.emit(id)
	return true


## F1-F4 pick up the card in that hand slot (pressing it again puts it down).
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.is_command_or_control_pressed() or key.shift_pressed:
		return
	var slot: int = SLOT_KEYS.find(key.physical_keycode)
	if slot < 0:
		return
	if slot == dragging_slot:
		_end_drag()
	elif _pick_up(slot):
		pass
	else:
		return
	get_viewport().set_input_as_handled()


## Runs before the map's own input, so a drag's release never selects units.
func _input(event: InputEvent) -> void:
	if dragging_slot < 0:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_end_drag()
	elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		pass  # a card picked up with F1-F4 is played on release; keep the press off the map
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		var slot: int = dragging_slot
		var card: StringName = _drag_card
		_end_drag()
		if not _bar.get_global_rect().has_point(mb.position):
			card_dropped.emit(slot, card, mb.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _end_drag() -> void:
	dragging_slot = -1
	_drag_card = SideState.EMPTY
	_ghost.visible = false
	drag_changed.emit(SideState.EMPTY)
