class_name UnitType
extends RefCounted
## Static stats of a unit kind. Distances are stored in metres (section 4.3)
## and converted per map by the simulation.

var id: StringName = &""
var display_name: String = ""
## Vehicles use the vehicle columns of the terrain table (no fords, slow in forest).
var vehicle: bool = false
var speed_mps: float = 0.0


func _init(p_id: StringName = &"", p_name: String = "", p_vehicle: bool = false, p_speed_mps: float = 0.0) -> void:
	id = p_id
	display_name = p_name
	vehicle = p_vehicle
	speed_mps = p_speed_mps


## Placeholder units for M2, speeds from the section 8 table (cells/s at 20 m/cell).
static func infantry() -> UnitType:
	return UnitType.new(&"infantry", "步兵班", false, MapScale.standard_cells_to_meters(1.5))


static func scout_car() -> UnitType:
	return UnitType.new(&"scout_car", "偵察車", true, MapScale.standard_cells_to_meters(3.5))


static func tank() -> UnitType:
	return UnitType.new(&"tank", "主戰坦克", true, MapScale.standard_cells_to_meters(2.0))
