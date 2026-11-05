extends Node
## Two-process persistence check: save, quit the engine, relaunch, Continue.
## The in-process tests prove load_slot restores state; this proves the same
## through a real process boundary (the way a player experiences it).
##
##   godot --headless --path . res://tools/relaunch_check.tscn -- --phase=write
##   godot --headless --path . res://tools/relaunch_check.tscn -- --phase=verify
##
## Phase "write" plays a short loop headless (new game → build → expedition →
## gather → return → village work → autosave), then writes the full in-memory state to
## user://_relaunch_check/expected.json and exits 0. Phase "verify", run in
## a fresh process, uses the Continue path (latest slot), writes
## observed.json, compares the two documents field by field and exits 0 on
## an exact match, 1 otherwise. Saves go to a private directory so real
## slots are never touched. check_relaunch.sh / .ps1 run both phases.

const DIR := "user://_relaunch_check"
const EXPECTED := DIR + "/expected.json"
const OBSERVED := DIR + "/observed.json"
const SLOT := 2
const SEED := 20261101


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	call_deferred("_run", phase)


func _run(phase: String) -> void:
	var code := 1
	match phase:
		"write":
			code = _write()
		"verify":
			code = _verify()
		_:
			printerr("relaunch_check: pass -- --phase=write or --phase=verify")
	get_tree().quit(code)


func _fail(msg: String) -> int:
	printerr("RELAUNCH CHECK FAILED: " + msg)
	return 1


