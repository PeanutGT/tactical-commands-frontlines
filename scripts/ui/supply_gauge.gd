class_name SupplyGauge
extends Control
## One cell per point of supply up to the cap, filled as supply comes in; the
## number and income on the left, field weight on the right.

const GAUGE_H: float = 34.0
const LABEL_W: float = 150.0
const WEIGHT_W: float = 92.0

var supply: float = 0.0
var cap: int = 10
var rate: float = 0.0
var weight: int = 0
var weight_cap: int = 0
## Cost of the card being carried, shown as a bracket over the cells it uses.
var pending_cost: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, GAUGE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	draw_style_box(UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1), Rect2(Vector2.ZERO, size))
	draw_string(UiTheme.stencil(800), Vector2(10.0, 26.0), "%d" % floori(supply), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiTheme.FRIEND)
	draw_string(UiTheme.text_font(), Vector2(46.0, 21.0), "補給 +%.2f/秒" % rate, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT_DIM)
	var over: bool = weight >= weight_cap
	draw_string(UiTheme.text_font(), Vector2(w - WEIGHT_W - 8.0, 21.0), "權重", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT_DIM)
	draw_string(UiTheme.stencil(700), Vector2(w - WEIGHT_W + 22.0, 25.0), "%d/%d" % [weight, weight_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.HOSTILE if over else UiTheme.TEXT)
	if cap <= 0:
		return
	var x0: float = LABEL_W
	var span: float = w - LABEL_W - WEIGHT_W - 16.0
	var gap: float = 3.0
	var cell_w: float = (span - gap * (cap - 1)) / cap
	for i: int in cap:
		var r: Rect2 = Rect2(x0 + i * (cell_w + gap), 9.0, cell_w, GAUGE_H - 18.0)
		draw_rect(r, Color(UiTheme.FRIEND, 0.12))
		var fill: float = clampf(supply - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), UiTheme.FRIEND if fill >= 1.0 else Color(UiTheme.FRIEND, 0.45))
	if pending_cost > 0:
		var end: float = x0 + mini(pending_cost, cap) * (cell_w + gap) - gap
		var short: bool = supply < pending_cost
		var c: Color = UiTheme.HOSTILE if short else UiTheme.UNKNOWN
		draw_line(Vector2(x0, 5.0), Vector2(end, 5.0), c, 2.0)
		draw_line(Vector2(end, 5.0), Vector2(end, 9.0), c, 2.0)
