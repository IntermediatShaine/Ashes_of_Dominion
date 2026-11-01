extends TestCase
## Mandatory save tests (directive §8.5), each exercising the real
## SaveRepository against a temporary directory.

var repo: SaveRepository


func before_each() -> void:
	repo = SaveRepository.new(temp_dir + "/saves")


func test_fresh_save_creation() -> void:
	var save := TestFixtures.new_save()
	assert_false(repo.slot_exists(1))
	var r := repo.write(1, save)
	assert_ok(r)
	assert_true(FileAccess.file_exists(repo.primary_path(1)))
	assert_false(FileAccess.file_exists(repo.temp_path(1)), "temp file removed after promotion")
	assert_true(repo.slot_exists(1))
	assert_eq(DictUtil.get_int(save.meta, "slot"), 1)
	assert_eq(DictUtil.get_int(save.meta, "save_count"), 1)


func test_save_and_reload_equivalence() -> void:
	var save := TestFixtures.new_save(2024, "hard", "ashborn")
	save.character.morality = -33
	save.universe.home_settlement().resources["wood"] = 17
	save.universe.discover_landmark("cinder_pass")
	assert_ok(repo.write(2, save))
	var r := repo.load_slot(2)
	assert_ok(r)
	var loaded: SaveGame = r.value
	assert_eq(loaded.to_dict(), save.to_dict(), "round trip must be lossless")
	assert_eq(loaded.universe.world_seed, 2024)
	assert_eq(loaded.character.morality, -33)
	assert_eq(loaded.universe.home_settlement().resources["wood"], 17)
	assert_true(loaded.universe.is_landmark_discovered("cinder_pass"))
	assert_true(r.warnings.is_empty(), "no recovery needed")


func test_multiple_consecutive_saves_keep_backup() -> void:
	var save := TestFixtures.new_save()
	for i in range(1, 5):
		save.universe.current_day = i
		assert_ok(repo.write(1, save))
	assert_true(FileAccess.file_exists(repo.backup_path(1)))
	var latest := repo.load_slot(1)
	assert_ok(latest)
	assert_eq((latest.value as SaveGame).universe.current_day, 4)
	assert_eq(DictUtil.get_int((latest.value as SaveGame).meta, "save_count"), 4)
	# backup holds the previous version
	var bak_text := TestCase.read_text(repo.backup_path(1))
	var bak_data: Dictionary = JSON.parse_string(bak_text)
	assert_eq(DictUtil.get_int(bak_data["universe"], "current_day"), 3)


func test_invalid_save_rejected() -> void:
	TestCase.write_text(repo.primary_path(1), "{ this is not json")
	assert_fail(repo.load_slot(1), "garbage json")
	TestCase.write_text(repo.primary_path(1), JSON.stringify({"schema_version": 1, "meta": {}}))
	assert_fail(repo.load_slot(1), "missing sections")
	var save := TestFixtures.new_save()
	var d := save.to_dict()
	d["character"]["morality"] = 500
	TestCase.write_text(repo.primary_path(1), JSON.stringify(d))
	var r := repo.load_slot(1)
	assert_fail(r, "semantic validation")
	assert_true(r.error.contains("morality"), r.error)
	# Writing invalid in-memory state is refused too
	save.character.level = 0
	assert_fail(repo.write(1, save))


func test_recovery_from_corrupted_latest_with_valid_backup() -> void:
	var save := TestFixtures.new_save()
	save.universe.current_day = 7
	assert_ok(repo.write(1, save))
	save.universe.current_day = 8
	assert_ok(repo.write(1, save))
	# Corrupt the primary (simulated interrupted write / disk error)
	TestCase.write_text(repo.primary_path(1), "{\"schema_version\": 1, \"meta\": {}, \"character\": {}, \"universe\"")
	var r := repo.load_slot(1)
	assert_ok(r, "must recover from backup")
	assert_eq((r.value as SaveGame).universe.current_day, 7)
	assert_false(r.warnings.is_empty(), "recovery is reported")
	# A later successful write must not be blocked by the corrupt primary
	save.universe.current_day = 9
	assert_ok(repo.write(1, save))
	assert_eq((repo.load_slot(1).value as SaveGame).universe.current_day, 9)


