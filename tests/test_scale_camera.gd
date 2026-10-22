extends TestCase


func test_tank_range_doc_example() -> void:
	check_eq(MapScale.meters_to_cells(160.0, 20.0), 8.0, "20 m/cell")
	check_eq(MapScale.meters_to_cells(160.0, 10.0), 16.0, "10 m/cell")
	check_eq(MapScale.meters_to_cells(160.0, 40.0), 4.0, "40 m/cell")


func test_unit_stats_for_10m_map() -> void:
	var tank: DistanceStats = DistanceStats.new(
		MapScale.standard_cells_to_meters(8.0),
		MapScale.standard_cells_to_meters(8.0),
		MapScale.standard_cells_to_meters(2.0),
	)
	var c: DistanceStats = tank.to_map_cells(10.0)
	check_eq([c.attack_range, c.vision, c.speed, c.radius], [16.0, 16.0, 4.0, DistanceStats.NO_RADIUS], "converted")


func test_zoom_keeps_point_under_cursor() -> void:
	var view: Vector2 = Vector2(800, 600)
	var pos: Vector2 = Vector2(500, 400)
	var screen: Vector2 = Vector2(100, 450)
	var before: Vector2 = CameraMath.screen_to_world(pos, view, 1.0, screen)
	var next: Vector2 = CameraMath.position_for_zoom_at(pos, view, 1.0, 2.5, screen)
	check(CameraMath.screen_to_world(next, view, 2.5, screen).is_equal_approx(before), "fixed point")


func test_fit_and_clamp() -> void:
	check_eq(CameraMath.fit_zoom(Vector2(800, 600), Vector2(2048, 2048)), 600.0 / 2048.0, "fit")
	var world: Vector2 = Vector2(2048, 2048)
	# World smaller than the view on both axes: centred.
	check_eq(CameraMath.clamp_position(Vector2(0, 0), Vector2(800, 600), 0.1, world), Vector2(1024, 1024), "centred")
	# Zoomed in: cannot scroll past the top-left edge.
	check_eq(CameraMath.clamp_position(Vector2(0, 0), Vector2(800, 600), 1.0, world), Vector2(400, 300), "edge")
