class_name ControlGroups
extends RefCounted
## AoE-style control groups: numbered lists of unit ids kept by the input
## layer. Presentation only; the simulation never sees groups.

## Two recalls of the same group within this many ms count as a double tap.
const DOUBLE_TAP_MS: int = 350

var _groups: Dictionary = {}  # int -> PackedInt32Array
var _last_group: int = -1
var _last_ms: int = -1000000


## Replaces group `n` with `ids` (empty clears it).
func store(n: int, ids: PackedInt32Array) -> void:
	if ids.is_empty():
		_groups.erase(n)
	else:
		_groups[n] = ids.duplicate()


## Ids in group `n` for which `alive` returns true; drops the rest for good.
func members(n: int, alive: Callable) -> PackedInt32Array:
	var kept: PackedInt32Array = PackedInt32Array()
	for id: int in _groups.get(n, PackedInt32Array()):
		if alive.call(id):
			kept.append(id)
	store(n, kept)
	return kept


## Records a recall of group `n` at `now_ms`; true when it is the second tap.
func tap(n: int, now_ms: int) -> bool:
	var double: bool = n == _last_group and now_ms - _last_ms <= DOUBLE_TAP_MS
	_last_group = -1 if double else n
	_last_ms = now_ms
	return double
