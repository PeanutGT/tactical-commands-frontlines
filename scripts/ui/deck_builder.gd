class_name DeckBuilder
extends Control
## Pre-match screen (section 7): pick the map's deck size of cards from the
## whole pool, any mix of factions, each card once. Click a card to add or
## remove it. Also picks the AI's difficulty (section 12).

signal deck_confirmed(deck: Array[StringName], difficulty: AiPlayer.Difficulty)

var _size: int = 0
var _deck: Array[StringName] = []
var _buttons: Dictionary[StringName, Button] = {}
var _count: Label
var _list: Label
var _start: Button
var _difficulty: OptionButton


## Builds the screen for a deck of `size` cards, starting from `initial`.
func setup(size: int, initial: Array[StringName]) -> void:
	_size = size
	_deck = initial.duplicate()
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: Panel = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.04, 0.05, 0.04, 0.94)))
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_top = 20.0
	root.offset_right = -24.0
	root.offset_bottom = -20.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 20)
	root.add_child(_count)
	var hint: Label = Label.new()
	hint.text = "點卡片加入或移除；可跨勢力混搭，每張卡限一張。滑鼠停在卡片上看數值。"
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	root.add_child(hint)

	var cols: HBoxContainer = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	for faction: StringName in Card.FACTIONS:
		var col: VBoxContainer = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		var title: Label = Label.new()
		title.text = Card.FACTION_NAMES[faction]
		title.add_theme_color_override("font_color", UiTheme.faction_color(faction))
		title.add_theme_font_size_override("font_size", 17)
		col.add_child(title)
		for id: StringName in Card.pool():
			if Card.faction(id) == faction:
				col.add_child(_card_button(id))

	_list = Label.new()
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_list)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var label: Label = Label.new()
	label.text = "AI 難度"
	bottom.add_child(label)
	_difficulty = OptionButton.new()
	for n: String in AiPlayer.NAMES:
		_difficulty.add_item(n)
	_difficulty.select(AiPlayer.Difficulty.NORMAL)
	_difficulty.custom_minimum_size = Vector2(110, 40)
	bottom.add_child(_difficulty)
	_start = Button.new()
	_start.text = "開始"
	_start.custom_minimum_size = Vector2(160, 40)
	_start.pressed.connect(_on_start)
	bottom.add_child(_start)
	_refresh()


func _card_button(id: StringName) -> Button:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s   費 %d｜權重 %d" % [Card.display_name(id), Card.cost(id), Card.weight(id)] if Card.is_unit(id) \
		else "%s   費 %d｜支援" % [Card.display_name(id), Card.cost(id)]
	b.tooltip_text = card_details(id)
	b.toggled.connect(func(on: bool) -> void: _toggle(id, on))
	_buttons[id] = b
	return b


## One-line stats for tooltips.
static func card_details(id: StringName) -> String:
	if not Card.is_unit(id):
		return Card.SUPPORT_TEXT.get(id, "") + "\n效果結束回牌庫底部"
	var t: UnitType = UnitType.of(id)
	var text: String = "血 %d｜裝甲 %d｜組織 %d｜速度 %.1f 格/秒" % [t.max_hp, t.armor, t.max_org, t.speed_mps / MapScale.STANDARD_METERS_PER_CELL]
	if t.weapon != null:
		text += "\n傷害 %d｜射程 %.0f 格｜穿甲 %d｜壓制 %d" % [t.weapon.damage, t.weapon.range_m / MapScale.STANDARD_METERS_PER_CELL, t.weapon.penetration, t.weapon.suppression]
	if t.transport_capacity > 0:
		text += "\n可載步兵權重 %d" % t.transport_capacity
	text += "\n陣亡後冷卻 %d 秒" % roundi(Card.cooldown_sec(id))
	return text


func _toggle(id: StringName, on: bool) -> void:
	if on and not _deck.has(id) and _deck.size() < _size:
		_deck.append(id)
	elif not on:
		_deck.erase(id)
	_refresh()


func _refresh() -> void:
	for id: StringName in _buttons:
		_buttons[id].set_pressed_no_signal(_deck.has(id))
		_buttons[id].disabled = not _deck.has(id) and _deck.size() >= _size
	_count.text = "組牌 %d / %d" % [_deck.size(), _size]
	_list.text = "牌組：" + "、".join(PackedStringArray(_deck.map(func(id: StringName) -> String: return Card.display_name(id))))
	_start.disabled = Card.validate_deck(_deck, _size) != ""


func _on_start() -> void:
	if Card.validate_deck(_deck, _size) != "":
		return
	visible = false
	deck_confirmed.emit(_deck.duplicate(), _difficulty.selected as AiPlayer.Difficulty)
