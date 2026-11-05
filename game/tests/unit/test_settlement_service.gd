extends TestCase
## SettlementService and the settlement rules behind it: snapshots are
## read-only copies of the one authoritative state, requests are validated and
## all-or-nothing, construction jobs advance with in-game days, workers and
## time behave, and every change is announced by a signal.
##
## No Session here: each test builds its own save and its own service, the
## same way Session does.

const FULL_DAY := UniverseState.MINUTES_PER_DAY


func _service(seed_value: int = 4242) -> SettlementService:
	return SettlementService.new(TestFixtures.new_save(seed_value), Content)


func _stock(svc: SettlementService, wood: int = 200, stone: int = 200, iron: int = 50, food: int = 200) -> void:
	# Tests need room to pay for things; the storage cap is not under test here.
	svc.state().base_storage_capacity = 1000
	svc.state().resources = {"wood": wood, "stone": stone, "iron": iron, "food": food}


func _site(svc: SettlementService, site_id: String) -> Dictionary:
	return svc.inspect_site(site_id)


func test_village_starts_as_ruins_and_free_plots() -> void:
	var svc := _service()
	var snap := svc.snapshot()
	assert_eq(svc.state().buildings.size(), 0, "nothing is built at the start")
	var cores := 0
	var plots := 0
	for site in snap["sites"]:
		assert_eq(site["level"], 0)
		assert_eq(site["instance_id"], "")
		assert_false(site["functional"])
		if site["kind"] == SiteRules.KIND_CORE:
			cores += 1
			assert_eq(site["state"], SiteRules.STATE_RUIN)
			assert_eq(site["improvements"].size(), 1, "a reserved site offers exactly its own building")
			assert_eq(site["improvements"][0]["action"], SettlementService.ACTION_BUILD)
			assert_eq(site["improvements"][0]["definition_id"], site["definition_id"])
		else:
			plots += 1
			assert_eq(site["state"], SiteRules.STATE_EMPTY)
			assert_eq(site["definition_id"], "")
			assert_true(site["improvements"].size() >= 3, "a plot offers every unreserved building")
	assert_eq(cores, 5, "hearth + shelter + workshop + stockpile + watchpost")
	assert_eq(plots, 4, "four free building sites")
	for id in ["village_hearth", "shelter", "workshop", "stockpile", "watchpost"]:
		var found := false
		for site in snap["sites"]:
			if site["definition_id"] == id:
				found = true
		assert_true(found, id + " has a site")


func test_snapshot_matches_state_and_is_a_copy() -> void:
	var svc := _service()
	var s := svc.state()
	var u := svc.universe()
	var defs := Content.table("buildings")
	var snap := svc.snapshot()
	assert_eq(snap["resources"], s.resources)
	assert_eq(snap["population"]["count"], s.population)
	assert_eq(snap["population"]["count"], s.residents.size(), "population is the roster")
	assert_eq(snap["population"]["residents"].size(), s.residents.size())
	assert_eq(snap["population"]["capacity"], SettlementRules.population_capacity(s, defs))
	assert_eq(snap["storage_capacity"], SettlementRules.storage_capacity(s, defs))
	assert_eq(snap["stats"]["morale"], s.morale)
	assert_eq(snap["time"]["day"], u.current_day)
	assert_eq(snap["time"]["minute_of_day"], u.time_of_day_minutes)
	assert_eq(snap["time"]["clock"], "08:00")
	assert_eq(snap["threat"]["awareness"], int(u.threat_state["awareness"]))
	assert_eq(snap["threat"]["label"], DictUtil.get_string(ThreatRules.band(u.threat_state, Content.balance("threat")), "label"))
	assert_eq(snap["map_id"], "village_emberfall")
	# Changing a snapshot changes nothing.
	var before := s.to_dict()
	snap["resources"]["wood"] = 9999
	snap["population"]["residents"][0]["name"] = "Changed"
	snap["population"]["residents"].clear()
	snap["sites"][0]["level"] = 7
	snap["events"].append({"x": 1})
	assert_eq(s.to_dict(), before, "state untouched by edits to a snapshot")
	assert_ne(svc.snapshot()["resources"]["wood"], 9999, "a new snapshot is built from state")
	var inspection := svc.inspect_site("site_shelter")
	inspection["improvements"][0]["cost"]["wood"] = 0
	assert_eq(svc.inspect_site("site_shelter")["improvements"][0]["cost"]["wood"], 10)
	assert_eq(DictUtil.get_int(DictUtil.get_dict(defs["shelter"], "cost"), "wood"), 10, "definitions are not reachable through an inspection")


