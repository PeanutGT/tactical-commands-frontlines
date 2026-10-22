class_name UnitLayer
extends Node2D
## Draws units as dev-style shapes (infantry = circle, vehicle = box pointing
## where it drives), interpolating between the last two simulation ticks.

const INFANTRY_RADIUS: float = 0.32  # cells
const VEHICLE_SIZE: Vector2 = Vector2(0.95, 0.6)  # cells, length × width

var sim: Simulation
## Fraction of the way from the last tick to the next one, 0..1.
var alpha: float = 0.0
var selected: Dictionary[int, bool] = {}

var _style: StylePack
## Last drawn heading per unit id, so a stopped vehicle keeps its facing.
var _heading: Dictionary[int, float] = {}


func setup(p_sim: Simulation, style: StylePack) -> void:
	sim = p_sim
	_style = style


## Interpolated position of a unit in world pixels.
func world_pos(u: SimUnit) -> Vector2:
	var p: Vector2 = Vector2(u.prev_pos).lerp(Vector2(u.pos), alpha)
	return p / float(Simulation.SUBCELL) * float(_style.cell_px)


## Rough radius in world pixels, used for clicking on a unit.
func pick_radius(u: SimUnit) -> float:
	var cells: float = VEHICLE_SIZE.x * 0.5 if u.type.vehicle else INFANTRY_RADIUS
	return maxf(cells, 0.4) * float(_style.cell_px)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var s: float = float(_style.cell_px)
	for u: SimUnit in sim.units:
		if selected.has(u.id) and u.is_moving():
			_draw_path(u, s)
	for u: SimUnit in sim.units:
		var p: Vector2 = world_pos(u)
		var fill: Color = _style.unit_colors[u.side]
		if u.type.vehicle:
			var moved: Vector2 = Vector2(u.pos - u.prev_pos)
			if moved != Vector2.ZERO:
				_heading[u.id] = moved.angle()
			draw_set_transform(p, _heading.get(u.id, 0.0))
			var size: Vector2 = VEHICLE_SIZE * s
			var body: Rect2 = Rect2(-size * 0.5, size)
			draw_rect(body, fill)
			draw_rect(body, _style.unit_outline, false, 1.5)
			# Nose mark shows the driving direction.
			draw_line(Vector2(size.x * 0.1, 0.0), Vector2(size.x * 0.5, 0.0), _style.unit_outline, 2.0)
			if u.type.id == &"tank":
				draw_circle(Vector2.ZERO, size.y * 0.3, _style.unit_outline, false, 1.5)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p, INFANTRY_RADIUS * s, fill)
			draw_circle(p, INFANTRY_RADIUS * s, _style.unit_outline, false, 1.5)
		if selected.has(u.id):
			draw_arc(p, pick_radius(u) + 3.0, 0.0, TAU, 24, _style.selection, 1.5, true)


func _draw_path(u: SimUnit, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([world_pos(u)])
	for i: int in range(u.path_index, u.path.size()):
		pts.append((Vector2(u.path[i]) + Vector2(0.5, 0.5)) * s)
	var c: Color = _style.order_marker
	c.a = 0.45
	draw_polyline(pts, c, 1.0)
