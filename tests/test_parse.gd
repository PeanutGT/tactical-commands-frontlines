extends TestCase

const W: Vector3i = Vector3i(255, 255, 255)
const K: Vector3i = Vector3i(0, 0, 0)
const G: Vector3i = Vector3i(0, 200, 0)


func test_classify_exact_palette_colours() -> void:
	check_eq(Terrain.nearest(0, 200, 255), Terrain.Type.PLAYER_SPAWN, "player spawn")
	check_eq(Terrain.nearest(120, 170, 200), Terrain.Type.FORD, "ford")
	check_eq(Terrain.nearest(160, 82, 45), Terrain.Type.BRIDGE, "bridge")


func test_classify_absorbs_noise() -> void:
	var t: int = Terrain.nearest(10, 190, 12)
	check_eq(t, Terrain.Type.PLAIN, "noisy green")
	check(Terrain.color_distance(t, 10, 190, 12) < 20.0, "noisy green is close")


func test_unknown_colours_are_listed() -> void:
	var rows: Array[String] = ["gx"]
	var grid: MapParser.TerrainGrid = MapParser.parse_terrain(rgba_from_rows(rows, {"g": G, "x": Vector3i(255, 140, 0)}), 2, 1)
	check_eq(grid.unknown_colors.size(), 1, "unknown count")
	check_eq(grid.unknown_colors[0].pos, Vector2i(1, 0), "unknown position")
	check_eq(grid.unknown_colors[0].rgb, Vector3i(255, 140, 0), "unknown rgb")
	check_eq(grid.terrain[0], Terrain.Type.PLAIN, "known cell")


func test_classify_height() -> void:
	check_eq([0, 85, 170, 255].map(Terrain.classify_height), [0, 1, 2, 3], "four levels")
	check_eq(Terrain.classify_height(100), 1, "100")
	check_eq(Terrain.classify_height(230), 3, "230")


func test_group_merges_adjacent_cells() -> void:
	var grid: PackedByteArray = PackedByteArray([
		1, 1, 0, 0,
		1, 1, 0, 1,
		0, 0, 0, 1,
	])
	var groups: Array[CellGroup] = MapParser.group_cells(grid, 4, 1)
	check_eq(groups.size(), 2, "group count")
	check_eq(groups[0].cells.size(), 4, "first group size")
	check_eq(groups[0].center, Vector2(1, 1), "first group centre")
	check_eq(groups[1].cells.size(), 2, "second group size")


func test_group_joins_through_connectors() -> void:
	var connectors: Array[int] = [5]
	var groups: Array[CellGroup] = MapParser.group_cells(PackedByteArray([9, 5, 9, 0]), 4, 9, connectors)
	check_eq(groups.size(), 1, "joined")
	check_eq(groups[0].cells.size(), 3, "includes connector")


func test_group_ignores_diagonals() -> void:
	check_eq(MapParser.group_cells(PackedByteArray([1, 0, 0, 1]), 2, 1).size(), 2, "diagonal")


func test_scale_bar() -> void:
	var rows: Array[String] = [
		"gggggggggg",
		"gkgggggggg",
		"wwwwwwwwww",
		"wkkkkkwwww",
		"wwwwwwwwww",
	]
	var bar: MapParser.ScaleBar = MapParser.measure_scale_bar(rgba_from_rows(rows, {"g": G, "k": K, "w": W}), 10, 5)
	check(bar != null, "bar found")
	if bar != null:
		check_eq([bar.margin_rows, bar.bar_cells, bar.meters_per_cell], [3, 5, 20.0], "bar")


func test_scale_bar_missing() -> void:
	var rows: Array[String] = ["gg", "gk"]
	check(MapParser.measure_scale_bar(rgba_from_rows(rows, {"g": G, "k": K}), 2, 2) == null, "no margin")


func test_crop_bottom() -> void:
	var rows: Array[String] = ["gg", "ww"]
	var cropped: PackedByteArray = MapParser.crop_bottom(rgba_from_rows(rows, {"g": G, "w": W}), 2, 2, 1)
	check_eq(cropped.size(), 8, "one row left")
	check_eq(MapParser.parse_terrain(cropped, 2, 1).terrain, PackedByteArray([Terrain.Type.PLAIN, Terrain.Type.PLAIN]), "plain row")


func test_downsample_majority() -> void:
	var grid: PackedByteArray = PackedByteArray([
		1, 1, 2, 2,
		1, 3, 2, 4,
		0, 0, 5, 5,
		0, 1, 5, 5,
	])
	check_eq(MapParser.downsample_majority(grid, 4, 2), PackedByteArray([1, 2, 0, 5]), "majority")