func test_construction_is_all_or_nothing() -> void:
	var svc := _service()
	var s := svc.state()
	s.resources = {"wood": 3, "stone": 0, "food": 5, "iron": 0}
	var before := s.to_dict()
	var reasons := svc.validate_construction("site_hearth", "village_hearth")
	assert_eq(reasons.size(), 1)
	assert_true(reasons[0].begins_with("Need 4 wood"), reasons[0])
	assert_fail(svc.request_construction("site_hearth", "village_hearth"), "cannot afford")
	assert_eq(s.to_dict(), before, "a refused request changes nothing (no cost, no job, no event)")
	assert_fail(svc.request_construction("no_such_site", "shelter"))
	assert_fail(svc.request_construction("site_hearth", "no_such_building"))
	assert_eq(s.to_dict(), before)


func test_instant_build_and_job_build() -> void:
	var svc := _service()
	var s := svc.state()
	_stock(svc)
	# The hearth has no build time: it stands at once.
	var r := svc.request_construction("site_hearth", "village_hearth")
	assert_ok(r)
	assert_true(r.value["completed"])
	assert_eq(s.resources["wood"], 196)
	var hearth := _site(svc, "site_hearth")
	assert_eq(hearth["state"], SiteRules.STATE_STANDING)
	assert_eq(hearth["level"], 1)
	assert_eq(hearth["condition"], 100)
	assert_eq(hearth["condition_label"], "Sound")
	assert_eq(hearth["instance_id"], String(s.buildings[0]["instance_id"]))
	assert_fail(svc.request_construction("site_hearth", "village_hearth"), "site is taken")

	# The workshop takes a day: a job is created, the cost is paid up front.
	r = svc.request_construction("site_workshop", "workshop")
	assert_ok(r)
	assert_false(r.value["completed"])
	assert_eq(s.resources["wood"], 188)
	assert_eq(s.resources["stone"], 196)
	assert_eq(s.construction_jobs.size(), 1)
	assert_eq(s.buildings.size(), 1, "not built yet")
	var site := _site(svc, "site_workshop")
	assert_eq(site["state"], SiteRules.STATE_CONSTRUCTION)
	assert_eq(site["definition_id"], "workshop")
	assert_eq(site["level"], 0)
	assert_eq(site["job"]["kind"], SettlementState.JOB_BUILD)
	assert_eq(site["job"]["work_required"], 1)
	assert_eq(site["improvements"].size(), 0, "nothing else can be ordered while work is under way")
	assert_fail(svc.request_construction("site_workshop", "workshop"), "work already under way")
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))

	var day_before := svc.universe().current_day
	var out := svc.advance_time(FULL_DAY)
	assert_eq(out["days_passed"], 1)
	assert_eq(svc.universe().current_day, day_before + 1)
	assert_eq(s.construction_jobs.size(), 0)
	site = _site(svc, "site_workshop")
	assert_eq(site["state"], SiteRules.STATE_STANDING)
	assert_eq(site["level"], 1)
	assert_eq(site["built_day"], day_before + 1)
	assert_eq(site["instance_id"], String(r.value["job"]["instance_id"]), "the job's reserved instance id is the building's id")
	var types: Array[String] = []
	for e in s.events:
		types.append(String(e["type"]))
	assert_eq(types, ["building_constructed", "job_started", "job_completed", "building_constructed"])
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))


