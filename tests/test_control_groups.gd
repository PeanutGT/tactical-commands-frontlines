extends TestCase


func test_store_and_recall_drops_dead() -> void:
	var g: ControlGroups = ControlGroups.new()
	g.store(0, PackedInt32Array([3, 5, 7]))
	var alive: Callable = func(id: int) -> bool: return id != 5
	check_eq(g.members(0, alive), PackedInt32Array([3, 7]), "dead dropped")
	check_eq(g.members(0, func(_id: int) -> bool: return true), PackedInt32Array([3, 7]), "stays dropped")
	check_eq(g.members(1, alive), PackedInt32Array(), "unset group empty")


func test_empty_store_clears() -> void:
	var g: ControlGroups = ControlGroups.new()
	g.store(2, PackedInt32Array([1]))
	g.store(2, PackedInt32Array())
	check_eq(g.members(2, func(_id: int) -> bool: return true), PackedInt32Array(), "cleared")


func test_double_tap() -> void:
	var g: ControlGroups = ControlGroups.new()
	check(not g.tap(0, 1000), "first tap")
	check(g.tap(0, 1200), "second tap in time")
	check(not g.tap(0, 1300), "third tap starts over")
	check(not g.tap(1, 1400), "other group")
	check(not g.tap(0, 1500), "switching group resets")
	check(not g.tap(0, 2000), "too slow")
