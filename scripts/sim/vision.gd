class_name Vision
extends RefCounted
## Fog of war and line of sight (sections 4.2 and 10), one view per side.
## Every cell is unexplored, explored (seen before) or visible now; a match
## starts with the whole map explored, so the ground is known but enemies are
## not. Sight is
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
## Unit sight is the card's vision times this (Peanut asked for longer sight).
const VISION_SCALE: float = 1.5
## Each HQ watches this far around its centre for its side (starting value).
const HQ_SIGHT_CELLS: float = 16.0
## A held point watches this far around its centre for its holder (starting value).
const POINT_SIGHT_CELLS: float = 10.0
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
## 煙霧彈 clouds over each cell (count), and the clouds as Vector3(x, y, radius)
## in cells. Smoke stops sight like forest and hides units inside it.
var smoke: PackedByteArray = PackedByteArray()
var smoke_zones: Array[Vector3] = []
## 無人機偵察 per side: Vector3(x, y, radius) in cells. A drone looks down,
## so it sees every cell in its circle; forest and smoke still hide units.
var drones: Array[Array] = [[], []]

## Cells lit by the last recompute, per side, to dim them on the next one.
var _lit: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
## Viewer serial number per cell; tells which cells the current viewer sees.
var _stamp: PackedInt32Array = PackedInt32Array()
var _serial: int = 0
## Cell indices seen from a cell: Vector3i(cell index, radius in 1/100
## cells, cells around the origin that do not block) -> PackedInt32Array.
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
		f.fill(Fog.EXPLORED)
		fog.append(f)
	_stamp.resize(n)
	_stamp.fill(0)
	_trace_mark.resize(n)
	_trace_mark.fill(0)
	smoke.resize(n)


func fog_at(side: int, cell: Vector2i) -> Fog:
	return fog[side][map.index_of(cell)] as Fog


func cell_visible(side: int, cell: Vector2i) -> bool:
	return fog[side][map.index_of(cell)] == Fog.VISIBLE


## Own units and buildings are always known; enemies only while someone has
## eyes on them.
func sees(side: int, u: SimUnit) -> bool:
	return u.side == side or u.type.structure or seen[side].has(u.id)


func add_smoke(centre: Vector2, r: float) -> void:
	smoke_zones.append(Vector3(centre.x, centre.y, r))
	for i: int in _disc(centre, r):
		smoke[i] += 1


func remove_smoke(centre: Vector2, r: float) -> void:
	smoke_zones.erase(Vector3(centre.x, centre.y, r))
	for i: int in _disc(centre, r):
		smoke[i] -= 1


func add_drone(side: int, centre: Vector2, r: float) -> void:
	drones[side].append(Vector3(centre.x, centre.y, r))


func remove_drone(side: int, centre: Vector2) -> void:
	for k: int in drones[side].size():
		var d: Vector3 = drones[side][k]
		if Vector2(d.x, d.y) == centre:
			drones[side].remove_at(k)
			return


