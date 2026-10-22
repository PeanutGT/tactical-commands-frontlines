class_name MapParser
extends RefCounted
## Turns raw RGBA8 pixels into grids (design doc sections 4.1-4.3).
## Pure functions on PackedByteArray; no Image, no nodes, no I/O.


class UnknownColor:
	var pos: Vector2i
	var rgb: Vector3i

	func _init(p_pos: Vector2i, p_rgb: Vector3i) -> void:
		pos = p_pos
		rgb = p_rgb


class TerrainGrid:
	## Terrain.Type per cell, row-major.
	var terrain: PackedByteArray = PackedByteArray()
	var unknown_colors: Array[UnknownColor] = []


class ScaleBar:
	## Rows of white margin at the bottom of the image.
	var margin_rows: int = 0
	## Length of the 100 m black line, in cells.
	var bar_cells: int = 0
	var meters_per_cell: float = 0.0


## One pixel = one cell. Off-palette pixels snap to the nearest colour and are reported.
static func parse_terrain(rgba: PackedByteArray, width: int, height: int) -> TerrainGrid:
	var grid: TerrainGrid = TerrainGrid.new()
	grid.terrain.resize(width * height)
	for i: int in width * height:
		var r: int = rgba[i * 4]
		var g: int = rgba[i * 4 + 1]
		var b: int = rgba[i * 4 + 2]
		var t: int = Terrain.nearest(r, g, b)
		grid.terrain[i] = t
		if Terrain.color_distance(t, r, g, b) > Terrain.COLOR_TOLERANCE:
			grid.unknown_colors.append(UnknownColor.new(Vector2i(i % width, i / width), Vector3i(r, g, b)))
	return grid


## Grey (red channel) to height level 0..3.
static func parse_height(rgba: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(width * height)
	for i: int in width * height:
		out[i] = Terrain.classify_height(rgba[i * 4])
	return out


## 4-connected components of cells equal to `value`.
## `connectors` are values that join a group once reached from it (e.g. a POI
## painted on the middle of a bridge); they become part of the group.
static func group_cells(grid: PackedByteArray, width: int, value: int, connectors: Array[int] = []) -> Array[CellGroup]:
	var height: int = grid.size() / width
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(grid.size())
	var groups: Array[CellGroup] = []
	for start: int in grid.size():
		if grid[start] != value or seen[start] == 1:
			continue
		var group: CellGroup = CellGroup.new()
		group.id = groups.size()
		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var sum: Vector2i = Vector2i.ZERO
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x: int = i % width
			var y: int = i / width
			group.cells.append(Vector2i(x, y))
			sum += Vector2i(x, y)
			var next: PackedInt32Array = PackedInt32Array([
				i - 1 if x > 0 else -1,
				i + 1 if x < width - 1 else -1,
				i - width if y > 0 else -1,
				i + width if y < height - 1 else -1,
			])
			for n: int in next:
				if n >= 0 and seen[n] == 0 and (grid[n] == value or connectors.has(grid[n])):
					seen[n] = 1
					stack.append(n)
		group.center = Vector2(sum) / float(group.cells.size()) + Vector2(0.5, 0.5)
		groups.append(group)
	return groups


## Section 4.3: a white margin at the bottom holds a black line that is always 100 m.
## Returns null when the image has no such margin.
static func measure_scale_bar(rgba: PackedByteArray, width: int, height: int, bar_meters: float = 100.0) -> ScaleBar:
	var margin_rows: int = 0
	var bar_cells: int = 0
	for y: int in range(height - 1, -1, -1):
		var white: int = 0
		var run: int = 0
		var longest: int = 0
		var other: bool = false
		for x: int in width:
			var i: int = (y * width + x) * 4
			if _is_white(rgba, i):
				white += 1
				run = 0
			elif _is_black(rgba, i):
				run += 1
				longest = maxi(longest, run)
			else:
				other = true
				break
		if other or white < width / 2.0:
			break
		margin_rows += 1
		bar_cells = maxi(bar_cells, longest)
	if margin_rows == 0 or bar_cells == 0:
		return null
	var bar: ScaleBar = ScaleBar.new()
	bar.margin_rows = margin_rows
	bar.bar_cells = bar_cells
	bar.meters_per_cell = bar_meters / bar_cells
	return bar


## Drops `rows` rows from the bottom of an RGBA8 image.
static func crop_bottom(rgba: PackedByteArray, width: int, height: int, rows: int) -> PackedByteArray:
	return rgba.slice(0, width * (height - rows) * 4)


## Shrinks a grid by an integer factor, each output cell taking the most common
## value of its block (e.g. 1024x1024 generator output -> 128x128).
## Ties go to the lowest value so the result is deterministic.
## Returns an empty array when the size is not divisible by `factor`.
static func downsample_majority(grid: PackedByteArray, width: int, factor: int) -> PackedByteArray:
	var height: int = grid.size() / width
	if width % factor != 0 or height % factor != 0:
		push_error("%dx%d is not divisible by %d" % [width, height, factor])
		return PackedByteArray()
	var ow: int = width / factor
	var oh: int = height / factor
	var out: PackedByteArray = PackedByteArray()
	out.resize(ow * oh)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(256)
	for oy: int in oh:
		for ox: int in ow:
			counts.fill(0)
			for y: int in range(oy * factor, (oy + 1) * factor):
				for x: int in range(ox * factor, (ox + 1) * factor):
					counts[grid[y * width + x]] += 1
			var best: int = 0
			for v: int in range(1, 256):
				if counts[v] > counts[best]:
					best = v
			out[oy * ow + ox] = best
	return out


static func _is_white(d: PackedByteArray, i: int) -> bool:
	return d[i] > 200 and d[i + 1] > 200 and d[i + 2] > 200


static func _is_black(d: PackedByteArray, i: int) -> bool:
	return d[i] < 60 and d[i + 1] < 60 and d[i + 2] < 60
