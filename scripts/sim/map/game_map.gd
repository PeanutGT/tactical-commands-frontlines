class_name GameMap
extends RefCounted
## A fully parsed, ready-to-simulate map. Integer grids only; nothing here
## touches nodes or rendering, so the simulation can read it deterministically.

enum Side { PLAYER, ENEMY }

var config: MapConfig
var width: int = 0
var height: int = 0
## Terrain.Type per cell, row-major.
var terrain: PackedByteArray = PackedByteArray()
## Height level 0..3 per cell, row-major.
var elevation: PackedByteArray = PackedByteArray()
var pois: Array[CellGroup] = []
var hqs: Array[CellGroup] = []
var bridges: Array[CellGroup] = []
## Largest spawn zone of each side; null when the map has none.
var player_spawn: CellGroup
var enemy_spawn: CellGroup
var unknown_colors: Array[MapParser.UnknownColor] = []


## Builds a map from map.json plus decoded RGBA8 pixels. `height_rgba` may be
## empty (no height PNG). Returns null and logs an error when sizes disagree.
static func build(p_config: MapConfig, terrain_rgba: PackedByteArray, p_width: int, p_height: int,
		height_rgba: PackedByteArray = PackedByteArray()) -> GameMap:
	if Vector2i(p_width, p_height) != p_config.size:
		push_error("%s: terrain is %dx%d, map.json says %dx%d" % [p_config.id, p_width, p_height, p_config.size.x, p_config.size.y])
		return null
	if not height_rgba.is_empty() and height_rgba.size() != terrain_rgba.size():
		push_error("%s: height map size does not match terrain %dx%d" % [p_config.id, p_width, p_height])
		return null

	var m: GameMap = GameMap.new()
	m.config = p_config
	m.width = p_width
	m.height = p_height
	var grid: MapParser.TerrainGrid = MapParser.parse_terrain(terrain_rgba, p_width, p_height)
	m.terrain = grid.terrain
	m.unknown_colors = grid.unknown_colors
	if height_rgba.is_empty():
		m.elevation.resize(p_width * p_height)
	else:
		m.elevation = MapParser.parse_height(height_rgba, p_width, p_height)

	m.player_spawn = m._largest(Terrain.Type.PLAYER_SPAWN)
	m.enemy_spawn = m._largest(Terrain.Type.ENEMY_SPAWN)
	m.pois = MapParser.group_cells(m.terrain, p_width, Terrain.Type.POI)
	# A POI on a bridge (the north and south bridges of 河城) is bridge deck too.
	var bridge_connectors: Array[int] = [Terrain.Type.POI]
	m.bridges = MapParser.group_cells(m.terrain, p_width, Terrain.Type.BRIDGE, bridge_connectors)
	# Section 4.1: an HQ belongs to whichever spawn zone it is closer to.
	m.hqs = MapParser.group_cells(m.terrain, p_width, Terrain.Type.HQ)
	for hq: CellGroup in m.hqs:
		var dp: float = INF if m.player_spawn == null else hq.center.distance_squared_to(m.player_spawn.center)
		var de: float = INF if m.enemy_spawn == null else hq.center.distance_squared_to(m.enemy_spawn.center)
		hq.owner = Side.PLAYER if dp <= de else Side.ENEMY
	return m


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func terrain_at(cell: Vector2i) -> int:
	return terrain[index_of(cell)]


func elevation_at(cell: Vector2i) -> int:
	return elevation[index_of(cell)]


func _largest(type: int) -> CellGroup:
	var best: CellGroup = null
	for g: CellGroup in MapParser.group_cells(terrain, width, type):
		if best == null or g.cells.size() > best.cells.size():
			best = g
	return best
