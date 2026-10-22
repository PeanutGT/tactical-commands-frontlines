class_name UiTheme
extends RefCounted
## Shared look for the card screens: a CJK system font and dark panels.

const TEXT: Color = Color("e8ecdf")
const TEXT_DIM: Color = Color("9aa08f")
const PANEL: Color = Color(0.06, 0.08, 0.05, 0.86)
const BAD: Color = Color("f07a5a")
## Card border per faction.
const FACTION_COLORS: Dictionary[StringName, Color] = {
	&"common": Color("b8bca8"), &"alliance": Color("5aa8f0"),
	&"federation": Color("e0604a"), &"armor_corps": Color("d8b040"),
}


static func make() -> Theme:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans TC", "PingFang TC", "sans-serif"])
	var t: Theme = Theme.new()
	t.default_font = font
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	return t


static func panel(bg: Color = PANEL, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6.0)
	return s


static func faction_color(faction: StringName) -> Color:
	return FACTION_COLORS.get(faction, TEXT)
