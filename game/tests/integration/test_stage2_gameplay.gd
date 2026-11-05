extends TestCase

var _repository: SaveRepository
var _scene: Node
var _navigation: Array[String] = []

class FailedWrites extends SaveRepository:
	func write(_slot: int, _save: SaveGame) -> OpResult:
		return OpResult.failure("Injected write failure")

func before_each() -> void:
	_repository = Session.repository
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	Router.navigation_hook = func(key: String): _navigation.append(key)
	_navigation.clear()
	var difficulty := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	assert_ok(Session.new_game({"name": "Survivor", "archetype_id": "village_hunter", "difficulty": difficulty.value, "mist_enabled": true, "seed": 20261105}, 1))

func after_each() -> void:
	Input.action_release("interact")
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null
	tree.paused = false
	Session.end_session()
	Session.repository = _repository
	Router.navigation_hook = Callable()

func _start(id: String) -> void:
	assert_ok(PoiRules.start(Session.expeditions, id))

func _stock() -> void:
	Session.settlement().base_storage_capacity = 1000
	Session.settlement().resources = {"wood": 300, "stone": 300, "salvage": 100, "food": 100, "iron": 0}

func _open_poi(id: String) -> Node:
	_start(id)
	_scene = load(Router.SCENES["poi"]).instantiate()
	tree.root.add_child(_scene)
	await tree.physics_frame
	await tree.physics_frame
	return _scene

func test_solo_start_and_personal_rebuilding() -> void:
	assert_eq(Session.settlement().population, 0)
	assert_eq(Session.character().current_class, "survivor")
	assert_eq(Session.universe().companion_states, {})
	var svc := Session.settlement_service
	assert_ok(svc.request_construction("site_stockpile", "stockpile"))
	assert_fail(svc.assign_idle_worker(String(svc.state().construction_jobs[0]["job_id"])))
	svc.advance_time(1440)
	assert_eq(svc.inspect_site("site_stockpile")["level"], 1)
	assert_eq(svc.snapshot()["storage_capacity"], 60)

func test_transactions_are_atomic_and_validate_all_inputs() -> void:
	var s := Session.settlement()
	var before := s.resources.duplicate()
	for invalid in [{"wood": -1}, {"wood": 1.5}, {"bogus": 2}, {"wood": 999, "stone": 1}, {"food": "3"}]:
		assert_fail(ResourceTransaction.spend(s, invalid, Content.table("resources")))
		assert_eq(s.resources, before)
	assert_ok(ResourceTransaction.spend(s, {"wood": 2}, Content.table("resources")))
	assert_eq(s.resource_amount("wood"), int(before["wood"]) - 2)
	var paid := s.resources.duplicate()
	assert_true(Session.settlement_service.add_resources({"food": -2}).has("error"))
	assert_true(Session.settlement_service.add_resources({"bogus": 1}).has("error"))
	assert_eq(s.resources, paid)
	var added := Session.settlement_service.add_resources({"wood": 1000})
	assert_eq(s.resource_amount("wood"), 40)
	assert_true(int(added["lost"]["wood"]) > 0)
	var bad_building := Content.table("buildings").duplicate(true)
	bad_building["shelter"]["cost"] = {"wood": -10}
	before = s.resources.duplicate()
	assert_fail(ConstructionRules.build(s, "shelter", bad_building, {}, 1))
	assert_eq(s.resources, before)

