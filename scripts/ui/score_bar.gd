class_name ScoreBar
extends Control
## Top-of-screen tug of war: the clock in the middle, each side's score racing
## outward from it to the map's goal (friend left, hostile right), with points
## held as pips and HQ health as a thin line under each track.

const BAR_SIZE: Vector2 = Vector2(660, 64)
const CLOCK_W: float = 96.0
const TRACK_H: float = 10.0

var _score: Array[int] = [0, 0]
var _points: Array[int] = [0, 0]
var _goal: int = 0
var _time_left: float = -1.0
var _hq: Array[float] = [0.0, 0.0]
var _hq_max: Array[float] = [0.0, 0.0]


func _init() -> void:
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_goal(goal: int) -> void:
	_goal = goal
	queue_redraw()


func set_score(score: Array[int], points: Array[int]) -> void:
	_score = score.duplicate()
	_points = points.duplicate()
	queue_redraw()


## The first health seen per side counts as full.
func set_match(time_left: float, hq_hp: Array[float]) -> void:
	_time_left = time_left
	for s: int in 2:
		_hq_max[s] = maxf(_hq_max[s], hq_hp[s])
	_hq = hq_hp.duplicate()
	queue_redraw()


func _draw() -> void:
	var w: float = BAR_SIZE.x
	var mid: float = w * 0.5
	draw_style_box(UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1), Rect2(Vector2.ZERO, BAR_SIZE))
	# Clock.
	var clock_rect: Rect2 = Rect2(mid - CLOCK_W * 0.5, 0.0, CLOCK_W, BAR_SIZE.y)
	draw_rect(clock_rect, UiTheme.GRAPHITE_LIGHT)
	var clock: String = "%d:%02d" % [ceili(_time_left) / 60, ceili(_time_left) % 60] if _time_left >= 0.0 else "--:--"
	var urgent: bool = _time_left >= 0.0 and _time_left < 60.0
	draw_string(UiTheme.stencil(800), Vector2(clock_rect.position.x, 40.0), clock, HORIZONTAL_ALIGNMENT_CENTER, CLOCK_W, 32, UiTheme.UNKNOWN if urgent else UiTheme.TEXT)
	draw_string(UiTheme.text_font(), Vector2(clock_rect.position.x, 57.0), "目標 %d" % _goal if _goal > 0 else "", HORIZONTAL_ALIGNMENT_CENTER, CLOCK_W, 11, UiTheme.TEXT_DIM)
	for side: int in 2:
		_draw_side(side, mid)


## One half: label and pips at the outer end, score by the clock, the track
## filling from the clock outward, HQ health under it.
func _draw_side(side: int, mid: float) -> void:
	var color: Color = UiTheme.side_color(side)
	var dir: float = -1.0 if side == GameMap.Side.PLAYER else 1.0
	var inner: float = mid + dir * (CLOCK_W * 0.5 + 10.0)
	var outer: float = mid + dir * (BAR_SIZE.x * 0.5 - 12.0)
	var span: float = absf(outer - inner)
	var left: float = minf(inner, outer)
	# Score next to the clock.
	var score_align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if side == GameMap.Side.PLAYER else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(UiTheme.stencil(700), Vector2(left, 32.0), str(_score[side]), score_align, span, 28, color)
	# Name and one pip per point held at the outer end.
	var name_align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if side == GameMap.Side.PLAYER else HORIZONTAL_ALIGNMENT_RIGHT
	draw_string(UiTheme.text_font(), Vector2(left, 22.0), "我方" if side == GameMap.Side.PLAYER else "敵方", name_align, span, 14, UiTheme.TEXT)
	for i: int in _points[side]:
		var cx: float = outer - dir * (6.0 + i * 13.0)
		draw_colored_polygon(_diamond(Vector2(cx - dir * 34.0, 17.0), 5.0), color)
	# Track.
	var track: Rect2 = Rect2(left, 40.0, span, TRACK_H)
	draw_rect(track, Color(color, 0.15))
	var t: float = clampf(float(_score[side]) / float(_goal), 0.0, 1.0) if _goal > 0 else 0.0
	var fill_w: float = span * t
	draw_rect(Rect2(inner - fill_w if side == GameMap.Side.PLAYER else inner, 40.0, fill_w, TRACK_H), color)
	# Quarter ticks so the race reads at a glance.
	for q: int in range(1, 4):
		var x: float = inner + dir * span * q * 0.25
		draw_line(Vector2(x, 40.0), Vector2(x, 40.0 + TRACK_H), Color(UiTheme.GRAPHITE, 0.9), 1.0)
	# HQ health.
	var hp_t: float = _hq[side] / _hq_max[side] if _hq_max[side] > 0.0 else 0.0
	draw_rect(Rect2(left, 54.0, span, 3.0), Color(color, 0.12))
	var hp_w: float = span * hp_t
	draw_rect(Rect2(outer if side == GameMap.Side.PLAYER else outer - hp_w, 54.0, hp_w, 3.0), Color(color, 0.7))


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