func test_recovery_from_orphaned_temp_file() -> void:
	var save := TestFixtures.new_save()
	save.universe.current_day = 3
	save.refresh_meta(1)
	TestCase.write_text(repo.temp_path(1), JSON.stringify(save.to_dict()))
	var r := repo.load_slot(1)
	assert_ok(r)
	assert_eq((r.value as SaveGame).universe.current_day, 3)


func test_schema_version_handling() -> void:
	var save := TestFixtures.new_save()
	var d := save.to_dict()
	d["schema_version"] = 0
	assert_fail(SaveValidator.build_and_validate(d), "version 0")
	d["schema_version"] = SaveGame.SCHEMA_VERSION + 1
	assert_fail(SaveValidator.build_and_validate(d), "future version")
	d.erase("schema_version")
	assert_fail(SaveValidator.build_and_validate(d), "missing version")
	d["schema_version"] = SaveGame.SCHEMA_VERSION
	assert_ok(SaveValidator.build_and_validate(d))
	assert_eq((repo.load_slot(1)).ok, false, "empty slot reports failure, not crash")


func test_random_state_preserved() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(31))
	for i in 9:
		b.rng.stream("rewards").randf()
		b.rng.stream("combat").randf()
	# Persist (through JSON) the state after nine draws, then continue both.
	var loaded := TestFixtures.round_trip(b)
	var b2 := TestFixtures.bind(loaded)
	assert_eq(loaded.universe.rng_states["rewards"]["draws"], 9)
	for i in 5:
		assert_eq(b2.rng.stream("rewards").randi_range(0, 1 << 30), b.rng.stream("rewards").randi_range(0, 1 << 30))
		assert_eq(b2.rng.stream("combat").randi_range(0, 1 << 30), b.rng.stream("combat").randi_range(0, 1 << 30))
	# The untouched streams are identical too, and distinct from each other.
	assert_eq(b2.rng.stream("events").randi_range(0, 1 << 30), b.rng.stream("events").randi_range(0, 1 << 30))
	assert_ne(b.rng.stream("encounter").randi_range(0, 1 << 30), b.rng.stream("route").randi_range(0, 1 << 30))


func test_character_survives_simulated_universe_replacement() -> void:
	var save := TestFixtures.new_save(1)
	save.character.morality = 40
	save.character.level = 3
	save.character.persistent_lore.append("the_curse_spoke")
	var old_universe_id := save.universe.universe_id
	save.universe.home_settlement().resources["wood"] = 99
	save.universe.faction("crown_of_aurel").player_reputation = 77
	# Simulate the (not yet designed) transfer: replace the universe only.
	var d := DifficultyRules.from_preset("challenging", Content.table("difficulty"))
	var u2 := UniverseFactory.create(2, d.value, {"mist_enabled": true}, save.character, save.multiverse, Content)
	assert_ok(u2)
	save.universe = u2.value
	assert_ok(repo.write(1, save))
	var loaded: SaveGame = repo.load_slot(1).value
	assert_eq(loaded.character.morality, 40)
	assert_eq(loaded.character.level, 3)
	assert_eq(loaded.character.persistent_lore, ["the_curse_spoke"])
	assert_ne(loaded.universe.universe_id, old_universe_id)
	assert_eq(loaded.universe.home_settlement().resources["wood"], 6, "settlement resources do not carry over")
	assert_eq(loaded.universe.faction("crown_of_aurel").player_reputation, 10, "reputation is universe-bound")
	assert_eq(loaded.multiverse.universe_counter, 2)