func test_all_four_buildings_repair_upgrade_and_finish_once() -> void:
	_stock()
	var svc := Session.settlement_service
	for kind in ["shelter", "workshop", "stockpile", "watchpost"]:
		var site: String = "site_" + kind
		assert_ok(svc.request_construction(site, kind))
		var paid := svc.state().resources.duplicate()
		assert_fail(svc.request_construction(site, kind))
		assert_eq(svc.state().resources, paid)
		svc.advance_time(1440)
		var id := String(svc.inspect_site(site)["instance_id"])
		assert_ok(svc.damage_building(id, 100, "acceptance"))
		assert_false(svc.inspect_site(site)["functional"])
		assert_eq(VillageVisuals.site_visual(svc.inspect_site(site)), "building." + kind + ".level_0")
		assert_ok(svc.request_repair(id))
		paid = svc.state().resources.duplicate()
		assert_fail(svc.request_repair(id))
		assert_eq(svc.state().resources, paid)
		assert_ok(Session.save_game())
		assert_ok(Session.load_slot(1))
		svc = Session.settlement_service
		svc.advance_time(1440 * 3)
		assert_eq(svc.inspect_site(site)["condition"], 100)
		assert_ok(svc.request_upgrade(id))
		paid = svc.state().resources.duplicate()
		assert_fail(svc.request_upgrade(id))
		assert_eq(svc.state().resources, paid)
		assert_ok(Session.save_game())
		assert_ok(Session.load_slot(1))
		svc = Session.settlement_service
		svc.advance_time(1440 * 3)
		assert_eq(svc.inspect_site(site)["level"], 2)
		assert_eq(VillageVisuals.site_visual(svc.inspect_site(site)), "building." + kind + ".level_2")
		assert_true(Session.save.validate().is_empty(), str(Session.save.validate()))

func test_workshop_crafting_production_and_worker_limits() -> void:
	_stock()
	var svc := Session.settlement_service
	assert_fail(svc.craft("basic_tools"))
	assert_ok(svc.request_construction("site_workshop", "workshop"))
	svc.advance_time(1440)
	assert_ok(svc.craft("basic_tools"))
	var after := Session.universe().to_dict()
	assert_fail(svc.craft("basic_tools"))
	assert_eq(Session.universe().to_dict(), after)
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	svc = Session.settlement_service
	assert_fail(svc.craft("basic_tools"))
	var wood := svc.state().resource_amount("wood")
	svc.advance_time(1440)
	assert_eq(svc.state().resource_amount("wood"), wood + 2, "workshop + personal tools")
	var worker := svc.state().add_resident("rescued", Session.universe().current_day, "Alda")
	var second := svc.state().add_resident("rescued", Session.universe().current_day, "Bram")
	var id := String(svc.inspect_site("site_workshop")["instance_id"])
	assert_ok(svc.assign_worker(String(worker["resident_id"]), id))
	assert_fail(svc.assign_worker(String(second["resident_id"]), id))
	var salvage := svc.state().resource_amount("salvage")
	svc.advance_time(1440)
	assert_eq(svc.state().resource_amount("salvage"), salvage + 1)
	assert_ok(svc.request_upgrade(id))
	svc.advance_time(2880)
	assert_ok(svc.craft("reinforced_blade"))
	assert_eq(Session.universe().protagonist_condition["equipment_attack"], 3)
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_eq(Session.universe().protagonist_condition["equipment"], "reinforced_blade")

func test_gather_recruit_and_reward_persistence() -> void:
	_start("lumber_camp")
	assert_fail(PoiRules.start(Session.expeditions, "ruined_watchtower"))
	assert_ok(PoiRules.claim(Session.expeditions, "timber_a"))
	assert_ok(PoiRules.claim(Session.expeditions, "survivor"))
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_eq(Session.resume_scene_key(), "poi")
	assert_fail(PoiRules.claim(Session.expeditions, "timber_a"))
	assert_fail(PoiRules.claim(Session.expeditions, "survivor"))
	assert_eq(Session.expeditions.active().haul, {"wood": 18})
	var exp_id := Session.universe().active_expedition_id
	assert_ok(Session.expeditions.finish("returned"))
	assert_eq(Session.settlement().resource_amount("wood"), 24)
	assert_eq(Session.settlement().population, 1)
	assert_eq(Session.universe().expedition_history.size(), 1)
	assert_ok(Session.expeditions.resolve(exp_id))
	assert_eq(Session.settlement().resource_amount("wood"), 24)
	assert_eq(Session.universe().expedition_history.size(), 1)
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	_start("lumber_camp")
	assert_false(PoiRules.available(Session.expeditions, "timber_a"))
	Session.settlement_service.advance_time(1440 * 10)
	assert_true(PoiRules.available(Session.expeditions, "timber_a"))
	assert_false(PoiRules.available(Session.expeditions, "survivor"), "residents never regrow")

