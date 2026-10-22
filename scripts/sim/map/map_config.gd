class_name MapConfig
extends RefCounted
## Contents of a map's map.json (design doc section 4.3).

var id: String = ""
var name: String = ""
var terrain_file: String = "terrain.png"
## Empty when the map has no height PNG (everything is height 0).
var height_file: String = ""
var size: Vector2i = Vector2i.ZERO
var meters_per_cell: float = 20.0
var weight_cap: int = 0
var deck_size: int = 0
var hand_size: int = 0
var start_supply: int = 0
var supply_cap: int = 0
var victory_points: int = 0
var time_limit_sec: int = 0
## Points each side holds from the start: the ones nearest its spawn zone.
var start_points: int = 0


static func from_dict(d: Dictionary) -> MapConfig:
	var c: MapConfig = MapConfig.new()
	var files: Dictionary = d.get("files", {})
	var sz: Dictionary = d.get("size", {})
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", c.id))
	c.terrain_file = str(files.get("terrain", "terrain.png"))
	var h: Variant = files.get("height")
	c.height_file = "" if h == null else str(h)
	c.size = Vector2i(int(sz.get("w", 0)), int(sz.get("h", 0)))
	c.meters_per_cell = float(d.get("metersPerCell", 20.0))
	c.weight_cap = int(d.get("weightCap", 0))
	c.deck_size = int(d.get("deckSize", 0))
	c.hand_size = int(d.get("handSize", 0))
	c.start_supply = int(d.get("startSupply", 0))
	c.supply_cap = int(d.get("supplyCap", 0))
	c.victory_points = int(d.get("victoryPoints", 0))
	c.time_limit_sec = int(d.get("timeLimitSec", 0))
	c.start_points = int(d.get("startPoints", 0))
	return c
