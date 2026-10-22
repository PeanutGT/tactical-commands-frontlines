class_name DistanceStats
extends RefCounted
## The unit stats that scale with the map (section 4.3). Metres (m/s for speed)
## or cells (cells/s), depending on which side of `to_map_cells` you are.

const NO_RADIUS: float = -1.0

var attack_range: float = 0.0
var vision: float = 0.0
var speed: float = 0.0
var radius: float = NO_RADIUS


func _init(p_attack_range: float = 0.0, p_vision: float = 0.0, p_speed: float = 0.0, p_radius: float = NO_RADIUS) -> void:
	attack_range = p_attack_range
	vision = p_vision
	speed = p_speed
	radius = p_radius


func to_map_cells(meters_per_cell: float) -> DistanceStats:
	var r: float = NO_RADIUS if radius == NO_RADIUS else MapScale.meters_to_cells(radius, meters_per_cell)
	return DistanceStats.new(
		MapScale.meters_to_cells(attack_range, meters_per_cell),
		MapScale.meters_to_cells(vision, meters_per_cell),
		MapScale.meters_to_cells(speed, meters_per_cell),
		r,
	)
