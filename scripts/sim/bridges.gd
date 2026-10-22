class_name Bridges
extends RefCounted
## Destructible bridges (section 4.4): durability per bridge, demolition
## charges and the ground they leave behind. A broken bridge turns into water
## until engineers repair it. Pure state; the simulation applies the effects
## on units and paths.

## Bridges this many cells or larger are 大橋 (starting value: 河城's north
## and south bridges have 91 and 52 cells, the two short ones 33 and 35).
const BIG_CELLS: int = 45
const BIG_HP: float = 1200.0
const SMALL_HP: float = 600.0
## Below half durability vehicles cross 30% slower.
const SLOW_BELOW: float = 0.5
const SLOW_SPEED: float = 0.7
## Units on a bridge when it goes down take this much and fall in.
const FALL_DAMAGE: float = 200.0
## Engineers: 8 s on the bridge to plant, 5 s fuse; 20 s and 3 supply to
## repair a broken one back to 30%.
const PLANT_TICKS: int = 8 * Simulation.TICK_RATE
const FUSE_TICKS: int = 5 * Simulation.TICK_RATE
const REPAIR_TICKS: int = 20 * Simulation.TICK_RATE
const REPAIR_COST: float = 3.0
const REPAIR_SHARE: float = 0.3
## Engineers this close to a broken bridge's cells can repair it.
const REPAIR_REACH_CELLS: int = 2

var map: GameMap
var hp: Array[float] = []
var max_hp: Array[float] = []
var broken: Array[bool] = []
## Charges planted and burning: [bridge index, ticks left].
var fuses: Array = []
## Bumped whenever a bridge breaks or is rebuilt, so the view can redraw.
var revision: int = 0

## Bridge index per cell, -1 for none.
var _at: PackedInt32Array = PackedInt32Array()
## Terrain each bridge cell had before it broke.
var _original: Array[PackedByteArray] = []


func _init(p_map: GameMap) -> void:
	map = p_map
	_at.resize(map.width * map.height)
	_at.fill(-1)
	for i: int in map.bridges.size():
		var b: CellGroup = map.bridges[i]
		var full: float = BIG_HP if b.cells.size() >= BIG_CELLS else SMALL_HP
		hp.append(full)
		max_hp.append(full)
		broken.append(false)
		var orig: PackedByteArray = PackedByteArray()
		for c: Vector2i in b.cells:
			_at[map.index_of(c)] = i
			orig.append(map.terrain_at(c))
		_original.append(orig)


## Bridge covering `cell` (standing or broken), or -1.
func at(cell: Vector2i) -> int:
	return _at[map.index_of(cell)] if map.in_bounds(cell) else -1


## Vehicles on this cell cross slowly.
func slows(cell: Vector2i) -> bool:
	var i: int = at(cell)
	return i >= 0 and not broken[i] and hp[i] < max_hp[i] * SLOW_BELOW


## Takes `amount` off bridge `i`; true when that brought it down.
func damage(i: int, amount: float) -> bool:
	if broken[i] or amount <= 0.0:
		return false
	hp[i] = maxf(0.0, hp[i] - amount)
	return hp[i] <= 0.0


## Turns bridge `i` into water.
func set_broken(i: int) -> void:
	broken[i] = true
	hp[i] = 0.0
	for c: Vector2i in map.bridges[i].cells:
		map.terrain[map.index_of(c)] = Terrain.Type.WATER
	fuses = fuses.filter(func(f: Array) -> bool: return f[0] != i)
	revision += 1


## Rebuilds bridge `i` at REPAIR_SHARE of its durability.
func rebuild(i: int) -> void:
	broken[i] = false
	hp[i] = max_hp[i] * REPAIR_SHARE
	var cells: Array[Vector2i] = map.bridges[i].cells
	for k: int in cells.size():
		map.terrain[map.index_of(cells[k])] = _original[i][k]
	revision += 1


## Counts burning charges down; returns the bridges whose charge went off.
func tick_fuses() -> Array[int]:
	var out: Array[int] = []
	var still: Array = []
	for f: Array in fuses:
		f[1] -= 1
		if f[1] <= 0:
			out.append(f[0])
		else:
			still.append(f)
	fuses = still
	return out


## A broken bridge with a cell within REPAIR_REACH_CELLS of `cell`, or -1.
func broken_near(cell: Vector2i) -> int:
	for y: int in range(-REPAIR_REACH_CELLS, REPAIR_REACH_CELLS + 1):
		for x: int in range(-REPAIR_REACH_CELLS, REPAIR_REACH_CELLS + 1):
			var i: int = at(cell + Vector2i(x, y))
			if i >= 0 and broken[i]:
				return i
	return -1
