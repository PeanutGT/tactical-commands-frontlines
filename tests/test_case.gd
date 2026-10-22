class_name TestCase
extends RefCounted
## Minimal test base: every method named test_* is run by tests/run_tests.gd.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


## RGBA8 pixels from rows of palette keys, e.g. ["gx"] with {"g": Vector3i(0, 200, 0), ...}.
static func rgba_from_rows(rows: Array[String], palette: Dictionary) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for row: String in rows:
		for ch: String in row:
			var c: Vector3i = palette[ch]
			out.append_array(PackedByteArray([c.x, c.y, c.z, 255]))
	return out
