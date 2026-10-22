class_name SimCommand
extends RefCounted
## A player or AI order. The simulation only changes through these, so a match
## is its seed plus the list of commands (section 3).

enum Kind { MOVE, STOP }

var kind: Kind = Kind.STOP
var side: int = GameMap.Side.PLAYER
var unit_ids: PackedInt32Array = PackedInt32Array()
var target: Vector2i = Vector2i.ZERO
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
