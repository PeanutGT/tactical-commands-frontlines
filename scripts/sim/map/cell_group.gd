class_name CellGroup
extends RefCounted
## A 4-connected group of cells (a point of interest, an HQ, a bridge...).

const NO_OWNER: int = -1

var id: int = 0
var cells: Array[Vector2i] = []
## Cell-space centroid; a 3x3 block whose middle cell is (5, 5) reports (5.5, 5.5).
var center: Vector2 = Vector2.ZERO
## GameMap.Side for HQs, NO_OWNER otherwise.
var owner: int = NO_OWNER


func bounds() -> Rect2i:
	var r: Rect2i = Rect2i(cells[0], Vector2i.ONE)
	for c: Vector2i in cells:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r