func test_shrine_choices_persist_and_affect_defense_separately_from_reputation() -> void:
	_start("forgotten_shrine")
	var reputation := Session.universe().faction("crown_of_aurel").player_reputation
	assert_ok(PoiRules.claim(Session.expeditions, "inscription"))
	assert_fail(PoiRules.claim(Session.expeditions, "altar", "invalid"))
	assert_ok(PoiRules.claim(Session.expeditions, "altar", "honor"))
	assert_eq(Session.character().morality, 10)
	assert_eq(Session.settlement_service.defense_strength(), 2)
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_fail(PoiRules.claim(Session.expeditions, "altar", "plunder"))
	assert_eq(Session.character().morality, 10)
	assert_eq(Session.universe().faction("crown_of_aurel").player_reputation, reputation)
	assert_eq(MapStateStore.get_flag(Session.universe(), "forgotten_shrine", "decision"), "honor")
	assert_eq(Session.character().persistent_lore.size(), 1)

func test_plunder_is_a_distinct_saved_consequence() -> void:
	_start("forgotten_shrine")
	assert_ok(PoiRules.claim(Session.expeditions, "altar", "plunder"))
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_eq(Session.character().morality, -10)
	assert_eq(Session.settlement_service.defense_strength(), 0)
	assert_eq(Session.expeditions.active().haul, {"salvage": 8})
	assert_eq(MapStateStore.get_flag(Session.universe(), "forgotten_shrine", "consequence"), "desecrated")

func test_watchtower_guards_gate_equipment_and_do_not_duplicate_rewards() -> void:
	_start("ruined_watchtower")
	assert_fail(PoiRules.claim(Session.expeditions, "cache"))
	assert_ok(PoiRules.enemy_defeated(Session.expeditions, "guard_a"))
	var haul := Session.expeditions.active().haul.duplicate()
	assert_fail(PoiRules.enemy_defeated(Session.expeditions, "guard_a"))
	assert_eq(Session.expeditions.active().haul, haul)
	assert_fail(PoiRules.claim(Session.expeditions, "cache"))
	assert_ok(PoiRules.enemy_defeated(Session.expeditions, "guard_b"))
	assert_ok(PoiRules.claim(Session.expeditions, "cache"))
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_eq(Session.universe().protagonist_condition["equipment"], "tower_blade")
	assert_eq(Session.universe().protagonist_condition["equipment_attack"], 2)
	assert_fail(PoiRules.claim(Session.expeditions, "cache"))
	assert_true(Session.character().persistent_lore[0].contains("Emberfall"))

func test_five_expedition_grace_then_watchpost_reduces_pressure() -> void:
	Session.universe().threat_state = ThreatRules.init_state(5)
	for i in 5:
		_start("lumber_camp")
		assert_ok(Session.expeditions.finish("returned"))
	assert_eq(Session.universe().threat_state["awareness"], 0)
	_stock()
	var svc := Session.settlement_service
	assert_ok(svc.request_construction("site_watchpost", "watchpost"))
	svc.advance_time(1440)
	var resident := svc.state().add_resident("rescued", 1, "Watcher")
	assert_ok(svc.assign_worker(String(resident["resident_id"]), String(svc.inspect_site("site_watchpost")["instance_id"])))
	assert_eq(svc.defense_strength(), 4)
	_start("lumber_camp")
	assert_ok(Session.expeditions.finish("returned"))
	assert_eq(Session.universe().threat_state["completed_expeditions"], 6)
	assert_eq(Session.universe().threat_state["awareness"], 6, "8 base + 2 building - 4 defense")
	assert_ok(Session.save_game())
	assert_ok(Session.load_slot(1))
	assert_eq(Session.universe().expedition_history.size(), 6)

