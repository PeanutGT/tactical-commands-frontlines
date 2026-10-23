extends TestCase


func test_line_is_centred_across_facing() -> void:
	var s: Array[Vector2] = Formation.slots(Formation.Shape.LINE, 3, Vector2(10, 10), Vector2(0, -5))
	check_eq(s, [Vector2(8, 10), Vector2(10, 10), Vector2(12, 10)] as Array[Vector2], "line facing up")


func test_wedge_tip_in_front() -> void:
	var o: Array[Vector2] = Formation.offsets(Formation.Shape.WEDGE, 4)
	check_eq(o, [Vector2(0, 0), Vector2(-1, -2), Vector2(1, -2), Vector2(0, -4)] as Array[Vector2], "1-2-1 wedge")


func test_column_trails_behind() -> void:
	var s: Array[Vector2] = Formation.slots(Formation.Shape.COLUMN, 3, Vector2(0, 0), Vector2(1, 0))
	check_eq(s, [Vector2(0, 0), Vector2(-2, 0), Vector2(-4, 0)] as Array[Vector2], "column facing right")


func test_assign_keeps_side_by_side_order() -> void:
	var units: Array[Vector2] = [Vector2(5, 0), Vector2(0, 0), Vector2(10, 0)]
	var slots: Array[Vector2] = [Vector2(50, 20), Vector2(40, 20), Vector2(60, 20)]
	check_eq(Formation.assign(units, slots), PackedInt32Array([0, 1, 2]), "left stays left")