func test_inspection_matches_state_for_every_building() -> void:
	var svc := _service()
	var s := svc.state()
	var defs := Content.table("buildings")
	_stock(svc)
	for pair in [["site_hearth", "village_hearth"], ["site_shelter", "shelter"], ["site_workshop", "workshop"], ["site_stockpile", "stockpile"], ["site_watchpost", "watchpost"]]:
		assert_ok(svc.request_construction(pair[0], pair[1]))
	svc.advance_time(FULL_DAY)
	assert_eq(s.buildings.size(), 5)
	assert_ok(svc.damage_building(DictUtil.get_string(s.building_at_site("site_stockpile"), "instance_id"), 35, "test"))
	for site_id in ["site_hearth", "site_shelter", "site_workshop", "site_stockpile", "site_watchpost"]:
		var instance := s.building_at_site(site_id)
		var definition: Dictionary = defs[String(instance["definition_id"])]
		var view := _site(svc, site_id)
		assert_eq(view["instance_id"], String(instance["instance_id"]), site_id)
		assert_eq(view["definition_id"], String(instance["definition_id"]), site_id)
		assert_eq(view["name"], DictUtil.get_string(definition, "name"), site_id)
		assert_eq(view["level"], int(instance["level"]), site_id)
		assert_eq(view["max_level"], BuildingRules.max_level(definition), site_id)
		assert_eq(view["condition"], int(instance["condition"]), site_id)
		assert_eq(view["effects"], BuildingRules.effects_for(instance, defs), site_id)
		assert_eq(view["state"], SiteRules.STATE_STANDING, site_id)
		assert_eq(svc.inspect_building(String(instance["instance_id"])), view, "same view by instance id")
		# the offered upgrade is the definition's next level
		var upgrade: Dictionary = view["improvements"][0]
		assert_eq(upgrade["action"], SettlementService.ACTION_UPGRADE, site_id)
		assert_eq(upgrade["target_level"], 2, site_id)
		assert_eq(upgrade["cost"], DictUtil.int_map(DictUtil.get_dict(BuildingRules.level_spec(definition, 2), "cost")), site_id)
		assert_true(upgrade["available"], site_id)
	var stockpile := _site(svc, "site_stockpile")
	assert_eq(stockpile["condition"], 65)
	assert_eq(stockpile["condition_label"], "Worn")
	assert_eq(stockpile["improvements"].size(), 2, "upgrade + repair")
	assert_eq(stockpile["improvements"][1]["action"], SettlementService.ACTION_REPAIR)


func test_upgrade_validation_job_and_effects() -> void:
	var svc := _service()
	var s := svc.state()
	var defs := Content.table("buildings")
	_stock(svc, 10, 0)
	assert_ok(svc.request_construction("site_shelter", "shelter"))
	var shelter_id := DictUtil.get_string(s.building_at_site("site_shelter"), "instance_id")
	assert_eq(SettlementRules.population_capacity(s, defs), s.base_population_capacity + 4)
	# cannot afford level 2 yet
	var reasons := svc.validate_upgrade(shelter_id)
	assert_eq(reasons.size(), 2, "; ".join(reasons))
	assert_false(_site(svc, "site_shelter")["improvements"][0]["available"])
	assert_eq(_site(svc, "site_shelter")["improvements"][0]["blocked_by"], reasons)
	var before := s.to_dict()
	assert_fail(svc.request_upgrade(shelter_id))
	assert_eq(s.to_dict(), before)
	# pay, a job runs for a day, then the level and its effects change
	_stock(svc, 14, 6)
	assert_true(svc.validate_upgrade(shelter_id).is_empty())
	var r := svc.request_upgrade(shelter_id)
	assert_ok(r)
	assert_false(r.value["completed"])
	assert_eq(s.resources["wood"], 0)
	assert_eq(s.resources["stone"], 0)
	assert_eq(int(s.building_by_id(shelter_id)["level"]), 1, "still level 1 while the work runs")
	assert_eq(_site(svc, "site_shelter")["state"], SiteRules.STATE_STANDING)
	assert_eq(_site(svc, "site_shelter")["job"]["kind"], SettlementState.JOB_UPGRADE)
	assert_eq(svc.validate_upgrade(shelter_id), ["Work is already under way here", "Need 6 stone (have 0)", "Need 14 wood (have 0)"] as Array[String])
	svc.advance_time(FULL_DAY)
	assert_eq(int(s.building_by_id(shelter_id)["level"]), 2)
	assert_eq(SettlementRules.population_capacity(s, defs), s.base_population_capacity + 7, "level 2 effects replace level 1's")
	# on to the top, then no further
	_stock(svc)
	assert_ok(svc.request_upgrade(shelter_id))
	svc.advance_time(FULL_DAY * 2)
	assert_eq(int(s.building_by_id(shelter_id)["level"]), 3)
	assert_eq(svc.validate_upgrade(shelter_id), ["Already at the highest level"] as Array[String])
	assert_fail(svc.request_upgrade(shelter_id))
	assert_eq(_site(svc, "site_shelter")["improvements"].size(), 0)
	assert_fail(svc.request_upgrade("bld_999999"), "unknown instance")


