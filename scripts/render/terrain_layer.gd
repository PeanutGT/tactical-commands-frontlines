class_name TerrainLayer
extends Sprite2D
## Static ground layer. With ground pictures in the style pack it is drawn by
## `terrain.gdshader` from a one-texel-per-cell map; without them (the dev
## pack) terrain colours, height shading and contour lines are baked once
## into a texture.

const SHADER: Shader = preload("res://shaders/terrain.gdshader")

var _ground: Texture2DArray


func build(map: GameMap, style: StylePack) -> void:
	if style.terrain_textures.is_empty():
		_bake(map, style)
	else:
		_build_textured(map, style)


func _build_textured(map: GameMap, style: StylePack) -> void:
	var ground: PackedInt32Array = _ground_types(map)
	var cells: Image = Image.create_empty(map.width, map.height, false, Image.FORMAT_RGB8)
	for y: int in map.height:
		for x: int in map.width:
			var i: int = y * map.width + x
			var t: int = ground[i]
			var across: int = 1 if t == Terrain.Type.BRIDGE and _deck_runs_across(ground, map, x, y) else 0
			cells.set_pixel(x, y, Color8(t, map.elevation[i], across))
	texture = ImageTexture.create_from_image(cells)
	centered = false
	scale = Vector2(style.cell_px, style.cell_px)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _ground == null:
		_ground = _ground_array(style)
	var mat: ShaderMaterial = material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	var layers: PackedInt32Array = PackedInt32Array()
	var tints: PackedColorArray = PackedColorArray()
	for t: int in Terrain.COUNT:
		layers.append(style.terrain_layer[t])
		tints.append(style.terrain_tints[t])
	mat.set_shader_parameter("cells", texture)
	mat.set_shader_parameter("ground", _ground)
	mat.set_shader_parameter("map_size", Vector2(map.width, map.height))
	mat.set_shader_parameter("tile_cells", style.terrain_tile_cells)
	mat.set_shader_parameter("layer_of", layers)
	mat.set_shader_parameter("tint_of", tints)
	mat.set_shader_parameter("height_shade", PackedFloat32Array(style.height_shade))
	mat.set_shader_parameter("contour_color", style.contour)


## Ground pictures as one texture array, all converted to the same format.
static func _ground_array(style: StylePack) -> Texture2DArray:
	var images: Array[Image] = []
	for tex: Texture2D in style.terrain_textures:
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		images.append(img)
	var arr: Texture2DArray = Texture2DArray.new()
	arr.create_from_images(images)
	return arr


## Terrain type whose ground is painted in each cell: point-of-interest and
## HQ cells (shown by markers) take the most common passable type around
## them, so a point on a bridge is painted as bridge deck.
static func _ground_types(map: GameMap) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(map.terrain.size())
	for i: int in map.terrain.size():
		out[i] = map.terrain[i]
	for y: int in map.height:
		for x: int in map.width:
			var t: int = map.terrain[y * map.width + x]
			if t != Terrain.Type.POI and t != Terrain.Type.HQ:
				continue
			var best: int = Terrain.Type.PLAIN
			for r: int in range(1, 6):
				var count: Dictionary[int, int] = {}
				for dy: int in range(-r, r + 1):
					for dx: int in range(-r, r + 1):
						var c: Vector2i = Vector2i(x + dx, y + dy)
						if c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.height:
							continue
						var n: int = map.terrain[c.y * map.width + c.x]
						if n != Terrain.Type.POI and n != Terrain.Type.HQ and Terrain.INFANTRY_OK[n]:
							count[n] = count.get(n, 0) + 1
				if not count.is_empty():
					var most: int = -1
					for k: int in count:
						if count[k] > most:
							most = count[k]
							best = k
					break
			out[y * map.width + x] = best
	return out


## Whether the bridge at (x, y) carries traffic left-right: its run of bridge
## cells is longer across than up-down.
static func _deck_runs_across(ground: PackedInt32Array, map: GameMap, x: int, y: int) -> bool:
	return _run(ground, map, x, y, Vector2i(1, 0)) > _run(ground, map, x, y, Vector2i(0, 1))


static func _run(ground: PackedInt32Array, map: GameMap, x: int, y: int, step: Vector2i) -> int:
	var n: int = 1
	for dir: int in [-1, 1]:
		var c: Vector2i = Vector2i(x, y) + step * dir
		while c.x >= 0 and c.y >= 0 and c.x < map.width and c.y < map.height and ground[c.y * map.width + c.x] == Terrain.Type.BRIDGE:
			n += 1
			c += step * dir
	return n


func _bake(map: GameMap, style: StylePack) -> void:
	var s: int = style.cell_px
	var img: Image = Image.create_empty(map.width * s, map.height * s, false, Image.FORMAT_RGBA8)
	var radius: float = s * 0.32
	for y: int in map.height:
		for x: int in map.width:
			var i: int = y * map.width + x
			var t: int = map.terrain[i]
			var base: Color = style.terrain_colors[t]
			var origin: Vector2i = Vector2i(x * s, y * s)
			img.fill_rect(Rect2i(origin, Vector2i(s, s)), StylePack.shade(base, style.height_shade[map.elevation[i]]))
			match t:
				Terrain.Type.BUILDING:
					# Inset roof so adjacent buildings read as separate blocks.
					img.fill_rect(Rect2i(origin + Vector2i(2, 2), Vector2i(s - 4, s - 4)), StylePack.shade(base, 1.35))
				Terrain.Type.FOREST:
					_fill_disc(img, Vector2(origin) + Vector2(s, s) * 0.5, radius, StylePack.shade(base, 0.8))
				Terrain.Type.FORD:
					img.fill_rect(Rect2i(origin + Vector2i(0, s / 2 - 1), Vector2i(s, 2)), StylePack.shade(base, 1.2))

	# Contour lines wherever the height level changes.
	for y: int in map.height:
		for x: int in map.width:
			var e: int = map.elevation[y * map.width + x]
			if x + 1 < map.width and map.elevation[y * map.width + x + 1] != e:
				img.fill_rect(Rect2i((x + 1) * s - 1, y * s, 2, s), style.contour)
			if y + 1 < map.height and map.elevation[(y + 1) * map.width + x] != e:
				img.fill_rect(Rect2i(x * s, (y + 1) * s - 1, s, 2), style.contour)

	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func _fill_disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2: float = radius * radius
	for py: int in range(floori(center.y - radius), ceili(center.y + radius)):
		for px: int in range(floori(center.x - radius), ceili(center.x + radius)):
			if Vector2(px + 0.5, py + 0.5).distance_squared_to(center) <= r2:
				img.set_pixel(px, py, color)
