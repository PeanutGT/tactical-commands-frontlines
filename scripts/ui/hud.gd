class_name Hud
extends CanvasLayer
## Screen-space overlay: the tug-of-war score bar, the selection, the result
## banner, and (F10) map info, the cell under the cursor and the controls.
## Layout and the controls text live in hud.tscn.

const TERRAIN_NAMES: Array[String] = [
	"平地", "樹林", "道路", "水域", "建築", "據點", "敵方出兵區", "我方出兵區", "總部", "橋梁", "淺灘",
]
@onready var _info: Label = %Info
@onready var _help: Label = %Help
@onready var _hint: Label = %Hint
@onready var _score_bar: ScoreBar = %ScoreBar
@onready var _result: Label = %Result

var _map: GameMap
var _zoom: float = 1.0
var _cell: Vector2i = Vector2i(-1, -1)
var _selected: int = 0
var _score: Array[int] = [0, 0]
var _points: Array[int] = [0, 0]
var _penalty: int = 0
var _time_left: float = -1.0
var _hq_hp: Array[float] = [0.0, 0.0]
var _difficulty: String = ""
## F10 shows map info and the controls.
var _details: bool = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F10:
		return
	set_details(not _details)
	get_viewport().set_input_as_handled()


## Shows or hides map info and the controls list.
func set_details(on: bool) -> void:
	_details = on
	_help.visible = on
	_hint.visible = not on
	_refresh()


func show_map(map: GameMap) -> void:
	_map = map
	_refresh()


func set_zoom(zoom: float) -> void:
	_zoom = zoom
	_refresh()


## `cell` outside the map hides the cell line.
func set_cursor(cell: Vector2i) -> void:
	_cell = cell
	_refresh()


func set_selection(count: int) -> void:
	_selected = count
	_refresh()


## Score and points held per side (GameMap.Side), and the player's
## friendly-fire penalty.
func set_score(score: Array[int], points: Array[int], penalty: int) -> void:
	if score == _score and points == _points and penalty == _penalty:
		return
	_score = score.duplicate()
	_points = points.duplicate()
	_penalty = penalty
	_score_bar.set_score(score, points)
	_refresh()


func set_difficulty(name: String) -> void:
	_difficulty = name
	_score_bar.visible = true
	if _map != null:
		_score_bar.set_goal(_map.config.victory_points)
	_refresh()


## Seconds left (-1 for no limit) and each side's HQ health.
func set_match(time_left: float, hq_hp: Array[float]) -> void:
	if ceili(time_left) == ceili(_time_left) and hq_hp == _hq_hp:
		return
	_time_left = time_left
	_hq_hp = hq_hp.duplicate()
	_score_bar.set_match(time_left, hq_hp)
	_refresh()


## The match is over: a big banner in the middle of the screen, its top edge
## in the winner's colour (`winner` -1 for a draw).
func show_result(text: String, winner: int = -1) -> void:
	_result.text = text
	var box: StyleBoxFlat = _result.get_theme_stylebox("normal", "ResultBanner").duplicate() as StyleBoxFlat
	_result.add_theme_stylebox_override("normal", box)
	box.border_color = UiTheme.side_color(winner) if winner >= 0 else UiTheme.UNKNOWN
	_result.visible = true


func _refresh() -> void:
	if _map == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	if _difficulty != "":
		lines.append("AI %s｜誤傷扣分 %d" % [_difficulty, _penalty])
	if _selected > 0:
		lines.append("已選 %d 個單位" % _selected)
	if _details:
		var c: MapConfig = _map.config
		lines.append("%s  %d×%d 格｜%s 公尺/格｜縮放 %.2f" % [c.name, _map.width, _map.height, String.num(c.meters_per_cell), _zoom])
		if _map.in_bounds(_cell):
			lines.append("(%d, %d)  %s｜高度 %d" % [_cell.x, _cell.y, TERRAIN_NAMES[_map.terrain_at(_cell)], _map.elevation_at(_cell)])
		if _difficulty != "":
			lines.append("總部 我方 %d｜敵方 %d" % [ceili(_hq_hp[0]), ceili(_hq_hp[1])])
	_info.text = "\n".join(lines)
	_info.visible = not lines.is_empty()
