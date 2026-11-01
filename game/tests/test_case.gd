class_name TestCase
extends RefCounted
## Minimal base class for automated tests. Subclasses define `test_*` methods;
## assertions record failures instead of aborting so one run reports everything.
## Run with:  godot --headless --path . res://tests/test_runner.tscn

var failures: Array[String] = []
var _current: String = ""
## Scene tree access for integration tests that need to instantiate nodes.
var tree: SceneTree = null
## Temporary directory unique to this test class (cleaned by the runner).
var temp_dir: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_fail("expected true" + (": " + msg if msg != "" else ""))


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		_fail("expected false" + (": " + msg if msg != "" else ""))


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not DictUtil.deep_equal(actual, expected):
		_fail("expected %s, got %s%s" % [_fmt(expected), _fmt(actual), (" — " + msg if msg != "" else "")])


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if DictUtil.deep_equal(actual, unexpected):
		_fail("expected something other than %s%s" % [_fmt(unexpected), (" — " + msg if msg != "" else "")])


func assert_ok(r: OpResult, msg: String = "") -> void:
	if r == null:
		_fail("OpResult is null" + (": " + msg if msg != "" else ""))
	elif not r.ok:
		_fail("expected ok, got error '%s'%s" % [r.error, (" — " + msg if msg != "" else "")])


func assert_fail(r: OpResult, msg: String = "") -> void:
	if r == null or r.ok:
		_fail("expected failure" + (": " + msg if msg != "" else ""))


func _fail(text: String) -> void:
	failures.append("%s: %s" % [_current, text])


func _fmt(v: Variant) -> String:
	var s := str(v)
	return s if s.length() < 160 else s.substr(0, 157) + "..."


## Helper for tests: write arbitrary text to a path.
static func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


static func remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		remove_dir_recursive(path + "/" + sub)
	for f in d.get_files():
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)
