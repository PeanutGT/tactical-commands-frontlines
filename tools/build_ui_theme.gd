extends SceneTree
## Writes res://ui/tcf_theme.tres, the project-wide UI theme. Run once to
## start over from these defaults; after that, edit the .tres in the editor.
##   godot --headless --path . --script res://tools/build_ui_theme.gd

const OUT: String = "res://ui/tcf_theme.tres"


func _initialize() -> void:
	var t: Theme = Theme.new()
	t.default_font = UiTheme.text_font()
	t.default_font_size = 14
	t.set_color("font_color", "Label", UiTheme.TEXT)

	t.set_stylebox("normal", "Button", UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1))
	t.set_stylebox("hover", "Button", UiTheme.panel(UiTheme.GRAPHITE_LIGHT, UiTheme.EDGE, 1))
	t.set_stylebox("pressed", "Button", UiTheme.panel(UiTheme.GRAPHITE_LIGHT, UiTheme.FRIEND, 1))
	t.set_stylebox("disabled", "Button", UiTheme.panel(Color(UiTheme.GRAPHITE, 0.45)))
	t.set_stylebox("focus", "Button", UiTheme.panel(Color.TRANSPARENT, UiTheme.FRIEND, 1))
	t.set_color("font_color", "Button", UiTheme.TEXT)
	t.set_color("font_hover_color", "Button", UiTheme.TEXT)
	t.set_color("font_pressed_color", "Button", UiTheme.TEXT)
	t.set_color("font_hover_pressed_color", "Button", UiTheme.TEXT)
	t.set_color("font_disabled_color", "Button", Color(UiTheme.TEXT_DIM, 0.6))
	for k: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	t.set_stylebox("panel", "TooltipPanel", UiTheme.panel(Color(UiTheme.GRAPHITE, 0.98), UiTheme.EDGE, 1))
	t.set_color("font_color", "TooltipLabel", UiTheme.TEXT)

	# Label variations.
	var hud: StyleBoxFlat = UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1)
	hud.set_content_margin_all(8.0)
	_label(t, "HudPanel", 14, UiTheme.TEXT, null, hud)
	_label(t, "HudPanelDim", 13, UiTheme.TEXT_DIM, null, hud)
	t.set_constant("line_spacing", "HudPanelDim", 4)
	_label(t, "Dim", 12, UiTheme.TEXT_DIM)
	_label(t, "CardName", 15, UiTheme.TEXT)
	_label(t, "FactionTitle", 17, UiTheme.TEXT)
	_label(t, "CardCost", 30, UiTheme.FRIEND, UiTheme.stencil(800))
	_label(t, "DeckCount", 30, UiTheme.TEXT, UiTheme.stencil(800))
	var key_box: StyleBoxFlat = UiTheme.panel(Color.TRANSPARENT, UiTheme.EDGE, 1)
	key_box.set_content_margin_all(2.0)
	key_box.content_margin_left = 5.0
	key_box.content_margin_right = 5.0
	_label(t, "KeyTag", 14, UiTheme.TEXT_DIM, UiTheme.stencil(700), key_box)
	var big: StyleBoxFlat = UiTheme.panel(Color(UiTheme.GRAPHITE, 0.96), UiTheme.EDGE, 1)
	big.set_content_margin_all(32.0)
	big.border_width_top = 6
	_label(t, "ResultBanner", 44, UiTheme.TEXT, UiTheme.stencil(800), big)
	_label(t, "HandStatus", 14, UiTheme.TEXT, null, UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1))

	# Hand card: graphite with a thick top band; the band takes the card's
	# faction colour at run time.
	var card: StyleBoxFlat = UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1)
	card.border_width_top = 5
	card.content_margin_top = 9.0
	card.content_margin_left = 8.0
	card.content_margin_right = 6.0
	t.set_type_variation("HandCard", "PanelContainer")
	t.set_stylebox("panel", "HandCard", card)
	t.set_type_variation("Backdrop", "Panel")
	t.set_stylebox("panel", "Backdrop", UiTheme.panel(Color("1a1d20")))

	# Start button: the one filled control on the deck screen.
	t.set_type_variation("StartButton", "Button")
	t.set_stylebox("normal", "StartButton", UiTheme.panel(UiTheme.FRIEND))
	t.set_stylebox("pressed", "StartButton", UiTheme.panel(UiTheme.FRIEND))
	t.set_stylebox("hover", "StartButton", UiTheme.panel(UiTheme.FRIEND.lightened(0.25)))
	t.set_color("font_color", "StartButton", UiTheme.GRAPHITE_LIGHT)
	t.set_color("font_hover_color", "StartButton", UiTheme.GRAPHITE_LIGHT)
	t.set_color("font_pressed_color", "StartButton", UiTheme.GRAPHITE_LIGHT)
	t.set_font_size("font_size", "StartButton", 17)

	var err: Error = ResourceSaver.save(t, OUT)
	print("saved %s: %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _label(t: Theme, name: String, size: int, color: Color, font: Font = null, box: StyleBox = null) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if font != null:
		t.set_font("font", name, font)
	if box != null:
		t.set_stylebox("normal", name, box)
