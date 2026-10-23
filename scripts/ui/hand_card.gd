class_name HandCard
extends PanelContainer
## One card in the hand: cost, hotkey, name and weight, with the faction's
## colour on the top band. Layout and look live in hand_card.tscn and the
## project theme; this only fills them in.

@onready var _cost: Label = %Cost
@onready var _key: Label = %Key
@onready var _name: Label = %Name
@onready var _kind: Label = %Kind


func set_key(text: String) -> void:
	_key.text = text


## Shows card `id`, or an empty slot for SideState.EMPTY.
func show_card(id: StringName) -> void:
	var box: StyleBoxFlat = get_theme_stylebox("panel", "HandCard").duplicate() as StyleBoxFlat
	if id == SideState.EMPTY:
		_name.text = ""
		_cost.text = ""
		_kind.text = "牌庫已空"
		box.border_width_top = box.border_width_bottom
		box.bg_color = Color(box.bg_color, 0.5)
		add_theme_stylebox_override("panel", box)
		tooltip_text = ""
		return
	_name.text = Card.display_name(id)
	_cost.text = str(Card.cost(id))
	_kind.text = "權重 %d" % Card.weight(id) if Card.is_unit(id) else "支援"
	box.border_color = UiTheme.faction_color(Card.faction(id))
	add_theme_stylebox_override("panel", box)
	tooltip_text = DeckBuilder.card_details(id)


## Dims the card when it cannot be played; the cost turns red when supply
## is short. `carried` fades the card that is being dragged.
func set_state(affordable: bool, playable: bool, carried: bool) -> void:
	modulate = Color(1, 1, 1, 0.35 if carried else 1.0) if playable else Color(0.55, 0.55, 0.55, 0.8)
	_cost.add_theme_color_override("font_color", UiTheme.FRIEND if affordable else UiTheme.HOSTILE)
