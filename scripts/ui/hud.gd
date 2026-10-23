class_name Hud
extends CanvasLayer
## Screen-space debug overlay: map info, the cell under the cursor, controls.

const TERRAIN_NAMES: Array[String] = [
	"平地", "樹林", "道路", "水域", "建築", "據點", "敵方出兵區", "我方出兵區", "總部", "橋梁", "淺灘",
]
const HELP_TEXT: String = "拖曳手牌到地圖出牌，或按 F1～F4 拿起卡再點地圖｜左鍵選取／拖曳框選（Shift 加選）｜右鍵移動，點敵人攻擊，點己方運兵車上車｜Ctrl+右鍵強制攻擊
Ctrl+1～9 存編組、1～9 叫出（連按兩下跳過去）｜Z 橫排／C 三角／V 縱列（再按一次取消）\nH 駐守｜X 停止｜R 撤退（退回一半費用）｜U 下車｜B 工兵炸橋／修橋｜滾輪縮放｜中鍵或空白鍵+左鍵拖曳平移｜WASD／方向鍵／邊緣捲動｜G 格線｜F 全圖"

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


func _ready() -> void:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans TC", "PingFang TC", "sans-serif"])
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.08, 0.05, 0.72)
	panel.set_content_margin_all(8.0)
	for label: Label in [_info, _help]:
		label.add_theme_font_override("font", font)
		label.add_theme_stylebox_override("normal", panel)
		label.add_theme_color_override("font_color", Color("e8ecdf"))
	_info.add_theme_font_size_override("font_size", 15)
	_help.add_theme_font_size_override("font_size", 13)
	_help.add_theme_color_override("font_color", Color("c4c9b8"))
	_help.text = HELP_TEXT
	_result = Label.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_theme_font_override("font", font)
	_result.add_theme_font_size_override("font_size", 40)
	var big: StyleBoxFlat = panel.duplicate()
	big.set_content_margin_all(28.0)
	_result.add_theme_stylebox_override("normal", big)
	_result.add_theme_color_override("font_color", Color("f4f8ea"))
	add_child(_result)


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
	_refresh()


func set_difficulty(name: String) -> void:
	_difficulty = name
	_refresh()


## Seconds left (-1 for no limit) and each side's HQ health.
func set_match(time_left: float, hq_hp: Array[float]) -> void:
	if ceili(time_left) == ceili(_time_left) and hq_hp == _hq_hp:
		return
	_time_left = time_left
	_hq_hp = hq_hp.duplicate()
	_refresh()


## The match is over: a big banner in the middle of the screen.
func show_result(text: String) -> void:
	_result.text = text
	_result.visible = true


func _refresh() -> void:
	if _map == null:
		return
	var c: MapConfig = _map.config
	var text: String = "%s  %d×%d 格｜%s 公尺/格｜縮放 %.2f" % [c.name, _map.width, _map.height, String.num(c.meters_per_cell), _zoom]
	if _map.in_bounds(_cell):
		text += "\n(%d, %d)  %s｜高度 %d" % [_cell.x, _cell.y, TERRAIN_NAMES[_map.terrain_at(_cell)], _map.elevation_at(_cell)]
	var goal: String = "／%d" % c.victory_points if c.victory_points > 0 else ""
	text += "\n積分 我方 %d%s（%d 據點）｜敵方 %d%s（%d 據點）｜誤傷扣分 %d" % [
		_score[GameMap.Side.PLAYER], goal, _points[GameMap.Side.PLAYER],
		_score[GameMap.Side.ENEMY], goal, _points[GameMap.Side.ENEMY], _penalty]
	if _difficulty != "":
		var clock: String = "%d:%02d" % [ceili(_time_left) / 60, ceili(_time_left) % 60] if _time_left >= 0.0 else "—"
		text += "\n剩餘時間 %s｜總部 我方 %d｜敵方 %d｜AI %s" % [clock, ceili(_hq_hp[0]), ceili(_hq_hp[1]), _difficulty]
	if _selected > 0:
		text += "\n已選 %d 個單位" % _selected
	_info.text = text
