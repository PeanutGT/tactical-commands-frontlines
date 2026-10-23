class_name SelectionPanel
extends Control
## Bottom-left readout of the selected units. One unit: name, strength,
## health and organization bars with numbers, status and weapon. Several:
## one row each with small bars. Reads the simulation, never changes it.

const WIDTH: float = 300.0
const PAD: float = 10.0
const ROW_H: float = 22.0
const MAX_ROWS: int = 8
const BAR_H: float = 6.0

var _sim: Simulation
var _units: UnitLayer


func setup(sim: Simulation, units: UnitLayer) -> void:
	_sim = sim
	_units = units


func _process(_delta: float) -> void:
	if _sim == null:
		return
	var ids: Array[int] = _ids()
	visible = not ids.is_empty()
	if not visible:
		return
	var h: float = 116.0 if ids.size() == 1 else PAD * 2.0 + 24.0 + ROW_H * mini(ids.size(), MAX_ROWS) + (16.0 if ids.size() > MAX_ROWS else 0.0)
	# Anchored to the bottom edge: grow upwards from offset_bottom.
	offset_top = offset_bottom - h
	offset_right = offset_left + WIDTH
	queue_redraw()


func _ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in _units.selected:
		if _sim.unit(id) != null:
			out.append(id)
	out.sort()
	return out


func _draw() -> void:
	if _sim == null:
		return
	draw_style_box(UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1), Rect2(Vector2.ZERO, size))
	var ids: Array[int] = _ids()
	if ids.size() == 1:
		_draw_one(_sim.unit(ids[0]))
	else:
		_draw_many(ids)


func _draw_one(u: SimUnit) -> void:
	var t: UnitType = u.type
	var font: Font = UiTheme.text_font()
	var x: float = PAD
	var w: float = WIDTH - PAD * 2.0
	draw_rect(Rect2(0, 0, 4, size.y), UiTheme.faction_color(t.faction))
	draw_string(font, Vector2(x, 26), t.display_name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 17, UiTheme.TEXT)
	draw_string(UiTheme.stencil(700), Vector2(x, 26), "%d/%d" % [u.figures(), t.figures], HORIZONTAL_ALIGNMENT_RIGHT, w, 18, UiTheme.TEXT_DIM)
	_bar_line(Vector2(x, 44), w, "兵力", u.hp, t.max_hp, _hp_color(u.hp / t.max_hp))
	_bar_line(Vector2(x, 64), w, "組織", u.org, t.max_org, _org_color(u))
	draw_string(font, Vector2(x, 92), _status(u), HORIZONTAL_ALIGNMENT_LEFT, w, 13, UiTheme.UNKNOWN if u.routing or u.is_suppressed() else UiTheme.TEXT)
	var weapon: String = "無武裝"
	if t.weapon != null:
		weapon = "傷害 %d｜射程 %.0f 格｜穿甲 %d｜裝甲 %d" % [t.weapon.damage, t.weapon.range_m / MapScale.STANDARD_METERS_PER_CELL, t.weapon.penetration, t.armor]
	draw_string(font, Vector2(x, 108), weapon, HORIZONTAL_ALIGNMENT_LEFT, w, 12, UiTheme.TEXT_DIM)


## Label, a bar and "value / max" on one line, `top` at the bar's top edge.
func _bar_line(top: Vector2, w: float, label: String, v: float, vmax: float, col: Color) -> void:
	var font: Font = UiTheme.text_font()
	draw_string(font, top + Vector2(0, 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT_DIM)
	var bar: Rect2 = Rect2(top + Vector2(34, 1), Vector2(w - 34 - 70, BAR_H + 2))
	_bar(bar, clampf(v / vmax, 0.0, 1.0), col)
	draw_string(UiTheme.stencil(600), top + Vector2(0, 11), "%d / %d" % [ceili(v), roundi(vmax)], HORIZONTAL_ALIGNMENT_RIGHT, w, 14, UiTheme.TEXT)


func _draw_many(ids: Array[int]) -> void:
	var font: Font = UiTheme.text_font()
	var w: float = WIDTH - PAD * 2.0
	draw_string(font, Vector2(PAD, 24), "已選 %d 個單位" % ids.size(), HORIZONTAL_ALIGNMENT_LEFT, w, 15, UiTheme.TEXT)
	var y: float = PAD + 24.0
	for i: int in mini(ids.size(), MAX_ROWS):
		var u: SimUnit = _sim.unit(ids[i])
		draw_rect(Rect2(PAD, y + 4, 3, ROW_H - 8), UiTheme.faction_color(u.type.faction))
		draw_string(font, Vector2(PAD + 8, y + 15), u.type.display_name, HORIZONTAL_ALIGNMENT_LEFT, 130, 13, UiTheme.TEXT)
		var bx: float = PAD + 144.0
		var bw: float = w - 144.0
		_bar(Rect2(bx, y + 5, bw, BAR_H), clampf(u.hp / u.type.max_hp, 0.0, 1.0), _hp_color(u.hp / u.type.max_hp))
		_bar(Rect2(bx, y + 5 + BAR_H + 2, bw, BAR_H - 2), clampf(u.org / u.type.max_org, 0.0, 1.0), _org_color(u))
		y += ROW_H
	if ids.size() > MAX_ROWS:
		draw_string(font, Vector2(PAD, y + 12), "還有 %d 個" % (ids.size() - MAX_ROWS), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UiTheme.TEXT_DIM)


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)


func _status(u: SimUnit) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if u.routing:
		parts.append("潰退中")
	elif u.is_suppressed():
		parts.append("受壓制")
	if u.retreating:
		parts.append("撤退中")
	match u.hold:
		SimUnit.Hold.ENTERING:
			parts.append("進入駐守")
		SimUnit.Hold.HELD:
			parts.append("駐守")
		SimUnit.Hold.LEAVING:
			parts.append("離開駐守")
	if not u.passengers.is_empty():
		parts.append("載員 %d 班" % u.passengers.size())
	if u.forced_target:
		parts.append("強制攻擊")
	return "、".join(parts) if not parts.is_empty() else "待命"


static func _hp_color(f: float) -> Color:
	return UiTheme.NEUTRAL if f > 0.5 else (UiTheme.UNKNOWN if f > 0.25 else UiTheme.HOSTILE)


static func _org_color(u: SimUnit) -> Color:
	return UiTheme.HOSTILE if u.routing else (Color("f0a050") if u.is_suppressed() else UiTheme.TEXT)
