class_name Formation
extends RefCounted
## Formation shapes for a move order: where each unit should end up around
## the clicked point. Input-layer helper; the simulation only gets ordinary
## per-unit move commands and does not keep the shape while driving.

enum Shape { NONE, LINE, WEDGE, COLUMN }

const NAMES: Dictionary = {
	Shape.NONE: "自由", Shape.LINE: "橫排", Shape.WEDGE: "三角", Shape.COLUMN: "縱列",
}
## Cells between neighbours in a formation.
const SPACING: float = 2.0


## Offsets in cells for `count` units, before rotation: x = right, y = forward.
## The first slot is the front (wedge tip, column head, line centre-left).
static func offsets(shape: Shape, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	match shape:
		Shape.LINE:
			for i: int in count:
				out.append(Vector2((float(i) - float(count - 1) * 0.5) * SPACING, 0.0))
		Shape.WEDGE:
			var row: int = 0
			while out.size() < count:
				var in_row: int = mini(row + 1, count - out.size())
				for j: int in in_row:
					out.append(Vector2((float(j) - float(in_row - 1) * 0.5) * SPACING, -float(row) * SPACING))
				row += 1
		Shape.COLUMN:
			for i: int in count:
				out.append(Vector2(0.0, -float(i) * SPACING))
		_:
			for i: int in count:
				out.append(Vector2.ZERO)
	return out


## Slot positions in cells around `center`, facing `forward` (any length).
static func slots(shape: Shape, count: int, center: Vector2, forward: Vector2) -> Array[Vector2]:
	var f: Vector2 = forward.normalized() if forward.length() > 0.001 else Vector2.UP
	var right: Vector2 = Vector2(-f.y, f.x)
	var out: Array[Vector2] = []
	for o: Vector2 in offsets(shape, count):
		out.append(center + right * o.x + f * o.y)
	return out


## For each unit position, the index of its slot. Both sets are compared
## around their own centres and the closest pairs are taken first, so units
## keep roughly their place in the group and paths rarely cross.
static func assign(units: Array[Vector2], slot_pos: Array[Vector2]) -> PackedInt32Array:
	var cu: Vector2 = _centre(units)
	var cs: Vector2 = _centre(slot_pos)
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(units.size())
	out.fill(-1)
	var taken: Array[bool] = []
	taken.resize(slot_pos.size())
	taken.fill(false)
	for _n: int in mini(units.size(), slot_pos.size()):
		var best_d: float = INF
		var best_u: int = -1
		var best_s: int = -1
		for u: int in units.size():
			if out[u] >= 0:
				continue
			for k: int in slot_pos.size():
				if taken[k]:
					continue
				var d: float = (units[u] - cu).distance_squared_to(slot_pos[k] - cs)
				if d < best_d:
					best_d = d
					best_u = u
					best_s = k
		out[best_u] = best_s
		taken[best_s] = true
	return out


static func _centre(points: Array[Vector2]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in points:
		sum += p
	return sum / float(maxi(points.size(), 1))
