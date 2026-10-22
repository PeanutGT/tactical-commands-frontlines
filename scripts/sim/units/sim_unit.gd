class_name SimUnit
extends RefCounted
## One unit's simulation state. Positions are integer sub-cells
## (Simulation.SUBCELL per cell) so the state stays deterministic.

var id: int = 0
var type: UnitType
var side: int = GameMap.Side.PLAYER
var pos: Vector2i = Vector2i.ZERO
## Position at the start of the last tick; rendering interpolates from it.
var prev_pos: Vector2i = Vector2i.ZERO
## Cells still to walk through, in order; path[path_index] is the next one.
var path: Array[Vector2i] = []
var path_index: int = 0
## Cell the current leg started from (decides whether the leg is uphill).
var leg_from: Vector2i = Vector2i.ZERO


func cell() -> Vector2i:
	return Vector2i(pos.x / Simulation.SUBCELL, pos.y / Simulation.SUBCELL)


func is_moving() -> bool:
	return path_index < path.size()


func destination() -> Vector2i:
	return path[path.size() - 1] if not path.is_empty() else cell()


func clear_path() -> void:
	path = []
	path_index = 0