func test_duplicate_transition_execution_prevented() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(7))
	TestFixtures.start_any_expedition(b)
	b.expeditions.collect_resource("res_1_1", "wood", 5)
	var day_before := b.save.universe.current_day
	var r := b.transitions.on_protagonist_defeated({"by": "test"})
	assert_ok(r)
	var outcome: Dictionary = r.value["outcome"]
	assert_eq(b.save.universe.death_count, 1)
	assert_eq(b.save.universe.active_expedition_id, "")
	assert_eq(b.save.multiverse.completed_transition_ids.size(), 1)
	assert_eq(b.save.multiverse.pending_transition, null)
	assert_eq(b.save.universe.threat_state["completed_expeditions"], 1)
	var day_after := b.save.universe.current_day
	assert_true(day_after > day_before)
	assert_eq(b.save.universe.home_settlement().resources["wood"], 6, "haul lost on defeat (configured)")
	# Re-executing the same transition is a no-op
	var again := b.transitions.execute_transition({"transition_id": outcome["transition_id"], "kind": TransitionService.TRANSITION_RESURRECTION, "payload": outcome})
	assert_ok(again)
	assert_true(again.value["already_completed"])
	assert_eq(b.save.universe.threat_state["completed_expeditions"], 1, "counter not incremented twice")
	assert_eq(b.save.universe.current_day, day_after)
	assert_eq(b.save.multiverse.completed_transition_ids.size(), 1)


func test_interrupted_transition_recovers_once_after_load() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(8))
	TestFixtures.start_any_expedition(b)
	var death_id := b.transitions.record_death()
	var outcome := b.transitions.resolve_resurrection(death_id)
	b.transitions.begin_transition(outcome)
	# "Crash" here: pending transition saved but never executed.
	assert_ok(repo.write(1, b.save))
	var loaded: SaveGame = repo.load_slot(1).value
	assert_true(loaded.multiverse.pending_transition is Dictionary)
	var b2 := TestFixtures.bind(loaded)
	var rec := b2.transitions.recover_pending()
	assert_ok(rec)
	assert_true(rec.value["recovered"])
	assert_eq(loaded.multiverse.pending_transition, null)
	assert_eq(loaded.universe.active_expedition_id, "")
	assert_eq(loaded.universe.threat_state["completed_expeditions"], 1)
	var rec2 := b2.transitions.recover_pending()
	assert_ok(rec2)
	assert_false(rec2.value["recovered"])
	assert_eq(loaded.universe.threat_state["completed_expeditions"], 1)


func test_resurrection_outcome_not_rerolled_after_load() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(9))
	TestFixtures.start_any_expedition(b)
	var death_id := b.transitions.record_death()
	var first := b.transitions.resolve_resurrection(death_id)
	assert_ok(repo.write(1, b.save))
	var loaded: SaveGame = repo.load_slot(1).value
	var b2 := TestFixtures.bind(loaded)
	var second := b2.transitions.resolve_resurrection(death_id)
	assert_eq(second, first, "stored outcome is returned verbatim")
	assert_eq(loaded.multiverse.resolved_resurrection_outcomes.size(), 1)
	# Even calling it many more times never creates another record
	for i in 5:
		b2.transitions.resolve_resurrection(death_id)
	assert_eq(loaded.multiverse.resolved_resurrection_outcomes.size(), 1)
	assert_eq(loaded.multiverse.id_counters.get("tr", 0), 1)


func test_slot_listing_and_delete() -> void:
	assert_ok(repo.write(3, TestFixtures.new_save()))
	var slots := repo.list_slots()
	assert_eq(slots[1], null)
	assert_true(slots[3] is Dictionary)
	assert_fail(repo.write(0, TestFixtures.new_save()), "slot 0 invalid")
	assert_fail(repo.write(SaveRepository.MAX_SLOTS + 1, TestFixtures.new_save()))
	assert_ok(repo.delete_slot(3))
	assert_false(repo.slot_exists(3))
