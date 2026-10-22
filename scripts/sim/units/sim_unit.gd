class_name SimUnit
extends RefCounted
## One unit's simulation state. Positions are integer sub-cells
## (Simulation.SUBCELL per cell) so the state stays deterministic.

## Section 9 hold position: 4 s to dig in, 2 s to get out, no moving meanwhile.
enum Hold { NONE, ENTERING, HELD, LEAVING }
## Engineer work on a bridge (section 4.4): planting a charge or repairing.
enum Work { NONE, DEMOLISH, REPAIR }
## convoy_goal of a unit that is not a supply truck, and of one driving to its HQ.
const NOT_CONVOY: int = -2
const GOAL_HQ: int = -1

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
## At 0 organization the unit routs: it walks slowly away from the fight,
## takes no orders and does not fire until it rallies.
var routing: bool = false
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
## Card it was deployed from; empty for units placed by a scenario.
var card: StringName = &""
## Driving back to its spawn zone to leave the field (section 7 撤退);
## takes no other orders.
var retreating: bool = false
## Transport this infantry rides in, 0 when on foot. A passenger is not on
## the map: it does not move, shoot or get shot, but still counts as weight.
var carrier_id: int = 0
## Transport this infantry is walking to board, 0 for none.
var board_id: int = 0
## Ids of the units riding in this transport, in boarding order.
var passengers: PackedInt32Array = PackedInt32Array()
## Ticks left until the passengers are off, 0 when not unloading.
var unload_ticks: int = 0
## 運補車隊 truck: point index (map.pois) it drives to, GOAL_HQ for its HQ,
## NOT_CONVOY for every other unit. It takes no orders.
var convoy_goal: int = NOT_CONVOY
## Point it set out from.
var convoy_from: int = -1
## Cells driven so far; the pay-out grows with it.
var convoy_cells: float = 0.0
## Support effects on the unit: ticks of 主動防護系統 and 裝甲突擊 left, and
## the 附加裝甲 shield soaking up damage first.
var aps_ticks: int = 0
var boost_ticks: int = 0
var shield: float = 0.0
var work: Work = Work.NONE
var work_ticks: int = 0
var work_bridge: int = -1
## Tick the work started; a hit after it calls the work off.
var work_since: int = 0


func cell() -> Vector2i:
	return Vector2i(pos.x / Simulation.SUBCELL, pos.y / Simulation.SUBCELL)


func is_moving() -> bool:
	return path_index < path.size()


func is_alive() -> bool:
	return hp > 0.0


## False while riding in a transport.
func on_map() -> bool:
	return carrier_id == 0


func destination() -> Vector2i:
	return path[path.size() - 1] if not path.is_empty() else cell()


func clear_path() -> void:
	path = []
	path_index = 0


## Dug in: takes less damage and shoots further (also while getting out).
func is_held() -> bool:
	return hold == Hold.HELD or hold == Hold.LEAVING


## Held units, units digging in or out and buildings cannot move.
func can_move() -> bool:
	return hold == Hold.NONE and not type.structure


func is_convoy() -> bool:
	return convoy_goal != NOT_CONVOY


## Below half organization: fires and moves slower.
func is_suppressed() -> bool:
	return org < type.max_org * Simulation.SUPPRESSED_BELOW


func figures() -> int:
	return type.figures_at(hp)


## Share of full firepower left: one figure's worth per surviving figure.
func strength() -> float:
	return float(figures()) / float(type.figures)
