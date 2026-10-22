extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 when any test fails.

const TEST_DIR: String = "res://tests"


func _initialize() -> void:
	var passed: int = 0
	var failed: int = 0
	for file: String in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR.path_join(file))
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.call(name)
			if t.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f: String in t.failures:
					printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
