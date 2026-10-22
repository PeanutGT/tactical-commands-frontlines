class_name UnitType
extends RefCounted
## Static stats of a unit kind. Distances are stored in metres (section 4.3)
## and converted per map by the simulation.

## Section 8 unit classes; weapons have a damage multiplier per class.
enum Kind { INFANTRY, ARMOR }

var id: StringName = &""
var display_name: String = ""
var kind: Kind = Kind.INFANTRY
## Vehicles use the vehicle columns of the terrain table (no fords, slow in forest).
var vehicle: bool = false
var speed_mps: float = 0.0
var max_hp: float = 100.0
## Deployment weight; killing a friendly costs weight × 5 score (section 11).
var weight: int = 1
## Null for unarmed units.
var weapon: Weapon = null


func _init(p_id: StringName = &"", p_name: String = "", p_kind: Kind = Kind.INFANTRY, p_speed_mps: float = 0.0) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	vehicle = p_kind == Kind.ARMOR
	speed_mps = p_speed_mps


## Only infantry can hold position (section 9).
func can_hold() -> bool:
	return kind == Kind.INFANTRY


func _with(hp: float, p_weight: int, p_weapon: Weapon) -> UnitType:
	max_hp = hp
	weight = p_weight
	weapon = p_weapon
	return self


## Section 8 "通用" stats (cells at 20 m/cell). Cooldowns and the class
## multipliers are not in the doc; these are starting values to balance later.
static func infantry() -> UnitType:
	return UnitType.new(&"infantry", "步兵班", Kind.INFANTRY, MapScale.standard_cells_to_meters(1.5)) \
		._with(100.0, 2, Weapon.new(10.0, MapScale.standard_cells_to_meters(5.0), 1.0, 1.0, 0.1))


static func scout_car() -> UnitType:
	return UnitType.new(&"scout_car", "偵察車", Kind.ARMOR, MapScale.standard_cells_to_meters(3.5)) \
		._with(110.0, 2, Weapon.new(8.0, MapScale.standard_cells_to_meters(5.0), 0.5, 1.0, 0.3))


static func tank() -> UnitType:
	return UnitType.new(&"tank", "主戰坦克", Kind.ARMOR, MapScale.standard_cells_to_meters(2.0)) \
		._with(520.0, 5, Weapon.new(50.0, MapScale.standard_cells_to_meters(8.0), 3.0, 0.4, 1.0))


## Area weapon (section 8 自走迫擊砲); hits friendlies inside the blast too.
static func mortar() -> UnitType:
	var w: Weapon = Weapon.new(40.0, MapScale.standard_cells_to_meters(12.0), 4.0, 1.0, 0.5)
	w.splash_m = MapScale.standard_cells_to_meters(1.5)
	return UnitType.new(&"mortar", "自走迫擊砲", Kind.ARMOR, MapScale.standard_cells_to_meters(2.2))._with(160.0, 3, w)
