extends TestCase
## End-to-end opt-in coverage using an isolated recorder and save repository.

var _previous_log: DiagnosticLog
var _previous_repository: SaveRepository
var _previous_settings: Dictionary


func before_each() -> void:
	_previous_log = Telemetry._log
	_previous_repository = Session.repository
	_previous_settings = Router.settings.duplicate(true)
	Telemetry._log = DiagnosticLog.new(temp_dir + "/telemetry")
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	Router.navigation_hook = func(_key: String): pass
	Router.settings["diagnostic_logging"] = false


func after_each() -> void:
	Session.end_session()
	Telemetry.set_enabled(false)
	Telemetry._log = _previous_log
	Session.repository = _previous_repository
	Router.navigation_hook = Callable()
	Router.settings = _previous_settings
	Router.save_settings()
	Router.apply_settings()
	tree.paused = false


func test_game_events_are_logged_only_while_opted_in() -> void:
	assert_false(Telemetry.is_enabled())
	assert_eq(Telemetry.log_paths().size(), 0)
	assert_ok(Router.set_diagnostic_logging(true))
	assert_true(Telemetry.is_enabled())
	var difficulty := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	assert_ok(difficulty)
	var created := Session.new_game({
		"name": "DoNotLogThisCharacterName",
		"archetype_id": "village_hunter",
		"difficulty": difficulty.value,
		"mist_enabled": true,
		"seed": 987654321,
	}, 1)
	assert_ok(created)
	Router.go("settlement")
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	var path := Telemetry.log_paths()[0]
	var recorded := read_text(path)
	assert_true(recorded.contains("session_started"))
	assert_true(recorded.contains("game_created"))
	assert_true(recorded.contains("game_loaded"))
	assert_true(recorded.contains("save_succeeded"))
	assert_true(recorded.contains("state_checked"))
	assert_true(recorded.contains("scene_settlement"))
	assert_false(recorded.contains("DoNotLogThisCharacterName"))
	assert_false(recorded.contains("987654321"), "world seed excluded")
	assert_ok(Router.set_diagnostic_logging(false))
	assert_false(Telemetry.is_enabled())
	assert_ok(Session.save_game(), "normal saves still work after opt-out")
	Router.go("world_map")
	assert_eq(read_text(path), recorded, "no event is recorded after opt-out")
