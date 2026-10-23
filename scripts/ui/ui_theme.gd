class_name UiTheme
extends RefCounted
## Shared look for every screen: a staff officer's plotting board. Graphite
## panels, NATO symbol colours (APP-6 friend / hostile / neutral / unknown)
## for sides, a CJK system font for text and a stencil face for numbers.
## Controls get their look from res://ui/tcf_theme.tres (the project theme,
## first written by tools/build_ui_theme.gd); these constants are for the
## parts drawn in code and per-card colours.

const TEXT: Color = Color("e6e8e3")
const TEXT_DIM: Color = Color("959a93")
const GRAPHITE: Color = Color(0.137, 0.153, 0.169, 0.92)
const GRAPHITE_LIGHT: Color = Color("323840")
const EDGE: Color = Color("4a525b")
const PANEL: Color = GRAPHITE
## APP-6 frame fills.
const FRIEND: Color = Color("80e0ff")
const HOSTILE: Color = Color("ff8080")
const NEUTRAL: Color = Color("aaffaa")
const UNKNOWN: Color = Color("ffff80")
const BAD: Color = HOSTILE
const GOOD: Color = NEUTRAL
## Card band per faction.
const FACTION_COLORS: Dictionary[StringName, Color] = {
	&"common": Color("b8bca8"), &"alliance": Color("5aa8f0"),
	&"federation": Color("e0604a"), &"armor_corps": Color("d8b040"),
}
const STENCIL_PATH: String = "res://assets/fonts/big_shoulders_stencil.ttf"

static var _text_font: SystemFont
static var _stencil: Dictionary[int, FontVariation] = {}


static func text_font() -> SystemFont:
	if _text_font == null:
		_text_font = SystemFont.new()
		_text_font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans TC", "PingFang TC", "sans-serif"])
	return _text_font


## The stencil face at `weight` (100-900), for numbers and key labels.
static func stencil(weight: int = 700) -> Font:
	if not _stencil.has(weight):
		var v: FontVariation = FontVariation.new()
		v.base_font = load(STENCIL_PATH) as FontFile
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		v.fallbacks = [text_font()]
		_stencil[weight] = v
	return _stencil[weight]


static func panel(bg: Color = PANEL, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(6.0)
	return s


static func faction_color(faction: StringName) -> Color:
	return FACTION_COLORS.get(faction, TEXT)


static func side_color(side: int) -> Color:
	return FRIEND if side == GameMap.Side.PLAYER else HOSTILE
