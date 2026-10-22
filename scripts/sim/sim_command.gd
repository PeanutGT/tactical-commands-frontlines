class_name SimCommand
extends RefCounted
## A player or AI order. The simulation only changes through these, so a match
## is its seed plus the list of commands (section 3).

## HOLD toggles hold position; ATTACK is a force-attack on `target_unit`.
## DEPLOY plays hand slot `slot` (which must still hold `card`) at `target`.
## LOAD sends infantry to board transport `target_unit`; UNLOAD empties the
## given transports; RETREAT drives units home for a half refund.
enum Kind { MOVE, STOP, ATTACK, HOLD, DEPLOY, RETREAT, LOAD, UNLOAD }

var kind: Kind = Kind.STOP
var side: int = GameMap.Side.PLAYER
var unit_ids: PackedInt32Array = PackedInt32Array()
var target: Vector2i = Vector2i.ZERO
var target_unit: int = 0
var slot: int = -1
var card: StringName = &""
## Tick the command runs on; set by Simulation.issue.
var tick: int = -1


static func _make(p_kind: Kind, p_side: int, ids: PackedInt32Array) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.kind = p_kind
	c.side = p_side
	c.unit_ids = ids
	return c


static func move(p_side: int, ids: PackedInt32Array, cell: Vector2i) -> SimCommand:
	var c: SimCommand = _make(Kind.MOVE, p_side, ids)
	c.target = cell
	return c


static func stop(p_side: int, ids: PackedInt32Array) -> SimCommand:
	return _make(Kind.STOP, p_side, ids)


static func attack(p_side: int, ids: PackedInt32Array, target_id: int) -> SimCommand:
	var c: SimCommand = _make(Kind.ATTACK, p_side, ids)
	c.target_unit = target_id
	return c


static func hold(p_side: int, ids: PackedInt32Array) -> SimCommand:
	return _make(Kind.HOLD, p_side, ids)


static func deploy(p_side: int, p_slot: int, p_card: StringName, cell: Vector2i) -> SimCommand:
	var c: SimCommand = _make(Kind.DEPLOY, p_side, PackedInt32Array())
	c.slot = p_slot
	c.card = p_card
	c.target = cell
	return c


static func retreat(p_side: int, ids: PackedInt32Array) -> SimCommand:
	return _make(Kind.RETREAT, p_side, ids)


static func board(p_side: int, ids: PackedInt32Array, transport_id: int) -> SimCommand:
	var c: SimCommand = _make(Kind.LOAD, p_side, ids)
	c.target_unit = transport_id
	return c


static func unload(p_side: int, ids: PackedInt32Array) -> SimCommand:
	return _make(Kind.UNLOAD, p_side, ids)