func test_site_placement_rules() -> void:
	var svc := _service()
	var s := svc.state()
	_stock(svc)
	assert_fail(svc.request_construction("plot_1", "workshop"), "reserved buildings only on their own site")
	assert_fail(svc.request_construction("site_workshop", "shelter"), "a reserved site takes only its building")
	assert_fail(svc.request_construction("site_workshop", "woodcutters_camp"))
	assert_eq(s.buildings.size(), 0)
	# a shelter fits its reserved site and any plot
	assert_ok(svc.request_construction("plot_2", "shelter"))
	assert_eq(String(s.buildings[0]["site_id"]), "plot_2")
	assert_ok(svc.request_construction("site_shelter", "shelter"))
	# request_construction_anywhere: reserved site first, then plots in layout order
	assert_ok(svc.request_construction_anywhere("stockpile"))
	assert_false(s.job_at_site("site_stockpile").is_empty())
	assert_fail(svc.request_construction_anywhere("stockpile"), "max_count counts the building under construction")
	assert_ok(svc.request_construction_anywhere("woodcutters_camp"))
	assert_eq(String(s.buildings[2]["site_id"]), "plot_1")
	assert_ok(svc.request_construction_anywhere("storehouse"))
	assert_eq(String(s.buildings[3]["site_id"]), "plot_3")
	assert_ok(svc.request_construction_anywhere("palisade"))
	assert_eq(String(s.buildings[4]["site_id"]), "plot_4")
	var r := svc.request_construction_anywhere("storehouse")
	assert_fail(r, "all four plots are taken")
	assert_true(r.error.contains("No free building site"), r.error)
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))


func test_worker_assignment() -> void:
	var svc := _service()
	var s := svc.state()
	var defs := Content.table("buildings")
	_stock(svc)
	assert_ok(svc.request_construction("site_shelter", "shelter"))
	assert_ok(svc.request_construction("site_watchpost", "watchpost"))
	assert_ok(svc.request_construction("plot_1", "woodcutters_camp"))
	var shelter_id := DictUtil.get_string(s.building_at_site("site_shelter"), "instance_id")
	var camp_id := DictUtil.get_string(s.building_at_site("plot_1"), "instance_id")
	var job_id := DictUtil.get_string(s.job_at_site("site_watchpost"), "job_id")
	var r0 := String(s.residents[0]["resident_id"])
	var r1 := String(s.residents[1]["resident_id"])
	var r2 := String(s.residents[2]["resident_id"])
	assert_fail(svc.assign_worker(r0, shelter_id), "a shelter has no work places")
	assert_fail(svc.assign_worker("res_999999", camp_id), "unknown resident")
	assert_fail(svc.assign_worker(r0, "bld_999999"), "unknown target")
	assert_eq(svc.snapshot()["population"]["idle"], s.population)

	# production: +1 wood per assigned woodcutter, two places
	assert_eq(SettlementRules.daily_production(s, defs), {"wood": 2})
	assert_ok(svc.assign_worker(r0, camp_id))
	assert_ok(svc.assign_worker(r1, camp_id))
	assert_eq(svc.validate_worker_assignment(r2, camp_id), ["No free work place (2/2)"] as Array[String])
	assert_fail(svc.assign_worker(r2, camp_id))
	assert_fail(svc.assign_worker(r0, camp_id), "already there")
	assert_eq(SettlementRules.daily_production(s, defs), {"wood": 4})
	assert_eq(_site(svc, "plot_1")["workers"].size(), 2)
	assert_eq(_site(svc, "plot_1")["worker_slots"], 2)
	assert_eq(svc.snapshot()["population"]["residents"][0]["assignment_label"], "Woodcutter's Camp")
	assert_eq(svc.snapshot()["population"]["idle"], s.population - 2)

	# a builder moves from the camp to the job: the job needs 1 day either way,
	# and finishing it frees the builder
	assert_ok(svc.assign_worker(r1, job_id))
	assert_eq(String(s.resident_by_id(r1)["assigned_to"]), job_id, "one work place per resident")
	assert_eq(SettlementRules.daily_production(s, defs), {"wood": 3})
	assert_eq(_site(svc, "site_watchpost")["job"]["work_per_day"], 2)
	assert_eq(_site(svc, "site_watchpost")["job"]["builders"].size(), 1)
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))
	svc.advance_time(FULL_DAY)
	assert_eq(String(s.resident_by_id(r1)["assigned_to"]), "", "released when the job finished")
	assert_eq(_site(svc, "site_watchpost")["level"], 1)

	assert_ok(svc.unassign_worker(r0))
	assert_fail(svc.unassign_worker(r0), "nothing to leave")
	assert_ok(svc.assign_idle_worker(camp_id))
	assert_eq(String(s.residents[0]["assigned_to"]), camp_id, "first idle resident in roster order")
	assert_ok(svc.unassign_one_worker(camp_id))
	assert_fail(svc.unassign_one_worker(camp_id))


