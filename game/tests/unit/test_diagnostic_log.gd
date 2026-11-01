extends TestCase
## Privacy, retention, restart, and size-limit checks for the local recorder.


func _lines(path: String) -> Array:
	var parsed: Array = []
	for line in read_text(path).split("\n", false):
		var event = JSON.parse_string(line)
		assert_true(event is Dictionary, "each line is valid JSON")
		if event is Dictionary:
			parsed.append(event)
	return parsed


func test_off_by_default_creates_no_files() -> void:
	var dir := temp_dir + "/off"
	var log := DiagnosticLog.new(dir)
	assert_false(log.is_enabled())
	log.record_event("game_created", {"slot": 1})
	assert_false(DirAccess.dir_exists_absolute(dir), "no folder is created when off")
	assert_eq(log.log_paths().size(), 0)


func test_enable_disable_reenable_appends_without_tracking_while_off() -> void:
	var log := DiagnosticLog.new(temp_dir + "/toggle")
	assert_ok(log.set_enabled(true))
	log.record_event("game_created", {"slot": 2})
	assert_eq(log.log_paths().size(), 1)
	var path := log.log_paths()[0]
	assert_ok(log.set_enabled(false))
	assert_false(log.is_enabled())
	var before := read_text(path)
	log.record_event("save_succeeded", {"slot": 2})
	assert_eq(read_text(path), before, "no entries or writes while disabled")
	assert_ok(log.set_enabled(true))
	log.record_event("save_succeeded", {"slot": 2})
	assert_ok(log.set_enabled(false))
	assert_eq(log.log_paths().size(), 1, "toggle preserves one log per app run")
	var events := _lines(path)
	assert_eq(events.size(), 4, "start, create, resumed, saved")
	assert_eq(events[3]["event"], "save_succeeded")


func test_only_whitelisted_events_and_metrics_are_recorded() -> void:
	var log := DiagnosticLog.new(temp_dir + "/privacy")
	assert_ok(log.set_enabled(true))
	log.record_event("free_form", {"name": "secret"})
	log.record_event("game_loaded", {"slot": 1, "name": "secret", "path": "/private", "seed": 555})
	assert_ok(log.set_enabled(false))
	var path := log.log_paths()[0]
	var contents := read_text(path)
	assert_false(contents.contains("secret"))
	assert_false(contents.contains("/private"))
	assert_false(contents.contains("555"))
	var lines := _lines(path)
	assert_eq(lines.size(), 2)
	assert_eq(lines[1]["metrics"]["slot"], 1)


func test_retains_only_five_newest_logs_across_app_restarts() -> void:
	var dir := temp_dir + "/rotation"
	for i in 8:
		var instance := DiagnosticLog.new(dir)
		assert_ok(instance.set_enabled(true))
		instance.record_event("game_created", {"slot": i})
		assert_ok(instance.set_enabled(false))
	var listing := DiagnosticLog.new(dir).log_paths()
	assert_eq(listing.size(), 5)
	var found: Array[int] = []
	for path in listing:
		for event in _lines(path):
			if event["event"] == "game_created":
				found.append(int(event["metrics"]["slot"]))
	found.sort()
	assert_eq(found, [3, 4, 5, 6, 7], "oldest sessions rotated out")


func test_log_size_is_bounded_and_clearing_removes_all_logs() -> void:
	var log := DiagnosticLog.new(temp_dir + "/size", 5, 300)
	assert_ok(log.set_enabled(true))
	for i in 100:
		log.record_event("player_damaged", {"amount": 12345})
	assert_ok(log.set_enabled(false))
	assert_eq(log.log_paths().size(), 1)
	assert_true(FileAccess.get_file_as_bytes(log.log_paths()[0]).size() <= 300)
	assert_ok(log.clear_logs())
	assert_eq(log.log_paths().size(), 0)
