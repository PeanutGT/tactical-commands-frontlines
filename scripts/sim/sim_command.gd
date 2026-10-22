class_name SimCommand
extends RefCounted
## A player or AI order. The simulation only changes through these, so a match
## is its seed plus the list of commands (section 3).

## HOLD toggles hold position; ATTACK is a force-attack on `target_unit`.
enum Kind { MOVE, STOP, ATTACK, HOLD }

var kind: Kind = Kind.STOP
var side: int = GameMap.Side.PLAYER
var unit_ids: PackedInt32Array = PackedInt32Array()
var target: Vector2i = Vector2i.ZERO
var target_unit: int = 0
## Tick the command runs on; set by Simulation.issue.
var tick: int = -1


static func move(p_side: int, ids: PackedInt32Array, cell: Vector2i) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.kind = Kind.MOVE
	c.side = p_side
	c.unit_ids = ids
	c.target = cell
	return c


static func stop(p_side: int, ids: PackedInt32Array) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.kind = Kind.STOP
	c.side = p_side
	c.unit_ids = ids
	return c


static func attack(p_side: int, ids: PackedInt32Array, target_id: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.kind = Kind.ATTACK
	c.side = p_side
	c.unit_ids = ids
	c.target_unit = target_id
	return c


static func hold(p_side: int, ids: PackedInt32Array) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.kind = Kind.HOLD
	c.side = p_side
	c.unit_ids = ids
	return c
