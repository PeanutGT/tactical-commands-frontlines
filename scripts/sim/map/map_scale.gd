class_name MapScale
extends RefCounted
## Section 4.3: unit stats are stored in metres and converted per map.
## Range, vision, speed and effect radius scale; HP, damage, cost, weight,
## cooldowns and supply do not. There is no minimum-range floor.

## The doc's tables are written for 1 cell = 20 m.
const STANDARD_METERS_PER_CELL: float = 20.0


static func meters_to_cells(meters: float, meters_per_cell: float) -> float:
	return meters / meters_per_cell


## Doc table value (cells at 20 m/cell) to metres.
static func standard_cells_to_meters(cells: float) -> float:
	return cells * STANDARD_METERS_PER_CELL
