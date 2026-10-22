class_name SimUnit
extends RefCounted
## One unit's simulation state. Positions are integer sub-cells
## (Simulation.SUBCELL per cell) so the state stays deterministic.

## Section 9 hold position: 4 s to dig in, 2 s to get out, no moving meanwhile.
enum Hold { NONE, ENTERING, HELD, LEAVING }

var id: int = 0
var type: UnitType
var side: int = GameMap.Side.PLAYER
var pos: Vector2i = Vector2i.ZERO
## Position at the start of the last tick; rendering interpolates from it.
var prev_pos: Vector2i = Vector2i.ZERO
## Waypoint cells still to walk to, in order; path[path_index] is the next one.
## Consecutive waypoints can be several cells apart (straight-line legs).
var path: Array[Vector2i] = []
var path_index: int = 0
var hp: float = 0.0
## Organization (組織度): drops under fire, recovers when left alone.
var org: float = 0.0
## At 0 organization the unit is pinned: no orders, no moving, no firing,
## until it rallies.
var pinned: bool = false
## Last tick the unit lost organization to fire, -1 for never.
var last_hit_tick: int = -1
## Ticks until the weapon can fire again.
var cooldown: int = 0
## Shots left in the current volley.
var burst_left: int = 0
## Unit currently shot at, 0 for none.
var target_id: int = 0
## Set by a force-attack order: chase and shoot this unit until it dies.
var forced_target: bool = false
## Cell the unit last pathed towards while chasing its forced target.
var chase_cell: Vector2i = Vector2i(-1, -1)
var hold: Hold = Hold.NONE
## Ticks left in ENTERING or LEAVING.
var hold_ticks: int = 0
## Move ordered while held; runs once the unit has left its position.
var pending_dest: Vector2i = Vector2i(-1, -1)


func cell() -> Vector2i:
	return Vector2i(pos.x / Simulation.SUBCELL, pos.y / Simulation.SUBCELL)


func is_moving() -> bool:
	return path_index < path.size()


func is_alive() -> bool:
	return hp > 0.0


func destination() -> Vector2i:
	return path[path.size() - 1] if not path.is_empty() else cell()


func clear_path() -> void:
	path = []
	path_index = 0


## Dug in: takes less damage and shoots further (also while getting out).
func is_held() -> bool:
	return hold == Hold.HELD or hold == Hold.LEAVING


## Held, pinned units and units digging in or out cannot move.
func can_move() -> bool:
	return hold == Hold.NONE and not pinned


## Below half organization: fires and moves slower.
func is_suppressed() -> bool:
	return org < type.max_org * Simulation.SUPPRESSED_BELOW


func figures() -> int:
	return type.figures_at(hp)
