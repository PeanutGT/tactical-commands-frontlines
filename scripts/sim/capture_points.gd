class_name CapturePoints
extends RefCounted
## Points of interest changing hands (section 6): a side whose units stand
## alone on a point for 5 s takes it. Enemies there too pause the count;
## nobody there, or only the owner, resets it.

const CAPTURE_TICKS: int = 5 * Simulation.TICK_RATE
## Units this close to a point's centre count as on it (starting value).
const RADIUS_CELLS: float = 3.0

var map: GameMap
## GameMap.Side holding each point (map.pois order), or CellGroup.NO_OWNER.
var owner: Array[int] = []
## Side currently taking each point, or CellGroup.NO_OWNER.
var taker: Array[int] = []
## Ticks the taker has held each point uncontested so far.
var progress: Array[int] = []


func _init(p_map: GameMap) -> void:
	map = p_map
	for i: int in map.pois.size():
		owner.append(CellGroup.NO_OWNER)
		taker.append(CellGroup.NO_OWNER)
		progress.append(0)


func held_by(side: int) -> int:
	return owner.count(side)


## 0..1 of the way to taking point `i`.
func share(i: int) -> float:
	return float(progress[i]) / CAPTURE_TICKS


## Routing units, passengers, supply trucks and buildings neither take nor
## contest a point.
func update(units: Array[SimUnit]) -> void:
	var r: float = RADIUS_CELLS * Simulation.SUBCELL
	for i: int in map.pois.size():
		var centre: Vector2 = map.pois[i].center * Simulation.SUBCELL
		var present: Array[bool] = [false, false]
		for u: SimUnit in units:
			if u.on_map() and u.is_alive() and not u.routing and not u.is_convoy() and not u.type.structure \
					and Vector2(u.pos).distance_squared_to(centre) <= r * r:
				present[u.side] = true
		if present[0] and present[1]:
			continue
		var side: int = 0 if present[0] else (1 if present[1] else CellGroup.NO_OWNER)
		if side == CellGroup.NO_OWNER or side == owner[i]:
			taker[i] = CellGroup.NO_OWNER
			progress[i] = 0
			continue
		if taker[i] != side:
			taker[i] = side
			progress[i] = 0
		progress[i] += 1
		if progress[i] >= CAPTURE_TICKS:
			owner[i] = side
			taker[i] = CellGroup.NO_OWNER
			progress[i] = 0
