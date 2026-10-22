class_name Hud
extends CanvasLayer
## Screen-space debug overlay: map info, the cell under the cursor, controls.

const TERRAIN_NAMES: Array[String] = [
	"平地", "樹林", "道路", "水域", "建築", "據點", "敵方出兵區", "我方出兵區", "總部", "橋梁", "淺灘",
]
const HELP_TEXT: String = "左鍵選取／拖曳框選（Shift 加選）｜右鍵移動，點敵人攻擊｜Ctrl+右鍵強制攻擊｜H 駐守｜X 停止
滾輪縮放｜中鍵或空白鍵+左鍵拖曳平移｜WASD／方向鍵／邊緣捲動｜G 格線｜F 全圖"

@onready var _info: Label = $Info
@onready var _help: Label = $Help

var _map: GameMap
var _zoom: float = 1.0
var _cell: Vector2i = Vector2i(-1, -1)
var _selected: int = 0
var _score: int = 0
var _penalty: int = 0


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


func set_score(score: int, penalty: int) -> void:
	if score == _score and penalty == _penalty:
		return
	_score = score
	_penalty = penalty
	_refresh()


func _refresh() -> void:
	if _map == null:
		return
	var c: MapConfig = _map.config
	var text: String = "%s  %d×%d 格｜%s 公尺/格｜縮放 %.2f" % [c.name, _map.width, _map.height, String.num(c.meters_per_cell), _zoom]
	if _map.in_bounds(_cell):
		text += "\n(%d, %d)  %s｜高度 %d" % [_cell.x, _cell.y, TERRAIN_NAMES[_map.terrain_at(_cell)], _map.elevation_at(_cell)]
	text += "\n我方積分 %d｜誤傷扣分 %d" % [_score, _penalty]
	if _selected > 0:
		text += "
已選 %d 個單位" % _selected
	_info.text = text
