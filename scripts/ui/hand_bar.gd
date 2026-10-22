class_name HandBar
extends Control
## Bottom-of-screen hand (section 7): one card per hand slot, with supply,
## field weight, the draw pile and cooling cards above it. Press a card and
## drag it onto the map to play it, or press 1-4 to pick a card up and click
## the map; right-click or drop it back on the bar to cancel. Reads the
## simulation, never changes it.

signal card_dropped(slot: int, card: StringName, screen_pos: Vector2)
## `card` is SideState.EMPTY when the drag ends.
signal drag_changed(card: StringName)

const CARD_SIZE: Vector2 = Vector2(118, 78)
const MESSAGE_SEC: float = 2.0

var side: int = GameMap.Side.PLAYER
var dragging_slot: int = -1

var _sim: Simulation
var _cards: Array[PanelContainer] = []
var _names: Array[Label] = []
var _costs: Array[Label] = []
var _status: Label
var _queue: Label
var _ghost: Label
var _bar: HBoxContainer
var _drag_card: StringName = SideState.EMPTY
var _message: String = ""
var _message_left: float = 0.0
## Standing instruction (picking a 運補車隊 destination), empty for none.
var _prompt: String = ""
## Last texts shown, so styles are only rebuilt when the hand changes.
var _shown: Array[StringName] = []


func setup(sim: Simulation) -> void:
	_sim = sim
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -100.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)

	_queue = Label.new()
	_queue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_queue.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_queue.add_theme_font_size_override("font_size", 12)
	_queue.add_theme_stylebox_override("normal", UiTheme.panel())
	box.add_child(_queue)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_stylebox_override("normal", UiTheme.panel())
	box.add_child(_status)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 8)
	box.add_child(_bar)
	for i: int in sim.sides[side].hand.size():
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = CARD_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
		var v: VBoxContainer = VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cost_label: Label = Label.new()
		cost_label.add_theme_font_size_override("font_size", 12)
		v.add_child(name_label)
		v.add_child(cost_label)
		_bar.add_child(card)
		_cards.append(card)
		_names.append(name_label)
		_costs.append(cost_label)
		_shown.append(&"?")

	_ghost = Label.new()
	_ghost.visible = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.add_theme_stylebox_override("normal", UiTheme.panel(Color(0.1, 0.12, 0.08, 0.8), UiTheme.TEXT, 1))
	add_child(_ghost)


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
	var status: String = "補給 %.1f / %d（每秒 +%.2f）｜權重 %d / %d" % [s.supply, _sim.map.config.supply_cap, _sim.supply_rate(side), weight, cap]
	if _message_left > 0.0:
		status += "｜" + _message
	elif _prompt != "":
		status += "｜" + _prompt
	_status.text = status
	_status.add_theme_color_override("font_color", UiTheme.BAD if _message_left > 0.0 else (UiTheme.GOOD if _prompt != "" else UiTheme.TEXT))

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
	_queue.text = "牌庫 %d 張，下一張：%s" % [s.deck.size(), next]
	if not cooling.is_empty():
		_queue.text += "｜冷卻：" + "、".join(cooling)

	for i: int in s.hand.size():
		var id: StringName = s.hand[i]
		if id != _shown[i]:
			_shown[i] = id
			_restyle(i, id)
		var playable: bool = id != SideState.EMPTY and s.supply >= Card.cost(id) \
			and weight + Card.weight(id) <= cap and _sim.winner == Simulation.NO_WINNER
		_cards[i].modulate = Color(1, 1, 1, 0.35 if i == dragging_slot else 1.0) if playable \
			else Color(0.55, 0.55, 0.55, 0.8)
	if dragging_slot >= 0:
		_ghost.position = get_local_mouse_position() + Vector2(14, -10)


func _restyle(i: int, id: StringName) -> void:
	if id == SideState.EMPTY:
		_names[i].text = ""
		_costs[i].text = "（牌庫已空）"
		_cards[i].add_theme_stylebox_override("panel", UiTheme.panel(Color(0.06, 0.07, 0.05, 0.6), UiTheme.TEXT_DIM, 1))
		_cards[i].tooltip_text = ""
		return
	_names[i].text = Card.display_name(id)
	_costs[i].text = "費 %d｜權重 %d" % [Card.cost(id), Card.weight(id)] if Card.is_unit(id) else "費 %d｜支援" % Card.cost(id)
	_cards[i].add_theme_stylebox_override("panel", UiTheme.panel(Color(0.1, 0.12, 0.09, 0.92), UiTheme.faction_color(Card.faction(id)), 2))
	_cards[i].tooltip_text = DeckBuilder.card_details(id)


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


## 1-4 pick up the card in that hand slot (pressing it again puts it down).
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var slot: int = key.physical_keycode - KEY_1
	if slot < 0 or slot > 8:
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
		pass  # a card picked up with 1-4 is played on release; keep the press off the map
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
