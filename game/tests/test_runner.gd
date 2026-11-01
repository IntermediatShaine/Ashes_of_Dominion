extends Node
## Discovers tests/**/test_*.gd, runs every `test_*` method and exits with
## code 0 (all passed) or 1 (failures / errors / content load errors).
##
##   godot --headless --path . res://tests/test_runner.tscn
##   godot --headless --path . res://tests/test_runner.tscn -- --filter=save
##
## Running as a scene (not with -s) means the autoloads are present, so
## integration tests can use Content and instantiate real scenes.

const TEST_DIRS := ["res://tests/unit", "res://tests/deterministic", "res://tests/persistence", "res://tests/integration"]
const TEMP_ROOT := "user://_test_tmp"

var _filter := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
	call_deferred("_run")


func _run() -> void:
	var exit_code := await run_all()
	get_tree().quit(exit_code)


func run_all() -> int:
	var total := 0
	var failed := 0
	var failure_lines: Array[String] = []
	print("=== Ashes of Dominion test run (Godot %s) ===" % Engine.get_version_info().get("string", "?"))
	if not Content.load_errors.is_empty():
		for e in Content.load_errors:
			failure_lines.append("CONTENT: " + e)
		failed += Content.load_errors.size()
	TestCase.remove_dir_recursive(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(TEMP_ROOT)
	var scripts := _discover()
	for path in scripts:
		if _filter != "" and not path.contains(_filter):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failure_lines.append("LOAD: cannot load/compile " + path)
			failed += 1
			continue
		var instance = script.new()
		if not (instance is TestCase):
			continue
		var tc: TestCase = instance
		tc.tree = get_tree()
		tc.temp_dir = TEMP_ROOT + "/" + path.get_file().get_basename()
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			if String(m["name"]).begins_with("test_"):
				methods.append(String(m["name"]))
		methods.sort()
		var file_failures := 0
		for method in methods:
			total += 1
			tc._current = "%s::%s" % [path.get_file(), method]
			var before := tc.failures.size()
			DirAccess.make_dir_recursive_absolute(tc.temp_dir)
			tc.before_each()
			await tc.call(method)
			tc.after_each()
			TestCase.remove_dir_recursive(tc.temp_dir)
			if tc.failures.size() > before:
				file_failures += 1
		failed += file_failures
		failure_lines.append_array(tc.failures)
		print("%-48s %3d tests  %s" % [path.replace("res://tests/", ""), methods.size(), "OK" if file_failures == 0 else "FAILED(%d)" % file_failures])
	print("")
	for line in failure_lines:
		print("FAIL " + line)
	print("=== %d tests, %d failed ===" % [total, failed])
	TestCase.remove_dir_recursive(TEMP_ROOT)
	return 0 if failed == 0 else 1


func _discover() -> Array[String]:
	var out: Array[String] = []
	for dir_path in TEST_DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with("test_") and f.ends_with(".gd"):
				out.append(dir_path + "/" + f)
	out.sort()
	return out