func _write() -> int:
	TestCase.remove_dir_recursive(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	Session.repository = SaveRepository.new(DIR + "/saves")
	var d := DifficultyRules.from_preset("normal", Content.table("difficulty"))
	var r := Session.new_game({"name": "Relaunch", "archetype_id": "village_hunter", "difficulty": d.value, "mist_enabled": true, "seed": SEED}, SLOT)
	if not r.ok:
		return _fail("new_game: " + r.error)
	# Touch every scope the way play does: construction (universe), an
	# expedition with a harvest and a kill (universe + character XP), a day
	# passing (simulation), a decision (character morality + reputation).
	Session.settlement().resources["wood"] = 20
	var b := Session.construct_building("shelter")
	if not b.ok:
		return _fail("construct shelter: " + b.error)
	var routes := Session.expeditions.plan_routes("ashen_crossroads")
	if routes.is_empty():
		return _fail("no route to ashen_crossroads")
	var s := Session.expeditions.start("ashen_crossroads", routes[0])
	if not s.ok:
		return _fail("start expedition: " + s.error)
	var map := Session.expeditions.build_area()
	if map.resource_nodes.is_empty() or map.enemy_spawns.is_empty():
		return _fail("generated area has no resources or enemies")
	var node: Dictionary = map.resource_nodes[0]
	Session.expeditions.collect_resource(String(node["key"]), String(node["resource_id"]), int(node["amount"]))
	Session.expeditions.on_enemy_defeated(String(map.enemy_spawns[0]["enemy_id"]))
	Session.expeditions.active().add_haul("food", 2)
	var dec := DecisionRules.resolve(Session.save, "stranded_survivor", Content.get_def("decisions", "stranded_survivor"), "help")
	if not dec.ok:
		return _fail("decision: " + dec.error)
	var f := Session.expeditions.finish("returned")
	if not f.ok:
		return _fail("finish expedition: " + f.error)
	# Village state (Stage 1): a building raised through the service, an
	# upgrade left unfinished with a builder on it, a worker at a building,
	# the clock moved inside the day, and the spot the player stands on.
	var village := Session.settlement_service
	Session.settlement().base_storage_capacity = 200
	Session.settlement().resources["wood"] = 60
	Session.settlement().resources["stone"] = 30
	for request in [village.request_construction("site_hearth", "village_hearth"), village.request_construction("plot_1", "woodcutters_camp"), village.request_upgrade(String(Session.settlement().building_at_site("site_shelter").get("instance_id", "")))]:
		if not request.ok:
			return _fail("village request: " + request.error)
	var upgrade_job := String(Session.settlement().job_at_site("site_shelter").get("job_id", ""))
	var camp := String(Session.settlement().building_at_site("plot_1").get("instance_id", ""))
	for assignment in [village.assign_idle_worker(upgrade_job), village.assign_idle_worker(camp)]:
		if not assignment.ok:
			return _fail("village worker: " + assignment.error)
	village.advance_time(95)
	Session.travel.remember_position(Vector2(512, 640))
	var w := Session.save_game()
	if not w.ok:
		return _fail("save_game: " + w.error)
	var snapshot := Session.save.to_dict()
	TestCase.write_text(EXPECTED, JSON.stringify(snapshot, "  "))
	print("RELAUNCH CHECK: wrote slot %d (day %d, level %d, %d buildings, history %d) and expected.json" % [SLOT, Session.universe().current_day, Session.character().level, Session.settlement().buildings.size(), Session.universe().expedition_history.size()])
	Session.end_session()
	return 0


func _verify() -> int:
	if not FileAccess.file_exists(EXPECTED):
		return _fail("expected.json missing — run --phase=write first")
	Session.repository = SaveRepository.new(DIR + "/saves")
	var r := Session.continue_latest()
	if not r.ok:
		return _fail("continue_latest: " + r.error)
	if Session.current_slot != SLOT:
		return _fail("Continue picked slot %d, expected %d" % [Session.current_slot, SLOT])
	if not Session.last_messages.is_empty():
		return _fail("load needed recovery: " + "; ".join(Session.last_messages))
	var observed := Session.save.to_dict()
	TestCase.write_text(OBSERVED, JSON.stringify(observed, "  "))
	var expected = JSON.parse_string(TestCase.read_text(EXPECTED))
	if not (expected is Dictionary):
		return _fail("expected.json is not valid JSON")
	# Compare the JSON round-trip of both so numeric representation is identical.
	var observed_rt = JSON.parse_string(JSON.stringify(observed))
	var diffs: Array[String] = []
	_diff("", expected, observed_rt, diffs)
	if not diffs.is_empty():
		for line in diffs:
			printerr("  " + line)
		return _fail("%d difference(s) between saved and reloaded state" % diffs.size())
	# Spot-check the invariants a player would notice.
	if Session.settlement().buildings.is_empty():
		return _fail("shelter missing after reload")
	if Session.universe().expedition_history.size() != 1:
		return _fail("expedition history lost")
	if Session.expeditions.active() != null:
		return _fail("expedition still active after reload")
	if Session.character().morality <= 0:
		return _fail("decision consequence lost")
	# Village progress a player would notice.
	var village := Session.settlement_service
	if int(village.inspect_site("site_hearth").get("level", 0)) != 1:
		return _fail("hearth lost after reload")
	if String(village.inspect_site("plot_1").get("definition_id", "")) != "woodcutters_camp" or (village.inspect_site("plot_1").get("workers", []) as Array).size() != 1:
		return _fail("woodcutter's camp or its worker lost after reload")
	var shelter := village.inspect_site("site_shelter")
	if int(shelter.get("level", 0)) != 1 or String((shelter.get("job", {}) as Dictionary).get("kind", "")) != "upgrade" or ((shelter.get("job", {}) as Dictionary).get("builders", []) as Array).size() != 1:
		return _fail("unfinished shelter upgrade lost after reload")
	if Session.universe().time_of_day_minutes != 575:
		return _fail("time of day lost after reload")
	if MapLocation.position(Session.universe().location) != Vector2(512, 640):
		return _fail("player position lost after reload")
	for resident in Session.settlement().residents:
		if String(resident.get("name", "")) == "":
			return _fail("a resident lost their name after reload")
	# The runtime streams must continue, not restart: a draw after reload
	# must differ from the first draw of a freshly seeded stream.
	var fresh := RngRegistry.from_dict({}, Session.universe().world_seed)
	var cont := Session.rng.stream("rewards").get_state()
	if int(cont["draws"]) > 0 and cont["state"] == fresh.stream("rewards").get_state()["state"]:
		return _fail("rewards stream restarted from its seed after reload")
	print("RELAUNCH CHECK PASSED: slot %d restored identically across a process restart (day %d, level %d, morality %d, %d buildings)" % [SLOT, Session.universe().current_day, Session.character().level, Session.character().morality, Session.settlement().buildings.size()])
	Session.end_session()
	return 0


func _diff(path: String, a: Variant, b: Variant, out: Array[String]) -> void:
	if a is Dictionary and b is Dictionary:
		var keys := {}
		for k in a.keys():
			keys[k] = true
		for k in b.keys():
			keys[k] = true
		for k in keys.keys():
			var p := path + "/" + str(k)
			if not a.has(k):
				out.append(p + ": only after reload")
			elif not b.has(k):
				out.append(p + ": lost on reload")
			else:
				_diff(p, a[k], b[k], out)
	elif a is Array and b is Array:
		if a.size() != b.size():
			out.append("%s: %d items saved, %d after reload" % [path, a.size(), b.size()])
			return
		for i in a.size():
			_diff("%s[%d]" % [path, i], a[i], b[i], out)
	elif not DictUtil.deep_equal(a, b):
		out.append("%s: saved %s, reloaded %s" % [path, str(a), str(b)])