func test_complete_solo_camp_repair_tower_save_loop() -> void:
	var village: Node = load(Router.SCENES["settlement"]).instantiate()
	tree.root.add_child(village)
	await tree.physics_frame
	var ruin: Dictionary = village.service.inspect_site("site_shelter")
	assert_eq(ruin["state"], "ruin")
	assert_eq(ruin["improvements"][0]["cost"], {"wood": 10})
	village.free()
	var scene: Node = await _open_poi("lumber_camp")
	assert_ok(scene.claim("timber_a"))
	assert_ok(scene.claim("forage"))
	scene.return_home()
	_scene.free()
	_scene = null
	assert_eq(_navigation.back(), "settlement")
	assert_ok(Session.settlement_service.request_construction("site_shelter", "shelter"))
	assert_eq(Session.settlement_service.inspect_site("site_shelter")["level"], 1)
	assert_eq(Session.settlement_service.snapshot()["population"]["capacity"], 12)
	scene = await _open_poi("ruined_watchtower")
	assert_eq(tree.get_nodes_in_group("enemies").size(), 2)
	# Exercise the actual combat damage path on both real enemies.
	for enemy in tree.get_nodes_in_group("enemies"):
		for hit in 30:
			if enemy.combatant.is_alive:
				enemy.take_hit(scene.player)
	assert_ok(scene.claim("cache"))
	scene.return_home()
	_scene.free()
	_scene = null
	assert_ok(Session.load_slot(1))
	assert_eq(Session.settlement_service.inspect_site("site_shelter")["level"], 1)
	assert_eq(Session.universe().expedition_history.size(), 2)
	assert_eq(Session.universe().protagonist_condition["equipment"], "tower_blade")

func test_combat_death_returns_home_with_existing_resurrection_records() -> void:
	var scene: Node = await _open_poi("ruined_watchtower")
	assert_ok(scene.claim("scrap"))
	var attack: int = scene.player.combatant.attack
	assert_true(attack > 0)
	scene.player.combatant.apply_damage(10000)
	assert_eq(_navigation.back(), "settlement")
	assert_eq(Session.universe().death_count, 1)
	assert_eq(Session.universe().active_expedition_id, "")
	assert_eq(Session.universe().location["entry_id"], "hearth")
	assert_eq(Session.settlement().resource_amount("salvage"), 0, "defeat loses pack")
	assert_eq(Session.save.multiverse.completed_transition_ids.size(), 1)
	assert_eq(Session.universe().companion_states, {})
	_scene.free()
	_scene = null
	assert_ok(Session.load_slot(1))
	assert_eq(Session.universe().death_count, 1)
	assert_eq(Session.save.multiverse.completed_transition_ids.size(), 1)

func test_poi_save_restores_position_pack_health_and_objects() -> void:
	var scene: Node = await _open_poi("lumber_camp")
	assert_ok(scene.claim("timber_b"))
	scene.player.position = Vector2(600, 600)
	scene.player.combatant.apply_damage(5)
	var health := DictUtil.get_int(Session.universe().protagonist_condition, "health")
	assert_ok(Session.save_game())
	_scene.free()
	_scene = null
	assert_ok(Session.load_slot(1))
	_scene = load(Router.SCENES[Session.resume_scene_key()]).instantiate()
	tree.root.add_child(_scene)
	await tree.physics_frame
	assert_eq(_scene.player.position.round(), Vector2(600, 600))
	assert_eq(_scene.player.combatant.health, health)
	assert_false(PoiRules.available(Session.expeditions, "timber_b"))
	assert_eq(Session.expeditions.active().haul, {"wood": 18})

func test_shrine_scene_choices_pause_and_resume_combat_input() -> void:
	var scene: Node = await _open_poi("forgotten_shrine")
	scene.interact_object("altar")
	assert_true(tree.paused)
	assert_false(scene.player.input_enabled)
	assert_eq(scene.choices_box.get_child_count(), 5)
	assert_ok(scene.claim("altar", "honor"))
	assert_false(tree.paused)
	assert_true(scene.player.input_enabled)
	assert_eq(scene.choices_box.get_child_count(), 0)

func test_schema2_migration_preserves_legacy_resources_and_residents() -> void:
	# Frozen schema 2 output of Stage 1's original 1->2 migration on the real
	# schema 1 fixture. Generated once with that unchanged production migration.
	var legacy: Dictionary = JSON.parse_string(TestCase.read_text("res://tests/fixtures/save_schema2_stage1_migrated.json"))
	assert_eq(legacy["schema_version"], 2)
	var migrated := SaveValidator.build_and_validate(legacy)
	assert_ok(migrated)
	assert_eq(migrated.value.universe.home_settlement().population, 7)
	assert_eq(migrated.value.universe.home_settlement().resource_amount("wood"), 12)
	assert_eq(migrated.value.universe.home_settlement().resource_amount("iron"), 0)
	var raw := Session.save.to_dict()
	raw["schema_version"] = 2
	var condition: Dictionary = raw["universe"]["protagonist_condition"]
	condition.erase("tools")
	condition.erase("equipment")
	condition.erase("equipment_attack")
	raw["universe"]["settlements"]["stl_emberfall"]["resources"].erase("salvage")
	var r := SaveValidator.build_and_validate(raw)
	assert_ok(r)
	assert_eq(r.value.schema_version, 3)
	assert_eq(r.value.universe.protagonist_condition["tools"], [])
	assert_eq(r.value.universe.home_settlement().resource_amount("wood"), 6)
	assert_eq(r.value.universe.home_settlement().resource_amount("salvage"), 0)

