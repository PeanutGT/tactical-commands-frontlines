class_name MapLoader
extends RefCounted
## Reads a map folder (map.json + PNGs) into a GameMap.
## New maps need each PNG set to import as "Image" (Import dock > Import As).


static func load_map(dir: String) -> GameMap:
	var json_path: String = dir.path_join("map.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error("%s: cannot read map.json" % json_path)
		return null
	var config: MapConfig = MapConfig.from_dict(parsed)

	var terrain_img: Image = _read_rgba(dir.path_join(config.terrain_file))
	if terrain_img == null:
		return null
	var height_data: PackedByteArray = PackedByteArray()
	if config.height_file != "":
		var height_img: Image = _read_rgba(dir.path_join(config.height_file))
		if height_img == null:
			return null
		height_data = height_img.get_data()
	return GameMap.build(config, terrain_img.get_data(), terrain_img.get_width(), terrain_img.get_height(), height_data)


## Map PNGs are imported as lossless Image resources (see their .import
## files), so this works both in the editor and in an exported build.
static func _read_rgba(path: String) -> Image:
	var res: Image = load(path) as Image
	if res == null or res.is_empty():
		push_error("%s: cannot load image (is it imported as Image?)" % path)
		return null
	var img: Image = res.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	return img