func test_builders_shorten_a_long_job() -> void:
	var alone := _service()
	var helped := _service()
	for svc in [alone, helped]:
		_stock(svc)
		assert_ok(svc.request_construction("site_hearth", "village_hearth"))
		var hearth_id := DictUtil.get_string(svc.state().building_at_site("site_hearth"), "instance_id")
		assert_ok(svc.request_upgrade(hearth_id))
		svc.advance_time(FULL_DAY)
		assert_ok(svc.request_upgrade(hearth_id))   # level 3: two days of work
	var job_id := DictUtil.get_string(helped.state().construction_jobs[0], "job_id")
	assert_ok(helped.assign_idle_worker(job_id))
	alone.advance_time(FULL_DAY)
	helped.advance_time(FULL_DAY)
	assert_eq(_site(alone, "site_hearth")["level"], 2, "one day is not enough for the village alone")
	assert_eq(_site(alone, "site_hearth")["job"]["work_done"], 1)
	assert_eq(_site(helped, "site_hearth")["level"], 3, "a builder doubles the daily work")


func test_damage_destroys_and_repair_restores() -> void:
	var svc := _service()
	var s := svc.state()
	var defs := Content.table("buildings")
	_stock(svc)
	assert_ok(svc.request_construction("site_watchpost", "watchpost"))
	svc.advance_time(FULL_DAY)
	var post_id := DictUtil.get_string(s.building_at_site("site_watchpost"), "instance_id")
	assert_ok(svc.assign_idle_worker(post_id))
	assert_eq(SettlementRules.military_strength(s, defs), 2)
	assert_eq(svc.validate_repair(post_id), ["Nothing to repair"] as Array[String])
	var hit := svc.damage_building(post_id, 250, "raid")
	assert_ok(hit)
	assert_eq(hit.value, 0, "condition never goes below 0")
	var view := _site(svc, "site_watchpost")
	assert_eq(view["state"], SiteRules.STATE_DESTROYED)
	assert_eq(view["level"], 1, "a destroyed building keeps its level")
	assert_false(view["functional"])
	assert_eq(view["condition_label"], "Ruined")
	assert_eq(view["effects"], {})
	assert_eq(SettlementRules.military_strength(s, defs), 0, "no effects while destroyed")
	assert_eq(s.workers_assigned_to(post_id).size(), 0, "nobody works in a ruin")
	assert_true(svc.validate_upgrade(post_id).has("Must be repaired first"))
	# repair: half of the level's cost for the missing condition, and it takes
	# as long as building it did
	var repair: Dictionary = view["improvements"][1]
	assert_eq(repair["action"], SettlementService.ACTION_REPAIR)
	assert_eq(repair["cost"], {"wood": 5, "stone": 2})
	assert_eq(repair["days"], 1)
	var wood_before := s.resource_amount("wood")
	assert_ok(svc.request_improvement("site_watchpost", SettlementService.ACTION_REPAIR))
	assert_eq(s.resource_amount("wood"), wood_before - 5)
	assert_eq(_site(svc, "site_watchpost")["job"]["kind"], SettlementState.JOB_REPAIR)
	svc.advance_time(FULL_DAY)
	view = _site(svc, "site_watchpost")
	assert_eq(view["condition"], 100)
	assert_eq(view["state"], SiteRules.STATE_STANDING)
	assert_eq(SettlementRules.military_strength(s, defs), 2)
	assert_fail(svc.damage_building("bld_999999", 5))


