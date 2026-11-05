extends TestCase
## Village progress through the real save path: upgrades, stockpiles, layout
## (which building stands on which site), residents, jobs in progress, the
## clock and the protagonist's location all survive write -> load, and a save
## written before the village existed (schema 1) migrates without losing or
## inventing anything.

const V1_FIXTURE := "res://tests/fixtures/save_schema1_main_eaadfdf.json"
const FULL_DAY := UniverseState.MINUTES_PER_DAY

var repo: SaveRepository


func before_each() -> void:
	repo = SaveRepository.new(temp_dir + "/saves")


func _played_save() -> SaveGame:
	var save := TestFixtures.new_save(3131)
	var svc := SettlementService.new(save, Content)
	var s := svc.state()
	s.base_storage_capacity = 1000
	s.resources = {"wood": 300, "stone": 300, "iron": 40, "food": 90}
	assert_ok(svc.request_construction("site_hearth", "village_hearth"))
	assert_ok(svc.request_construction("site_shelter", "shelter"))
	assert_ok(svc.request_construction("site_stockpile", "stockpile"))
	assert_ok(svc.request_construction("plot_3", "woodcutters_camp"))
	svc.advance_time(FULL_DAY)
	assert_ok(svc.request_upgrade(DictUtil.get_string(s.building_at_site("site_shelter"), "instance_id")))
	svc.advance_time(FULL_DAY + 75)
	assert_ok(svc.assign_idle_worker(DictUtil.get_string(s.building_at_site("plot_3"), "instance_id")))
	assert_ok(svc.damage_building(DictUtil.get_string(s.building_at_site("site_stockpile"), "instance_id"), 30, "storm"))
	# leave one job unfinished, with a builder on it
	assert_ok(svc.request_construction("site_watchpost", "watchpost"))
	assert_ok(svc.assign_idle_worker(DictUtil.get_string(s.job_at_site("site_watchpost"), "job_id")))
	s.pending_recruits = 1
	MapLocation.set_position(save.universe.location, Vector2(640.4, 512.6))
	return save


func test_village_progress_survives_save_and_load() -> void:
	var save := _played_save()
	var before := SettlementService.new(save, Content).snapshot()
	assert_ok(repo.write(1, save))
	var r := repo.load_slot(1)
	assert_ok(r)
	assert_true(r.warnings.is_empty(), "a current save needs no migration or recovery")
	var loaded: SaveGame = r.value
	assert_eq(loaded.to_dict(), save.to_dict(), "round trip must be lossless")
	var svc := SettlementService.new(loaded, Content)
	assert_eq(svc.normalize(), {"named": 0, "placed": 0, "released": 0}, "nothing to repair after loading")
	assert_eq(svc.snapshot(), before, "the loaded village is the saved village")
	# spot checks a player would notice
	var s := svc.state()
	assert_eq(s.resource_amount("wood"), save.universe.home_settlement().resource_amount("wood"))
	assert_eq(svc.inspect_site("site_shelter")["level"], 2, "the upgrade")
	assert_eq(svc.inspect_site("site_stockpile")["condition"], 70, "the damage")
	assert_eq(svc.inspect_site("plot_3")["definition_id"], "woodcutters_camp", "the layout change")
	assert_eq(svc.inspect_site("plot_3")["workers"].size(), 1)
	assert_eq(svc.inspect_site("site_watchpost")["state"], SiteRules.STATE_CONSTRUCTION)
	assert_eq(svc.inspect_site("site_watchpost")["job"]["builders"].size(), 1)
	assert_eq(s.population, 6)
	assert_eq(s.pending_recruits, 1)
	assert_eq(loaded.universe.current_day, 3)
	assert_eq(loaded.universe.time_of_day_minutes, 555)
	assert_eq(loaded.universe.location["map_id"], "village_emberfall")
	assert_eq(MapLocation.position(loaded.universe.location), Vector2(640, 513), "resume position, whole pixels")
	assert_eq(s.events.size(), save.universe.home_settlement().events.size())


