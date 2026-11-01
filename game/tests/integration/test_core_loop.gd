extends TestCase
## The whole vertical-slice loop through the real services, with no scenes:
## new game → settlement → plan → start → fight/collect/decide → return →
## build → save → load → verify.

var repo: SaveRepository


func before_each() -> void:
	repo = SaveRepository.new(temp_dir + "/saves")


func test_full_loop_persists_consequences() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(4711, "challenging", "village_hunter"))
	var u := b.save.universe
	var home := u.home_settlement()
	assert_eq(home.display_name, "Emberfall")
	assert_eq(u.current_day, 1)
	assert_true(u.is_landmark_discovered("emberfall"))
	assert_false(u.is_landmark_discovered("cinder_pass"))

	# plan + start
	var dests := b.expeditions.available_destinations()
	assert_true(dests.has("ashen_crossroads"))
	assert_false(dests.has("emberfall"), "home is not a destination")
	var routes := b.expeditions.plan_routes("ashen_crossroads")
	assert_true(routes.size() >= 1)
	var started := b.expeditions.start("ashen_crossroads", routes[0])
	assert_ok(started)
	assert_fail(b.expeditions.start("ashen_crossroads", routes[0]), "only one active expedition")
	var exp_id: String = started.value
	assert_eq(exp_id, "exp_000001")

	# explore: area generation, resource, enemy, decision
	var area := b.expeditions.build_area()
	assert_eq(area.biome_id, "marches")
	assert_false(area.npc_spawn.is_empty(), "stranded survivor appears in the marches")
	var node: Dictionary = area.resource_nodes[0]
	b.expeditions.collect_resource(node["key"], node["resource_id"], int(node["amount"]))
	var kill := b.expeditions.on_enemy_defeated(area.enemy_spawns[0]["enemy_id"])
	assert_true(int(kill["xp"]) > 0)
	var exp := u.active_expedition()
	assert_eq(exp.enemies_defeated, 1)
	assert_eq(exp.haul[node["resource_id"]] >= int(node["amount"]), true)
	exp.add_haul("food", 2)
	var decision := DecisionRules.resolve(b.save, "stranded_survivor", Content.get_def("decisions", "stranded_survivor"), "help")
	assert_ok(decision)
	assert_eq(b.save.character.morality, 15)
	assert_eq(u.faction("crown_of_aurel").player_reputation, 20)
	assert_eq(u.faction("ashen_legion").player_reputation, -20, "untouched faction keeps its value")
	assert_eq(home.pending_recruits, 1)
	assert_fail(DecisionRules.resolve(b.save, "stranded_survivor", Content.get_def("decisions", "stranded_survivor"), "rob"), "decision resolves once")

	# return home
	var haul_wood := int(exp.haul.get("wood", 0))
	var wood_before := home.resource_amount("wood")
	var fin := b.expeditions.finish("returned")
	assert_ok(fin)
	var summary: Dictionary = fin.value
	assert_eq(home.resource_amount("wood"), wood_before + haul_wood)
	assert_eq(u.active_expedition_id, "")
	assert_eq(u.expedition_history, [exp_id])
	assert_eq(u.threat_state["completed_expeditions"], 1)
	assert_eq(u.current_day, 1 + 2 * exp.travel_days)
	assert_eq(home.population, 7, "rescued survivor joined")
	assert_true(u.revealed_edge_ids.size() > 0)
	var r2 := b.expeditions.resolve(exp_id)
	assert_ok(r2)
	assert_true(r2.value["already_resolved"])
	assert_eq(u.threat_state["completed_expeditions"], 1, "resolve is idempotent")
	assert_eq(u.expedition_history.size(), 1)

	# build
	home.resources["wood"] = maxi(home.resource_amount("wood"), 10)
	var built := ConstructionRules.build(home, "shelter", Content.table("buildings"), u.id_counters, u.current_day)
	assert_ok(built)

	# save / load
	b.save.universe.rng_states = b.rng.to_dict()
	assert_ok(repo.write(1, b.save))
	var loaded: SaveGame = repo.load_slot(1).value
	assert_eq(loaded.character.morality, 15)
	assert_eq(loaded.universe.faction("crown_of_aurel").player_reputation, 20)
	assert_eq(loaded.universe.home_settlement().buildings.size(), 1)
	assert_eq(loaded.universe.home_settlement().population, 7)
	assert_eq(loaded.universe.decision_log["stranded_survivor"], "help")
	assert_eq(loaded.universe.expeditions[exp_id].resolved, true)
	var b2 := TestFixtures.bind(loaded)
	# Same universe => same world graph and same area layout after reload.
	assert_eq(b2.world.fingerprint(), b.world.fingerprint())
	var started2 := b2.expeditions.start("ashen_crossroads", b2.expeditions.plan_routes("ashen_crossroads")[0])
	assert_ok(started2)
	assert_eq(started2.value, "exp_000002", "id counters persist")
	var area2 := b2.expeditions.build_area()
	# The survivor is resolved, so the next marches decision in priority order takes her place.
	assert_eq(String(area2.npc_spawn.get("decision_id", "")), "crown_patrol", "resolved decision gives way to the Crown patrol")
	assert_eq(area2.spawn, area.spawn)
	assert_eq(area2.exit, area.exit)
	assert_true(area2.resource_nodes[0]["depleted"], "harvested node stays depleted")
	assert_eq(area2.enemy_spawns.size(), area.enemy_spawns.size())


func test_retreat_keeps_haul_and_counts() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(99))
	TestFixtures.start_any_expedition(b)
	b.expeditions.collect_resource("k", "stone", 3)
	var stone_before := b.save.universe.home_settlement().resource_amount("stone")
	assert_ok(b.expeditions.finish("retreated"))
	assert_eq(b.save.universe.home_settlement().resource_amount("stone"), stone_before + 3)
	assert_eq(b.save.universe.threat_state["completed_expeditions"], 1)
	assert_fail(b.expeditions.finish("returned"), "nothing active")


func test_grace_period_counts_once_per_expedition() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(5, "extreme"))
	var grace := int(b.save.universe.threat_state["grace_period"])
	assert_eq(grace, 2)
	for i in grace:
		TestFixtures.start_any_expedition(b)
		assert_ok(b.expeditions.finish("returned"))
		assert_eq(b.save.universe.threat_state["awareness"], 0)
	TestFixtures.start_any_expedition(b)
	assert_ok(b.expeditions.finish("returned"))
	assert_true(int(b.save.universe.threat_state["awareness"]) > 0)
	assert_eq(b.save.universe.threat_state["completed_expeditions"], grace + 1)


func test_level_up_in_the_field_unlocks_classes_and_heals() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save(6))
	TestFixtures.start_any_expedition(b)
	b.save.universe.protagonist_condition["health"] = 1
	var levels := b.expeditions.grant_experience(1000)
	assert_true(levels >= 3)
	assert_eq(b.save.universe.protagonist_condition["health"], ProgressionRules.max_health(b.save.character, Content.balance("character")))
	assert_true(b.save.character.unlocked_classes.has("survivor"))