func test_poi_content_and_visual_references_are_valid() -> void:
	assert_eq(Content.load_errors, [])
	for id in Content.ids("pois"):
		var poi: Dictionary = Content.table("pois")[id]
		var layout := MapDefinition.from_dict(poi["layout"])
		assert_eq(layout.validate(), [])
		assert_true(Visuals.has_visual(layout.ground_base))
		for object in poi["objects"]:
			assert_true(Visuals.has_visual(String(object["visual"])))
		for enemy in poi["enemies"]:
			assert_true(Visuals.has_visual("actor.enemy." + String(enemy["enemy_id"])))

func test_personal_gathering_uses_the_shared_interaction_input() -> void:
	var scene: Node = await _open_poi("lumber_camp")
	scene.player.position = scene.objects["timber_a"].position + Vector2(0, 16)
	for i in 4:
		await tree.physics_frame
	Input.action_press("interact")
	await tree.physics_frame
	Input.action_release("interact")
	await tree.physics_frame
	assert_eq(Session.expeditions.active().haul, {"wood": 18})
	Input.action_press("interact")
	await tree.physics_frame
	Input.action_release("interact")
	assert_eq(Session.expeditions.active().haul, {"wood": 18}, "repeated input does not gather twice")

func test_poi_level_up_updates_the_live_combatant_and_equipment_bonus() -> void:
	Session.universe().protagonist_condition["equipment_attack"] = 3
	Session.universe().protagonist_condition["equipment"] = "reinforced_blade"
	var scene: Node = await _open_poi("ruined_watchtower")
	var levels := Session.expeditions.grant_experience(100)
	assert_true(levels > 0)
	assert_eq(scene.player.combatant.attack, ProgressionRules.attack(Session.character(), Content.balance("character")) + 3)
	assert_eq(scene.player.combatant.health, ProgressionRules.max_health(Session.character(), Content.balance("character")))
	assert_ok(PoiRules.enemy_defeated(Session.expeditions, "guard_a"))
	assert_ok(PoiRules.enemy_defeated(Session.expeditions, "guard_b"))
	assert_ok(PoiRules.claim(Session.expeditions, "cache"))
	assert_eq(Session.universe().protagonist_condition["equipment"], "reinforced_blade", "tower cache cannot downgrade a crafted blade")

func test_failed_return_save_can_retry_without_resolving_twice() -> void:
	var scene: Node = await _open_poi("lumber_camp")
	assert_ok(scene.claim("timber_a"))
	var repository := Session.repository
	Session.repository = FailedWrites.new(temp_dir + "/failure")
	scene.return_home()
	assert_eq(_navigation, [])
	assert_true(scene.prompt_label.text.contains("SAVE FAILED"))
	assert_eq(Session.universe().expedition_history.size(), 1)
	Session.repository = repository
	scene._autosave("Retry")
	assert_eq(_navigation, ["settlement"])
	assert_eq(Session.universe().expedition_history.size(), 1)
	assert_eq(Session.settlement().resource_amount("wood"), 24)

func test_failed_departure_save_retries_the_same_expedition() -> void:
	_scene = load(Router.SCENES["world_map"]).instantiate()
	tree.root.add_child(_scene)
	await tree.process_frame
	var repository := Session.repository
	Session.repository = FailedWrites.new(temp_dir + "/failure")
	_scene._begin_poi("lumber_camp")
	var id := Session.universe().active_expedition_id
	assert_eq(_navigation, [])
	assert_true(_scene._status.text.contains("SAVE FAILED"))
	Session.repository = repository
	_scene._begin_poi("lumber_camp")
	assert_eq(Session.universe().active_expedition_id, id)
	assert_eq(_navigation, ["poi"])