func test_unfinished_job_continues_identically_after_reload() -> void:
	var uninterrupted := _played_save()
	var saved := _played_save()
	assert_ok(repo.write(1, saved))
	var reloaded: SaveGame = repo.load_slot(1).value
	for save in [uninterrupted, reloaded]:
		var svc := SettlementService.new(save, Content)
		svc.advance_time(FULL_DAY)
		assert_eq(svc.inspect_site("site_watchpost")["level"], 1)
		assert_eq(svc.state().construction_jobs.size(), 0)
	assert_eq(reloaded.universe.to_dict(), uninterrupted.universe.to_dict(), "saving in the middle of a job changes nothing")


func test_schema_1_save_migrates() -> void:
	var raw = JSON.parse_string(TestCase.read_text(V1_FIXTURE))
	assert_true(raw is Dictionary, "fixture is readable")
	assert_eq(DictUtil.get_int(raw, "schema_version"), 1, "the fixture really is a schema-1 save")
	var original: Dictionary = (raw as Dictionary).duplicate(true)
	var r := SaveValidator.build_and_validate(raw)
	assert_ok(r)
	assert_eq(r.warnings, ["Migrated save to schema 2"] as Array[String])
	assert_eq(raw, original, "migration works on a copy")
	var save: SaveGame = r.value
	assert_eq(save.schema_version, SaveGame.SCHEMA_VERSION)
	var u := save.universe
	var s := u.home_settlement()
	var old_u: Dictionary = original["universe"]
	var old_s: Dictionary = old_u["settlements"]["stl_emberfall"]
	# nothing that was in the old save is lost or changed
	assert_eq(save.character.to_dict(), SaveGame.from_dict(original).character.to_dict())
	assert_eq(save.multiverse.to_dict(), SaveGame.from_dict(original).multiverse.to_dict())
	assert_eq(u.current_day, DictUtil.get_int(old_u, "current_day"))
	assert_eq(str(u.world_seed), String(old_u["world_seed"]))
	assert_eq(u.rng_states, old_u["rng_states"])
	assert_eq(u.decision_log, old_u["decision_log"])
	assert_eq(u.expedition_history.size(), 1)
	assert_eq(u.threat_state, DictUtil.int_map(old_u["threat_state"]))
	assert_eq(s.resources, DictUtil.int_map(old_s["resources"]))
	assert_eq(s.morale, DictUtil.get_int(old_s, "morale"))
	assert_eq(s.population, DictUtil.get_int(old_s, "population"), "one resident per counted person")
	assert_eq(s.buildings.size(), 1)
	assert_eq(String(s.buildings[0]["instance_id"]), "bld_000001")
	assert_eq(String(s.buildings[0]["definition_id"]), "shelter")
	assert_eq(DictUtil.get_int(s.buildings[0], "built_day"), 1)
	# what the new format needs is filled with neutral values
	assert_eq(DictUtil.get_int(s.buildings[0], "level"), 1)
	assert_eq(DictUtil.get_int(s.buildings[0], "condition"), 100)
	assert_eq(u.time_of_day_minutes, 480)
	assert_eq(u.location, {"map_id": "village_emberfall", "entry_id": "spawn", "return_stack": []})
	assert_eq(s.construction_jobs.size(), 0)
	assert_eq(s.events.size(), 0)
	assert_eq(s.resident_counter, s.residents.size())
	assert_true(save.validate().is_empty(), "; ".join(save.validate()))
	# content-dependent parts are completed by normalize()
	assert_eq(String(s.buildings[0]["site_id"]), "")
	assert_eq(String(s.residents[0]["name"]), "")
	var svc := SettlementService.new(save, Content)
	assert_eq(svc.normalize(), {"named": 7, "placed": 1, "released": 0})
	assert_eq(String(s.buildings[0]["site_id"]), "site_shelter", "the old shelter stands on the shelter site")
	assert_eq(svc.inspect_site("site_shelter")["level"], 1)
	assert_eq(SettlementRules.population_capacity(s, Content.table("buildings")), s.base_population_capacity + 4, "same capacity as before the migration")
	for resident in s.residents:
		assert_true(String(resident["name"]) != "")
	assert_true(save.validate().is_empty(), "; ".join(save.validate()))
	# migrating twice from the same file gives the same people in the same places
	var again: SaveGame = SaveValidator.build_and_validate(JSON.parse_string(TestCase.read_text(V1_FIXTURE))).value
	SettlementService.new(again, Content).normalize()
	assert_eq(again.universe.to_dict(), u.to_dict(), "migration is deterministic")


