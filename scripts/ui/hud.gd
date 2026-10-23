class_name Hud
extends CanvasLayer
## Screen-space overlay: the tug-of-war score bar, the selection, the result
## banner, and (F10) map info, the cell under the cursor and the controls.

const TERRAIN_NAMES: Array[String] = [
	"平地", "樹林", "道路", "水域", "建築", "據點", "敵方出兵區", "我方出兵區", "總部", "橋梁", "淺灘",
]
const HELP_TEXT: String = """出牌　拖曳手牌到地圖，或按 F1～F4 拿起卡再點地圖
選取　左鍵點選／拖曳框選，Shift 加選
移動　右鍵；點敵人攻擊；點己方運兵車上車
強制攻擊　Ctrl＋右鍵
編組　Ctrl＋1～9 存、1～9 叫出（連按兩下跳過去）
隊形　Z 橫排／C 三角／V 縱列（再按一次取消）
H 駐守　X 停止　R 撤退（退回一半費用）
U 下車　B 工兵炸橋／修橋
鏡頭　滾輪縮放；中鍵或空白鍵＋左鍵拖曳；WASD／方向鍵／邊緣捲動
G 格線　F 全圖　F10 收起說明"""

@onready var _info: Label = $Info
@onready var _help: Label = $Help

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
var _result: Label
var _score_bar: ScoreBar
var _hint: Label
## F10 shows map info and the controls.
var _details: bool = false


func _ready() -> void:
	var font: SystemFont = UiTheme.text_font()
	var panel: StyleBoxFlat = UiTheme.panel(UiTheme.GRAPHITE, UiTheme.EDGE, 1)
	panel.set_content_margin_all(8.0)
	for label: Label in [_info, _help]:
		label.add_theme_font_override("font", font)
		label.add_theme_stylebox_override("normal", panel)
		label.add_theme_color_override("font_color", UiTheme.TEXT)
	_info.add_theme_font_size_override("font_size", 14)
	_help.add_theme_font_size_override("font_size", 13)
	_help.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_help.text = HELP_TEXT
	_help.visible = false
	_help.add_theme_constant_override("line_spacing", 4)
	_help.offset_top = _help.offset_bottom
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_hint = Label.new()
	_hint.text = "F10 操作說明"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = 12.0
	_hint.offset_bottom = -12.0
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_hint.add_theme_stylebox_override("normal", panel)
	add_child(_hint)
	move_child(_hint, _help.get_index() + 1)

	_score_bar = ScoreBar.new()
	_score_bar.visible = false
	_score_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_bar.offset_left = -ScoreBar.BAR_SIZE.x * 0.5
	_score_bar.offset_right = ScoreBar.BAR_SIZE.x * 0.5
	_score_bar.offset_top = 10.0
	_score_bar.offset_bottom = 10.0 + ScoreBar.BAR_SIZE.y
	add_child(_score_bar)
	move_child(_score_bar, 0)

	_result = Label.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_theme_font_override("font", UiTheme.stencil(800))
	_result.add_theme_font_size_override("font_size", 44)
	var big: StyleBoxFlat = UiTheme.panel(Color(UiTheme.GRAPHITE, 0.96), UiTheme.EDGE, 1)
	big.set_content_margin_all(32.0)
	big.border_width_top = 6
	_result.add_theme_stylebox_override("normal", big)
	_result.add_theme_color_override("font_color", UiTheme.TEXT)
	add_child(_result)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F10:
		return
	_details = not _details
	_help.visible = _details
	_hint.visible = not _details
	_refresh()
	get_viewport().set_input_as_handled()


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
	var box: StyleBoxFlat = _result.get_theme_stylebox("normal") as StyleBoxFlat
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