func test_cancel_job_refunds_and_frees_the_site() -> void:
	var svc := _service()
	var s := svc.state()
	_stock(svc, 20, 20)
	assert_ok(svc.request_construction("site_stockpile", "stockpile"))
	var job_id := DictUtil.get_string(s.construction_jobs[0], "job_id")
	assert_ok(svc.assign_idle_worker(job_id))
	assert_eq(s.resources["wood"], 14)
	var r := svc.cancel_job(job_id)
	assert_ok(r)
	assert_eq(r.value["refund"], {"wood": 6, "stone": 2})
	assert_eq(s.resources["wood"], 20)
	assert_eq(s.resources["stone"], 20)
	assert_eq(s.construction_jobs.size(), 0)
	assert_eq(s.workers_assigned_to(job_id).size(), 0)
	assert_eq(_site(svc, "site_stockpile")["state"], SiteRules.STATE_RUIN)
	assert_fail(svc.cancel_job(job_id), "already gone")
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))


func test_time_advances_and_runs_the_daily_tick() -> void:
	var svc := _service()
	var s := svc.state()
	var u := svc.universe()
	s.resources["food"] = 8
	assert_eq(u.time_of_day_minutes, 480)
	var out := svc.advance_time(90)
	assert_eq(out["days_passed"], 0)
	assert_eq(u.time_of_day_minutes, 570)
	assert_eq(u.current_day, 1)
	assert_eq(s.resources["food"], 8, "no tick inside a day")
	assert_eq(svc.time_view()["clock"], "09:30")
	out = svc.advance_time(FULL_DAY - 570)   # exactly to midnight
	assert_eq(out["days_passed"], 1)
	assert_eq(u.current_day, 2)
	assert_eq(u.time_of_day_minutes, 0)
	assert_eq(s.resources["food"], 7, "six people eat one unit a day")
	assert_eq(out["sim"].size(), 1)
	out = svc.rest_until_dawn()
	assert_eq(out["days_passed"], 0)
	assert_eq(u.time_of_day_minutes, 360)
	out = svc.rest_until_dawn()
	assert_eq(out["days_passed"], 1, "resting at dawn waits for the next dawn")
	assert_eq(u.current_day, 3)
	assert_eq(u.time_of_day_minutes, 360)
	assert_eq(svc.advance_time(0)["days_passed"], 0)
	assert_eq(svc.advance_time(-50)["minutes"], 0, "time never runs backwards")
	assert_eq(u.time_of_day_minutes, 360)
	out = svc.advance_time(FULL_DAY * 3 + 15)
	assert_eq(out["days_passed"], 3)
	assert_eq(u.current_day, 6)
	assert_eq(u.time_of_day_minutes, 375)
	assert_true(u.validate().is_empty(), "; ".join(u.validate()))