func test_migrated_save_loads_from_disk_and_is_rewritten_as_schema_2() -> void:
	TestCase.write_text(repo.primary_path(2), TestCase.read_text(V1_FIXTURE))
	var r := repo.load_slot(2)
	assert_ok(r)
	assert_true(r.warnings.has("Migrated save to schema 2"), str(r.warnings))
	var save: SaveGame = r.value
	SettlementService.new(save, Content).normalize()
	# the game goes on: the migrated village can be built on
	var svc := SettlementService.new(save, Content)
	var hearth := svc.request_construction("site_hearth", "village_hearth")
	assert_ok(hearth)
	assert_eq(String(hearth.value["instance"]["instance_id"]), "bld_000002", "the universe id counter carried over")
	assert_ok(repo.write(2, save))
	var on_disk: Dictionary = JSON.parse_string(TestCase.read_text(repo.primary_path(2)))
	assert_eq(DictUtil.get_int(on_disk, "schema_version"), 2)
	assert_false((on_disk["universe"]["settlements"]["stl_emberfall"] as Dictionary).has("population"), "population is no longer stored separately")
	var bak: Dictionary = JSON.parse_string(TestCase.read_text(repo.backup_path(2)))
	assert_eq(DictUtil.get_int(bak, "schema_version"), 1, "the original stays as the backup")
	var second := repo.load_slot(2)
	assert_ok(second)
	assert_true(second.warnings.is_empty(), "no second migration")
	assert_eq((second.value as SaveGame).to_dict(), save.to_dict())


func test_invalid_village_state_is_rejected() -> void:
	var cases := {
		"two buildings on one site": func(d: Dictionary): d["buildings"][1]["site_id"] = d["buildings"][0]["site_id"],
		"condition above 100": func(d: Dictionary): d["buildings"][0]["condition"] = 140,
		"level 0": func(d: Dictionary): d["buildings"][0]["level"] = 0,
		"duplicate instance id": func(d: Dictionary): d["buildings"][1]["instance_id"] = d["buildings"][0]["instance_id"],
		"resident assigned to nothing that exists": func(d: Dictionary): d["residents"][0]["assigned_to"] = "bld_999999",
		"duplicate resident id": func(d: Dictionary): d["residents"][1]["resident_id"] = d["residents"][0]["resident_id"],
		"job already finished": func(d: Dictionary): d["construction_jobs"][0]["work_done"] = 5,
		"job of unknown kind": func(d: Dictionary): d["construction_jobs"][0]["kind"] = "demolish",
		"build job on an occupied site": func(d: Dictionary): d["construction_jobs"][0]["site_id"] = d["buildings"][0]["site_id"],
		"negative resource": func(d: Dictionary): d["resources"]["wood"] = -1,
		"malformed event": func(d: Dictionary): d["events"][0].erase("type"),
	}
	var base := _played_save().to_dict()
	assert_ok(SaveValidator.build_and_validate(base.duplicate(true)), "the unmodified document is valid")
	for label in cases.keys():
		var doc: Dictionary = base.duplicate(true)
		(cases[label] as Callable).call(doc["universe"]["settlements"]["stl_emberfall"])
		assert_fail(SaveValidator.build_and_validate(doc), label)
	var no_location: Dictionary = base.duplicate(true)
	no_location["universe"]["location"] = {"map_id": "", "entry_id": "", "return_stack": []}
	assert_fail(SaveValidator.build_and_validate(no_location), "location without a map")
	var bad_clock: Dictionary = base.duplicate(true)
	bad_clock["universe"]["time_of_day_minutes"] = 1440
	assert_fail(SaveValidator.build_and_validate(bad_clock), "minute outside the day")
	# a refused state is never written either
	var save := _played_save()
	save.universe.home_settlement().buildings[0]["condition"] = -5
	assert_fail(repo.write(3, save))
	assert_false(repo.slot_exists(3))
