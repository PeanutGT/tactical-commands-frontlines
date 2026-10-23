class_name UnitArt
extends RefCounted
## Top-down pictures of one kind of unit: greyscale, facing up, drawn in a
## SIZE × SIZE box and tinted with the side's colour. Points are in that box.
## Sources: `art/units/` (made by `gen_units.py`).

const SIZE: float = 64.0

## Whole unit, or the hull when the turret is a separate picture.
var body: Texture2D
var turret: Texture2D
var wreck: Texture2D
## Point the turret turns around.
var pivot: Vector2 = Vector2(32, 32)
## Where shots leave, with the turret pointing up.
var muzzle: Vector2 = Vector2(32, 4)
## Track runs, for the scrolling track pattern; empty on wheels and legs.
var tracks: Array[Rect2] = []
var infantry: bool = false

## Picture name, turret pivot, muzzle, tracks [x1, x2, top, bottom, width],
## scale (the generator scales some pictures about the centre).
const PICTURES: Dictionary = {
	&"infantry": [null, Vector2(40, 12), [], 1.4],
	&"mbt": [Vector2(32, 35), Vector2(32, 2), [13, 45, 8, 58, 6], 1.0],
	&"heavy_tank": [Vector2(32, 35), Vector2(32, 0), [9, 49, 6, 60, 7], 1.0],
	&"light_tank": [Vector2(32, 34), Vector2(32, 8), [18, 40, 16, 52, 5], 1.15],
	&"tank_destroyer": [null, Vector2(32, -2), [14, 44, 10, 58, 6], 1.0],
	&"ifv": [Vector2(30, 30), Vector2(30, 6), [], 1.0],
	&"apc": [Vector2(37, 26), Vector2(37, 18), [15, 43, 10, 56, 6], 1.0],
	&"recon": [Vector2(32, 32), Vector2(32, 22), [], 1.2],
	&"spg": [Vector2(32, 41), Vector2(32, -2), [14, 44, 10, 60, 6], 1.0],
	&"mlrs": [null, Vector2(32, 26), [], 1.0],
	&"aa": [Vector2(32, 32), Vector2(32, 6), [14, 44, 10, 58, 6], 1.0],
	&"truck": [null, Vector2(32, 8), [], 1.0],
	&"engineer": [null, Vector2(32, 8), [13, 45, 8, 58, 6], 1.0],
	&"recovery": [null, Vector2(32, 8), [13, 45, 8, 58, 6], 1.0],
}

## Picture used by each UnitType.id. Air units (M7) have none yet.
const OF_TYPE: Dictionary = {
	&"infantry": &"infantry", &"engineer": &"infantry", &"sf_recon": &"infantry",
	&"sniper": &"infantry", &"javelin": &"infantry", &"loitering": &"infantry",
	&"conscripts": &"infantry", &"bazooka": &"infantry", &"thermobaric": &"infantry",
	&"mech_infantry": &"infantry",
	&"scout_car": &"recon", &"apc": &"apc", &"tank": &"mbt", &"spg": &"spg",
	&"aa_vehicle": &"aa", &"ifv": &"ifv", &"heavy_tank": &"heavy_tank",
	&"breakthrough_tank": &"heavy_tank", &"mrl": &"mlrs", &"light_tank": &"light_tank",
	&"tank_destroyer": &"tank_destroyer", &"mortar": &"spg", &"bridge_layer": &"engineer",
	&"recovery_vehicle": &"recovery", &"supply_truck": &"truck",
}


## Pictures for every unit type that has one.
static func load_all() -> Dictionary[StringName, UnitArt]:
	var by_name: Dictionary[StringName, UnitArt] = {}
	for pic: StringName in PICTURES:
		by_name[pic] = _load(pic, PICTURES[pic])
	var out: Dictionary[StringName, UnitArt] = {}
	for type_id: StringName in OF_TYPE:
		out[type_id] = by_name[OF_TYPE[type_id]]
	return out


static func _load(pic: StringName, row: Array) -> UnitArt:
	var a: UnitArt = UnitArt.new()
	var path: String = "res://art/units/unit_%s" % pic
	var k: float = row[3]
	a.infantry = pic == &"infantry"
	a.muzzle = _scaled(row[1], k)
	if row[0] != null:
		a.body = load(path + "_hull.svg")
		a.turret = load(path + "_turret.svg")
		a.pivot = _scaled(row[0], k)
	else:
		a.body = load(path + ".svg")
		a.pivot = Vector2(32, 32)
	a.wreck = load(path + "_wreck.svg")
	var t: Array = row[2]
	if not t.is_empty():
		for x: float in [t[0], t[1]]:
			var tl: Vector2 = _scaled(Vector2(x, t[2]), k)
			var br: Vector2 = _scaled(Vector2(x + t[4], t[3]), k)
			a.tracks.append(Rect2(tl, br - tl))
	return a


static func _scaled(p: Vector2, k: float) -> Vector2:
	return Vector2(32, 32) + (p - Vector2(32, 32)) * k