func test_signals_follow_changes() -> void:
	var svc := _service()
	_stock(svc)
	var seen := {"reasons": [], "buildings": [], "jobs": [], "resources": 0, "time": [], "events": [], "workers": [], "population": []}
	svc.settlement_changed.connect(func(reason: String): seen["reasons"].append(reason))
	svc.building_changed.connect(func(site_id: String, instance_id: String): seen["buildings"].append([site_id, instance_id]))
	svc.job_changed.connect(func(job_id: String, status: String): seen["jobs"].append([job_id, status]))
	svc.resources_changed.connect(func(_r: Dictionary): seen["resources"] += 1)
	svc.time_advanced.connect(func(day: int, minute: int): seen["time"].append([day, minute]))
	svc.event_recorded.connect(func(e: Dictionary): seen["events"].append(String(e["type"])))
	svc.worker_assignment_changed.connect(func(resident_id: String, target_id: String): seen["workers"].append([resident_id, target_id]))
	svc.population_changed.connect(func(count: int): seen["population"].append(count))

	assert_fail(svc.request_construction("plot_1", "workshop"))
	assert_eq(seen["reasons"], [], "a refused request announces nothing")
	assert_eq(seen["events"], [])

	assert_ok(svc.request_construction("site_hearth", "village_hearth"))
	var hearth_id := DictUtil.get_string(svc.state().building_at_site("site_hearth"), "instance_id")
	assert_eq(seen["reasons"], ["construction"])
	assert_eq(seen["buildings"], [["site_hearth", hearth_id]])
	assert_eq(seen["resources"], 1)
	assert_eq(seen["events"], ["building_constructed"])

	assert_ok(svc.request_construction("site_workshop", "workshop"))
	var job_id := DictUtil.get_string(svc.state().construction_jobs[0], "job_id")
	assert_eq(seen["jobs"], [[job_id, "started"]])
	assert_eq(seen["buildings"][1], ["site_workshop", ""], "announced with no instance while it is being built")
	var builder := String(svc.state().residents[0]["resident_id"])
	assert_ok(svc.assign_worker(builder, job_id))
	assert_eq(seen["workers"], [[builder, job_id]])
	assert_eq(seen["reasons"], ["construction", "construction", "workers"])

	svc.advance_time(UniverseState.MINUTES_PER_DAY)
	var workshop_id := DictUtil.get_string(svc.state().building_at_site("site_workshop"), "instance_id")
	assert_eq(seen["jobs"][1], [job_id, "completed"])
	assert_eq(seen["buildings"][2], ["site_workshop", workshop_id])
	assert_eq(seen["time"], [[2, 480]])
	assert_eq(seen["reasons"][3], "time")
	assert_eq(seen["events"], ["building_constructed", "job_started", "worker_assigned", "job_completed", "building_constructed"])
	assert_eq(seen["events"].size(), svc.state().events.size(), "one signal per logged event")

	# housing lets waiting recruits in, and that is announced too
	svc.state().pending_recruits = 2
	var capacity := SettlementRules.population_capacity(svc.state(), Content.table("buildings"))
	while svc.state().population < capacity:
		svc.state().add_resident("founder", 1, "Filler %d" % svc.state().population)
	assert_ok(svc.request_construction("site_shelter", "shelter"))
	assert_eq(seen["population"], [capacity + 2])
	assert_eq(svc.state().pending_recruits, 0)
	assert_eq(seen["events"].slice(-2), ["resident_joined", "resident_joined"])


func test_residents_are_named_deterministically_and_uniquely() -> void:
	var a := _service(777).state()
	var b := _service(777).state()
	var c := _service(778).state()
	var names_a: Array[String] = []
	var names_b: Array[String] = []
	var names_c: Array[String] = []
	for i in a.residents.size():
		names_a.append(String(a.residents[i]["name"]))
		names_b.append(String(b.residents[i]["name"]))
		names_c.append(String(c.residents[i]["name"]))
		assert_eq(String(a.residents[i]["resident_id"]), "res_%06d" % (i + 1))
		assert_eq(String(a.residents[i]["origin"]), "founder")
	assert_eq(names_a, names_b, "same universe seed, same people")
	assert_ne(names_a, names_c, "another universe has other people")
	var unique := {}
	for n in names_a:
		assert_true(n != "", "everyone has a name")
		unique[n] = true
	assert_eq(unique.size(), names_a.size(), "no two residents share a name")
	# a crowd larger than the name pool still gets distinct names
	var pool := PopulationRules.name_pool(Content)
	for i in pool.size() + 3:
		a.add_resident("recruit", 2)
	PopulationRules.ensure_names(a, pool, 777)
	unique.clear()
	for r in a.residents:
		unique[String(r["name"])] = true
	assert_eq(unique.size(), a.residents.size())


func test_population_is_the_roster() -> void:
	var s := _service().state()
	assert_eq(s.population, 6)
	s.population = 8
	assert_eq(s.residents.size(), 8, "assigning the legacy number grows the roster")
	assert_eq(String(s.residents[7]["resident_id"]), "res_000008")
	s.residents[7]["assigned_to"] = ""
	s.residents[6]["assigned_to"] = "somewhere"
	s.population = 7
	assert_eq(s.residents.size(), 7)
	assert_eq(String(s.residents[6]["assigned_to"]), "somewhere", "the idle one left first")
	assert_false(s.to_dict().has("population"), "not stored twice")
	var moved_state := SettlementState.from_dict(s.to_dict())
	assert_eq(moved_state.population, 7)
	assert_eq(moved_state.resident_counter, 8, "ids are never reused")


