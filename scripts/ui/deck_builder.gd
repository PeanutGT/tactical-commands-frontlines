class_name DeckBuilder
extends Control
## Pre-match screen (section 7): pick the map's deck size of cards from the
## whole pool, any mix of factions, each card once. Click a card to add or
## remove it. Also picks the AI's difficulty (section 12).

signal deck_confirmed(deck: Array[StringName], difficulty: AiPlayer.Difficulty)

var _size: int = 0
var _deck: Array[StringName] = []
var _buttons: Dictionary[StringName, Button] = {}

@onready var _count: Label = %Count
@onready var _columns: HBoxContainer = %Columns
@onready var _list: Label = %List
@onready var _start: Button = %Start
@onready var _difficulty: OptionButton = %Difficulty


## Fills the screen for a deck of `size` cards, starting from `initial`.
## Layout lives in deck_builder.tscn; the card list is built from the pool.
func setup(size: int, initial: Array[StringName]) -> void:
	_size = size
	_deck = initial.duplicate()
	for faction: StringName in Card.FACTIONS:
		var col: VBoxContainer = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_columns.add_child(col)
		var title: Label = Label.new()
		title.text = Card.FACTION_NAMES[faction]
		title.theme_type_variation = &"FactionTitle"
		title.add_theme_color_override("font_color", UiTheme.faction_color(faction))
		col.add_child(title)
		for id: StringName in Card.pool():
			if Card.faction(id) == faction:
				col.add_child(_card_button(id))
	_difficulty.clear()
	for n: String in AiPlayer.NAMES:
		_difficulty.add_item(n)
	_difficulty.select(AiPlayer.Difficulty.NORMAL)
	_start.pressed.connect(_on_start)
	_refresh()


func _card_button(id: StringName) -> Button:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s   費 %d｜權重 %d" % [Card.display_name(id), Card.cost(id), Card.weight(id)] if Card.is_unit(id) \
		else "%s   費 %d｜支援" % [Card.display_name(id), Card.cost(id)]
	b.tooltip_text = card_details(id)
	var picked: StyleBoxFlat = UiTheme.panel(UiTheme.GRAPHITE_LIGHT, UiTheme.faction_color(Card.faction(id)), 2)
	b.add_theme_stylebox_override("pressed", picked)
	b.add_theme_stylebox_override("hover_pressed", picked)
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
	text += "\n打出後冷卻 %d 秒再回牌庫" % roundi(Card.cooldown_sec(id))
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
