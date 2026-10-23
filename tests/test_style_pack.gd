extends TestCase
## The first real style pack: ground and unit pictures load and map onto the
## terrain and unit types.

## A bridge across a river with a point of interest on it.
const ROWS: Array[String] = [
	".....",
	"~~~~~",
	"bbybb",
	"~~~~~",
	".....",
]


func test_every_ground_unit_has_pictures() -> void:
	var art: Dictionary[StringName, UnitArt] = UnitArt.load_all()
	var types: Array[StringName] = UnitType.ids()
	types.append(&"supply_truck")
	for id: StringName in types:
		if id == &"supply_truck" or UnitType.of(id).kind != UnitType.Kind.AIR:
			check(art.has(id), "%s has pictures" % id)
	for a: UnitArt in art.values():
		check(a.body != null and a.wreck != null, "body and wreck load")
		check_eq(a.body.get_size(), Vector2(256, 256), "imported at 4x")


func test_nato_pack_layers() -> void:
	var s: StylePack = StylePack.nato()
	check_eq(s.terrain_layer.size(), Terrain.COUNT, "a layer per terrain type")
	check_eq(s.terrain_tints.size(), Terrain.COUNT, "a tint per terrain type")
	for layer: int in s.terrain_layer:
		check(layer >= 0 and layer < s.terrain_textures.size(), "layer %d exists" % layer)


func test_point_on_bridge_is_painted_as_deck() -> void:
	var map: GameMap = map_from_rows(ROWS)
	var ground: PackedInt32Array = TerrainLayer._ground_types(map)
	check_eq(ground[2 * 5 + 2], Terrain.Type.BRIDGE, "point cell takes the bridge around it")
	check(TerrainLayer._deck_runs_across(ground, map, 2, 2), "deck runs left-right")
