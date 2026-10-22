class_name TerrainLayer
extends Sprite2D
## Static ground layer: terrain colours, height shading and contour lines,
## baked once into a texture.


func build(map: GameMap, style: StylePack) -> void:
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
