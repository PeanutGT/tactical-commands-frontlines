class_name StylePack
extends Resource
## Art is looked up from a style pack so it can be swapped without touching
## the simulation (design doc section 3). `dev()` is the geometric placeholder.

@export var cell_px: int = 16
## Ground colour per Terrain.Type.
@export var terrain_colors: Array[Color] = []
## Brightness multiplier per height level 0..3.
@export var height_shade: Array[float] = [1.0, 1.0, 1.0, 1.0]
@export var contour: Color = Color.BLACK
@export var grid: Color = Color(0, 0, 0, 0.18)
@export var poi_ring: Color = Color.YELLOW
## HQ fill per GameMap.Side.
@export var hq_colors: Array[Color] = [Color.CYAN, Color.RED]
## Unit fill per GameMap.Side.
@export var unit_colors: Array[Color] = [Color.CYAN, Color.RED]
@export var unit_outline: Color = Color.BLACK
@export var selection: Color = Color.WHITE
@export var order_marker: Color = Color.GREEN
## Fog opacity over cells never seen, and over cells seen before but not now.
@export var fog_unexplored: float = 1.0
@export var fog_explored: float = 0.5
## Ground pictures, one per texture layer. Empty = flat `terrain_colors`.
@export var terrain_textures: Array[Texture2D] = []
## Texture layer per Terrain.Type, and the colour it is multiplied by.
@export var terrain_layer: Array[int] = []
@export var terrain_tints: Array[Color] = []
## Cells covered by one repeat of a ground picture.
@export var terrain_tile_cells: float = 8.0
## Unit pictures per UnitType.id (see UnitArt); types without one are drawn
## as dev shapes.
var unit_art: Dictionary[StringName, UnitArt] = {}


static func dev() -> StylePack:
	var s: StylePack = StylePack.new()
	s.cell_px = 16
	s.terrain_colors = [
		Color("7fa65a"),  # plain
		Color("3f6b3a"),  # forest
		Color("a7a59c"),  # road
		Color("3b6fa8"),  # water
		Color("3a3a40"),  # building
		Color("7fa65a"),  # POI: drawn as a ring on top
		Color("b45a50"),  # enemy spawn
		Color("4f8fb8"),  # player spawn
		Color("7fa65a"),  # HQ: drawn as a marker on top
		Color("8a6a4a"),  # bridge
		Color("6f9cbf"),  # ford
	]
	s.height_shade = [0.86, 0.96, 1.06, 1.16]
	s.contour = Color("1d2418")
	s.grid = Color(0, 0, 0, 0.18)
	s.poi_ring = Color("f2d04a")
	s.hq_colors = [Color("58b4e8"), Color("e8605a")]
	s.unit_colors = [Color("3d8fd6"), Color("d6473d")]
	s.unit_outline = Color("10140e")
	s.selection = Color("f4f8ea")
	s.order_marker = Color("9cf06a")
	s.fog_unexplored = 1.0
	s.fog_explored = 0.5
	return s


## First real pack (design doc section 3): painted ground and greyscale
## top-down unit pictures tinted per side.
static func nato() -> StylePack:
	var s: StylePack = dev()
	s.terrain_textures = [
		preload("res://art/terrain/plain.png"),
		preload("res://art/terrain/forest.png"),
		preload("res://art/terrain/road.png"),
		preload("res://art/terrain/water.png"),
		preload("res://art/terrain/building.png"),
		preload("res://art/terrain/bridge.png"),
		preload("res://art/terrain/ford.png"),
	]
	# Points of interest and the HQ are plain ground with markers on top;
	# spawn zones are road tinted towards their side's colour.
	s.terrain_layer = [0, 1, 2, 3, 4, 0, 2, 2, 0, 5, 6]
	var white: Color = Color.WHITE
	s.terrain_tints = [white, white, white, white, white, white,
		white.lerp(s.unit_colors[GameMap.Side.ENEMY], 0.3) * 1.15, white.lerp(s.unit_colors[GameMap.Side.PLAYER], 0.3) * 1.15,
		white, white, white]
	s.terrain_tile_cells = 8.0
	s.height_shade = [0.88, 0.97, 1.05, 1.13]
	s.contour = Color(0.08, 0.1, 0.06, 0.55)
	s.unit_art = UnitArt.load_all()
	return s


static func shade(c: Color, k: float) -> Color:
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), c.a)
