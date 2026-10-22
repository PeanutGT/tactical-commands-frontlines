class_name Vision
extends RefCounted
## Fog of war and line of sight (sections 4.2 and 10), one view per side.
## Every cell is unexplored, explored (seen before) or visible now. Sight is
## traced along grid rays from each unit's cell: forest, buildings and HQs
## stop a ray (the blocking cell itself is still seen), and a cell in between
## that is higher than both the viewer and the cell looked at hides it (ridge).
## Pure grid state, recomputed by the simulation; drawing lives in the view.

enum Fog { UNEXPLORED, EXPLORED, VISIBLE }

## Section 4.2: each height level adds two cells of sight.
const HEIGHT_BONUS_CELLS: float = 2.0
## Section 10: a unit in forest is only seen from this close (ambush).
const FOREST_REVEAL_CELLS: float = 3.0
## Section 4.2: from two or more levels below, a unit is only seen this close.
const HIGH_GROUND_REVEAL_CELLS: float = 4.0
const HIGH_GROUND_LEVELS: int = 2
## The ground never changes, so what a cell sees is worked out once per sight
## radius and kept; the cache starts over past this many views.
const MAX_CACHED_VIEWS: int = 4096

var map: GameMap
## Fog per side (GameMap.Side), one Fog value per cell, row-major.
var fog: Array[PackedByteArray] = []
## Enemy unit ids each side can see right now.
var seen: Array[Dictionary] = [{}, {}]
## Bumped on every recompute, so the view knows when to redraw.
var revision: int = 0

## Cells lit by the last recompute, per side, to dim them on the next one.
var _lit: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
## Viewer serial number per cell; tells which cells the current viewer sees.
var _stamp: PackedInt32Array = PackedInt32Array()
var _serial: int = 0
## Cell indices seen from a cell: Vector3i(x, y, radius in 1/100 cells) -> PackedInt32Array.
var _views: Dictionary[Vector3i, PackedInt32Array] = {}
## Cells gathered by the trace in progress, and its own visited marks.
var _traced: PackedInt32Array = PackedInt32Array()
var _trace_mark: PackedInt32Array = PackedInt32Array()
var _trace_serial: int = 0


func _init(p_map: GameMap) -> void:
	map = p_map
	var n: int = map.width * map.height
	for s: int in 2:
		var f: PackedByteArray = PackedByteArray()
		f.resize(n)
		fog.append(f)
	_stamp.resize(n)
	_stamp.fill(0)
	_trace_mark.resize(n)
	_trace_mark.fill(0)


func fog_at(side: int, cell: Vector2i) -> Fog:
	return fog[side][map.index_of(cell)] as Fog


func cell_visible(side: int, cell: Vector2i) -> bool:
	return fog[side][map.index_of(cell)] == Fog.VISIBLE


## Own units are always known; enemies only while someone has eyes on them.
func sees(side: int, u: SimUnit) -> bool:
	return u.side == side or seen[side].has(u.id)


## Sight radius of `u` in cells on this map, high ground included.
func sight_cells(u: SimUnit) -> float:
	var mpc: float = map.config.meters_per_cell
	var bonus_m: float = MapScale.standard_cells_to_meters(HEIGHT_BONUS_CELLS) * map.elevation_at(u.cell())
	return MapScale.meters_to_cells(u.type.vision_m + bonus_m, mpc)


## Rebuilds both sides' views from the units on the map.
func update(units: Array[SimUnit]) -> void:
	revision += 1
	for side: int in 2:
		var f: PackedByteArray = fog[side]
		for i: int in _lit[side]:
			f[i] = Fog.EXPLORED
		_lit[side] = PackedInt32Array()
		seen[side] = {}
	for u: SimUnit in units:
		if not u.on_map() or not u.is_alive() or u.type.kind == UnitType.Kind.AIR:
			continue
		_serial += 1
		_cast(u)
		for t: SimUnit in units:
			if t.side != u.side and t.on_map() and t.is_alive() and not seen[u.side].has(t.id) and _spots(u, t):
				seen[u.side][t.id] = true


## Whether `viewer` picks out `t`: very close always; otherwise its cell must be
## in view, and forest or much higher ground hides it until close.
func _spots(viewer: SimUnit, t: SimUnit) -> bool:
	var d: float = Vector2(t.pos - viewer.pos).length() / Simulation.SUBCELL
	if d <= FOREST_REVEAL_CELLS:
		return true
	var c: Vector2i = t.cell()
	if _stamp[map.index_of(c)] != _serial:
		return false
	if map.terrain_at(c) == Terrain.Type.FOREST:
		return false
	if map.elevation_at(c) - map.elevation_at(viewer.cell()) >= HIGH_GROUND_LEVELS and d > HIGH_GROUND_REVEAL_CELLS:
		return false
	return true


## Lights every cell `u` can see and stamps them with the current viewer.
func _cast(u: SimUnit) -> void:
	var o: Vector2i = u.cell()
	var r: float = sight_cells(u)
	var key: Vector3i = Vector3i(o.x, o.y, roundi(r * 100.0))
	var cells: PackedInt32Array
	if _views.has(key):
		cells = _views[key]
	else:
		cells = _trace(o, r)
		if _views.size() >= MAX_CACHED_VIEWS:
			_views.clear()
		_views[key] = cells
	var f: PackedByteArray = fog[u.side]
	for i: int in cells:
		_stamp[i] = _serial
		if f[i] != Fog.VISIBLE:
			f[i] = Fog.VISIBLE
			_lit[u.side].append(i)


## Cells seen from `o` within `r` cells: rays to each cell on the edge of a
## square around it, walked outwards until they leave the sight circle or hit
## a blocker.
func _trace(o: Vector2i, r: float) -> PackedInt32Array:
	_trace_serial += 1
	_traced = PackedInt32Array()
	_mark(o)
	var r2: float = r * r
	var reach: int = ceili(r)
	var eo: int = map.elevation_at(o)
	for k: int in range(-reach, reach):
		_ray(o, eo, o + Vector2i(k, -reach), r2)
		_ray(o, eo, o + Vector2i(reach, k), r2)
		_ray(o, eo, o + Vector2i(-k, reach), r2)
		_ray(o, eo, o + Vector2i(-reach, -k), r2)
	return _traced


## Bresenham walk from `o` towards `to`.
func _ray(o: Vector2i, eo: int, to: Vector2i, r2: float) -> void:
	var dx: int = absi(to.x - o.x)
	var dy: int = -absi(to.y - o.y)
	var sx: int = 1 if to.x > o.x else -1
	var sy: int = 1 if to.y > o.y else -1
	var err: int = dx + dy
	var c: Vector2i = o
	## Highest cell passed so far, not counting the viewer's own.
	var ridge: int = -1
	while c != to:
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
		if not map.in_bounds(c) or float((c - o).length_squared()) > r2:
			return
		var ec: int = map.elevation_at(c)
		if ridge <= maxi(eo, ec):
			_mark(c)
		if Terrain.BLOCKS_SIGHT[map.terrain_at(c)]:
			return
		ridge = maxi(ridge, ec)


func _mark(c: Vector2i) -> void:
	var i: int = map.index_of(c)
	if _trace_mark[i] != _trace_serial:
		_trace_mark[i] = _trace_serial
		_traced.append(i)
