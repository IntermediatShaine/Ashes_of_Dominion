class_name DiagnosticLog
extends RefCounted
## Local, opt-in diagnostics. No network activity, account IDs, player names,
## world seeds, paths, user text, or free-form error messages are collected.
## One log per application session (even if recording is toggled off/on).
## At most five JSONL files, each capped at 1 MiB, are kept on disk.

const MAX_LOGS: int = 5
const MAX_LOG_BYTES: int = 1048576
const EVENTS := [
	"session_started", "recording_resumed", "application_quit",
	"scene_main_menu", "scene_new_game", "scene_load_game", "scene_settings",
	"scene_settlement", "scene_world_map", "scene_exploration",
	"game_created", "game_loaded", "game_load_failed", "game_ended",
	"save_succeeded", "save_failed", "state_checked", "building_built",
	"expedition_started", "area_entered", "expedition_finished",
	"expedition_failed", "expedition_abandoned", "player_defeated",
	"resurrection_failed", "player_damaged", "enemy_defeated",
	"resource_collected", "decision_resolved", "decision_rejected",
]
const METRICS := ["slot", "errors", "elapsed_ms", "amount", "health", "xp", "enemies", "resources", "outcome"]

var _directory: String
var _max_logs: int
var _max_bytes: int
var _file: FileAccess = null
var _session_path: String = ""
var _bytes_written: int = 0
var _limit_reached: bool = false


func _init(directory: String = "user://telemetry", max_logs: int = MAX_LOGS, max_bytes: int = MAX_LOG_BYTES) -> void:
	_directory = directory
	_max_logs = maxi(1, max_logs)
	_max_bytes = maxi(1, max_bytes)


func is_enabled() -> bool:
	return _file != null


## Disabling closes the handle immediately; no new events are written.
## Re-enabling within the same application session appends to the same file.
func set_enabled(on: bool) -> OpResult:
	if not on:
		if _file != null:
			_file.flush()
			_file.close()
			_file = null
		return OpResult.success()
	if _file != null:
		return OpResult.success()
	if _session_path != "" and FileAccess.file_exists(_session_path):
		var existing := FileAccess.open(_session_path, FileAccess.READ_WRITE)
		if existing == null:
			return OpResult.failure("Cannot reopen diagnostic log (%s)" % error_string(FileAccess.get_open_error()))
		existing.seek_end()
		_file = existing
		_bytes_written = int(existing.get_position())
		record_event("recording_resumed")
		return OpResult.success()
	var mk := DirAccess.make_dir_recursive_absolute(_directory)
	if mk != OK:
		return OpResult.failure("Cannot create diagnostic log folder (%s)" % error_string(mk))
	# Monotonic filenames keep rotation correct through rapid restarts and
	# system clock changes. The newest retained file provides the high-water mark.
	var stamp := int(Time.get_unix_time_from_system() * 1000.0)
	var previous := log_paths()
	if not previous.is_empty():
		var newest_name: String = previous.back().get_file()
		stamp = maxi(stamp, newest_name.trim_prefix("session_").trim_suffix(".jsonl").to_int() + 1)
	var path := _directory.path_join("session_%016d.jsonl" % stamp)
	while FileAccess.file_exists(path):
		stamp += 1
		path = _directory.path_join("session_%016d.jsonl" % stamp)
	var created := FileAccess.open(path, FileAccess.WRITE)
	if created == null:
		return OpResult.failure("Cannot create diagnostic log (%s)" % error_string(FileAccess.get_open_error()))
	_file = created
	_session_path = path
	_bytes_written = 0
	_limit_reached = false
	record_event("session_started")
	_prune_old_logs()
	return OpResult.success()


## Only an allowlisted event and numeric/boolean metrics can reach the file.
## This prevents arbitrary gameplay strings and user-entered data leaking into logs.
func record_event(event_name: String, values: Dictionary = {}) -> void:
	if _file == null or _limit_reached or not EVENTS.has(event_name):
		return
	var metrics: Dictionary = {}
	for key in METRICS:
		if not values.has(key):
			continue
		var value: Variant = values[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_BOOL or typeof(value) == TYPE_FLOAT:
			metrics[key] = value
	var entry := {
		"utc": Time.get_datetime_string_from_system(true, true),
		"event": event_name,
	}
	if not metrics.is_empty():
		entry["metrics"] = metrics
	var line := JSON.stringify(entry)
	var byte_count := line.to_utf8_buffer().size() + 1
	if _bytes_written + byte_count > _max_bytes:
		_limit_reached = true
		return
	_file.store_line(line)
	_file.flush()
	_bytes_written += byte_count


func log_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(_directory)
	if dir == null:
		return paths
	for filename in dir.get_files():
		if filename.begins_with("session_") and filename.ends_with(".jsonl"):
			paths.append(_directory.path_join(filename))
	paths.sort()
	return paths


func clear_logs() -> OpResult:
	set_enabled(false)
	for path in log_paths():
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			return OpResult.failure("Cannot delete diagnostic log (%s)" % error_string(err))
	_session_path = ""
	_bytes_written = 0
	_limit_reached = false
	return OpResult.success()


func _prune_old_logs() -> void:
	var paths := log_paths()
	while paths.size() > _max_logs:
		var oldest := ""
		for path in paths:
			if path != _session_path:
				oldest = path
				break
		if oldest == "":
			break
		if DirAccess.remove_absolute(oldest) != OK:
			push_warning("Diagnostic log rotation could not remove an older log")
			break
		paths.erase(oldest)
