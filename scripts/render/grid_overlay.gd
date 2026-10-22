class_name GridOverlay
extends Node2D
## Cell grid lines, toggled with G.

var _size: Vector2i = Vector2i.ZERO
var _cell_px: int = 16
var _color: Color = Color(0, 0, 0, 0.18)


func setup(map: GameMap, style: StylePack) -> void:
	_size = Vector2i(map.width, map.height)
	_cell_px = style.cell_px
	_color = style.grid
	queue_redraw()


func _draw() -> void:
	var w: float = _size.x * _cell_px
	var h: float = _size.y * _cell_px
	for x: int in _size.x + 1:
		draw_line(Vector2(x * _cell_px, 0), Vector2(x * _cell_px, h), _color)
	for y: int in _size.y + 1:
		draw_line(Vector2(0, y * _cell_px), Vector2(w, y * _cell_px), _color)