## Cell indices whose centres lie within `r` of `centre`.
func _disc(centre: Vector2, r: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for y: int in range(floori(centre.y - r), ceili(centre.y + r) + 1):
		for x: int in range(floori(centre.x - r), ceili(centre.x + r) + 1):
			var c: Vector2i = Vector2i(x, y)
			if map.in_bounds(c) and (Vector2(c) + Vector2(0.5, 0.5)).distance_to(centre) <= r:
				out.append(map.index_of(c))
	return out


## Sight radius of `u` in cells on this map, high ground included.
func sight_cells(u: SimUnit) -> float:
	var mpc: float = map.config.meters_per_cell
	var bonus_m: float = MapScale.standard_cells_to_meters(HEIGHT_BONUS_CELLS) * map.elevation_at(u.cell())
	return MapScale.meters_to_cells(u.type.vision_m * VISION_SCALE + bonus_m, mpc)


## Rebuilds both sides' views from the units on the map, the HQs, the points
## each side holds (`poi_owner`, map.pois order) and drones.
func update(units: Array[SimUnit], poi_owner: Array[int] = []) -> void:
	revision += 1
	for side: int in 2:
		var f: PackedByteArray = fog[side]
		for i: int in _lit[side]:
			f[i] = Fog.EXPLORED
		_lit[side] = PackedInt32Array()
		seen[side] = {}
	for hq: CellGroup in map.hqs:
		_watch(hq.owner, _view(Vector2i(hq.center.floor()), HQ_SIGHT_CELLS, 1), units)
	for i: int in poi_owner.size():
		if poi_owner[i] != CellGroup.NO_OWNER:
			var p: CellGroup = map.pois[i]
			_watch(poi_owner[i], _view(Vector2i(p.center.floor()), POINT_SIGHT_CELLS, 0), units)
	for side: int in 2:
		for d: Vector3 in drones[side]:
			_watch(side, _disc(Vector2(d.x, d.y), d.z), units)
	for u: SimUnit in units:
		if not u.on_map() or not u.is_alive() or u.type.kind == UnitType.Kind.AIR or u.type.structure:
			continue
		_serial += 1
		_light_view(u.side, _view(u.cell(), sight_cells(u), 0))
		for t: SimUnit in units:
			if t.side != u.side and t.on_map() and t.is_alive() and not seen[u.side].has(t.id) and _spots(u, t):
				seen[u.side][t.id] = true


## A fixed lookout (HQ, held point, drone) lights `cells` for `side` and spots
## the enemies standing in them, except in forest or smoke.
func _watch(side: int, cells: PackedInt32Array, units: Array[SimUnit]) -> void:
	_serial += 1
	_light_view(side, cells)
	for t: SimUnit in units:
		if t.side == side or not t.on_map() or not t.is_alive():
			continue
		var i: int = map.index_of(t.cell())
		if _stamp[i] == _serial and map.terrain_at(t.cell()) != Terrain.Type.FOREST and smoke[i] == 0:
			seen[side][t.id] = true


## Whether `viewer` picks out `t`: very close always; otherwise its cell must be
## in view, and forest or much higher ground hides it until close.
func _spots(viewer: SimUnit, t: SimUnit) -> bool:
	var d: float = Vector2(t.pos - viewer.pos).length() / Simulation.SUBCELL
	if d <= FOREST_REVEAL_CELLS:
		return true
	var c: Vector2i = t.cell()
	if _stamp[map.index_of(c)] != _serial:
		return false
	if map.terrain_at(c) == Terrain.Type.FOREST or smoke[map.index_of(c)] > 0:
		return false
	if map.elevation_at(c) - map.elevation_at(viewer.cell()) >= HIGH_GROUND_LEVELS and d > HIGH_GROUND_REVEAL_CELLS:
		return false
	return true


## Cells seen from `o` within `r` cells, cached while no smoke is near.
## Blockers within `inner` cells of `o` (an HQ's own block) do not stop sight.
func _view(o: Vector2i, r: float, inner: int) -> PackedInt32Array:
	for z: Vector3 in smoke_zones:
		if Vector2(o).distance_to(Vector2(z.x, z.y)) <= r + z.z + 1.0:
			return _trace(o, r, inner)
	var key: Vector3i = Vector3i(map.index_of(o), roundi(r * 100.0), inner)
	if _views.has(key):
		return _views[key]
	var cells: PackedInt32Array = _trace(o, r, inner)
	if _views.size() >= MAX_CACHED_VIEWS:
		_views.clear()
	_views[key] = cells
	return cells


## Lights `cells` for `side` and stamps them with the current viewer.
func _light_view(side: int, cells: PackedInt32Array) -> void:
	var f: PackedByteArray = fog[side]
	for i: int in cells:
		_stamp[i] = _serial
		if f[i] != Fog.VISIBLE:
			f[i] = Fog.VISIBLE
			_lit[side].append(i)


## Rays to each cell on the edge of a square around `o`, walked outwards
## until they leave the sight circle or hit a blocker.
func _trace(o: Vector2i, r: float, inner: int) -> PackedInt32Array:
	_trace_serial += 1
	_traced = PackedInt32Array()
	_mark(o)
	var r2: float = r * r
	var reach: int = ceili(r)
	var eo: int = map.elevation_at(o)
	for k: int in range(-reach, reach):
		_ray(o, eo, o + Vector2i(k, -reach), r2, inner)
		_ray(o, eo, o + Vector2i(reach, k), r2, inner)
		_ray(o, eo, o + Vector2i(-k, reach), r2, inner)
		_ray(o, eo, o + Vector2i(-reach, -k), r2, inner)
	return _traced


## Bresenham walk from `o` towards `to`.
func _ray(o: Vector2i, eo: int, to: Vector2i, r2: float, inner: int) -> void:
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
		if (Terrain.BLOCKS_SIGHT[map.terrain_at(c)] or smoke[map.index_of(c)] > 0) and maxi(absi(c.x - o.x), absi(c.y - o.y)) > inner:
			return
		ridge = maxi(ridge, ec)


func _mark(c: Vector2i) -> void:
	var i: int = map.index_of(c)
	if _trace_mark[i] != _trace_serial:
		_trace_mark[i] = _trace_serial
		_traced.append(i)