func test_event_log_is_bounded() -> void:
	var svc := _service()
	var s := svc.state()
	_stock(svc)
	assert_ok(svc.request_construction("plot_1", "woodcutters_camp"))
	var camp_id := String(s.buildings[0]["instance_id"])
	var limit := DictUtil.get_int(Content.balance("settlement"), "event_log_limit")
	assert_true(limit > 0)
	for i in limit:
		assert_ok(svc.assign_idle_worker(camp_id))
		assert_ok(svc.unassign_one_worker(camp_id))
	assert_eq(s.events.size(), limit, "oldest entries are dropped")
	assert_eq(s.event_counter, limit * 2 + 1, "ids keep counting")
	assert_eq(String(s.events[limit - 1]["event_id"]), "sev_%06d" % (limit * 2 + 1))
	assert_true(s.validate().is_empty())


func test_normalize_places_and_names_without_touching_a_current_state() -> void:
	var svc := _service()
	var s := svc.state()
	var before := s.to_dict()
	assert_eq(svc.normalize(), {"named": 0, "placed": 0, "released": 0})
	assert_eq(s.to_dict(), before, "a current state is left alone")
	# what a migrated save looks like: unnamed people, buildings without a site
	for r in s.residents:
		r["name"] = ""
	s.buildings.append(SettlementState.make_building_instance("bld_000001", "shelter", 1))
	s.buildings.append(SettlementState.make_building_instance("bld_000002", "woodcutters_camp", 2))
	s.buildings.append(SettlementState.make_building_instance("bld_000003", "shelter", 3))
	s.residents[0]["assigned_to"] = "bld_000001"   # impossible: a shelter has no work places
	var out := svc.normalize()
	assert_eq(out, {"named": 6, "placed": 3, "released": 1})
	assert_eq(String(s.buildings[0]["site_id"]), "site_shelter", "first shelter takes the reserved site")
	assert_eq(String(s.buildings[1]["site_id"]), "plot_1")
	assert_eq(String(s.buildings[2]["site_id"]), "plot_2")
	assert_eq(String(s.residents[0]["assigned_to"]), "")
	assert_true(s.validate().is_empty(), "; ".join(s.validate()))
	var again := s.to_dict()
	assert_eq(svc.normalize(), {"named": 0, "placed": 0, "released": 0}, "idempotent")
	assert_eq(s.to_dict(), again)
	assert_eq(svc.snapshot()["unplaced_buildings"].size(), 0)


func test_same_requests_give_the_same_state() -> void:
	var docs: Array = []
	for run in 2:
		var svc := _service(909)
		_stock(svc)
		assert_ok(svc.request_construction("site_hearth", "village_hearth"))
		assert_ok(svc.request_construction("site_workshop", "workshop"))
		assert_ok(svc.request_construction_anywhere("woodcutters_camp"))
		assert_ok(svc.assign_idle_worker(DictUtil.get_string(svc.state().building_at_site("plot_1"), "instance_id")))
		svc.advance_time(FULL_DAY * 2 + 30)
		assert_ok(svc.request_upgrade(DictUtil.get_string(svc.state().building_at_site("site_hearth"), "instance_id")))
		svc.rest_until_dawn()
		docs.append(svc.save.universe.to_dict())
	assert_eq(docs[0], docs[1], "no hidden randomness in the settlement")


func test_legacy_rule_entry_points_still_work() -> void:
	# The pre-village primitives are still valid ways to change the state.
	var s := TestFixtures.new_save().universe.home_settlement()
	var defs := Content.table("buildings")
	s.resources = {"wood": 30, "stone": 20, "food": 5, "iron": 0}
	var r := ConstructionRules.build(s, "shelter", defs, {}, 1)
	assert_ok(r)
	assert_eq(r.value["level"], 1)
	assert_eq(r.value["condition"], 100)
	assert_eq(r.value["site_id"], "", "no site without a layout")
	assert_eq(SettlementRules.population_capacity(s, defs), s.base_population_capacity + 4)
	s.pending_recruits = 2
	s.population = SettlementRules.population_capacity(s, defs) - 1
	assert_eq(SettlementRules.settle_recruits(s, defs), 1, "only as many as fit")
	assert_eq(s.pending_recruits, 1)
	assert_eq(String(s.residents[s.residents.size() - 1]["origin"]), "recruit")
