extends TestCase
## Unit tests for isolated game rules (no scenes, no Session).


func _char() -> CharacterState:
	var r := CharacterFactory.create("Unit", "village_hunter", Content.get_def("archetypes", "village_hunter"), Content.table("ancestries"))
	assert_ok(r)
	return r.value


func test_character_factory_applies_ancestry_modifiers() -> void:
	var r := CharacterFactory.create("Dw", "forge_exile", Content.get_def("archetypes", "forge_exile"), Content.table("ancestries"))
	assert_ok(r)
	var c: CharacterState = r.value
	# forge_exile: strength 7 + dwarf +1 = 8; dexterity 4 - 1 = 3
	assert_eq(c.attribute("strength"), 8)
	assert_eq(c.attribute("dexterity"), 3)
	assert_eq(c.current_class, "survivor")
	assert_false(c.is_mixed_ancestry())
	var mixed := CharacterFactory.create("Ash", "ashborn", Content.get_def("archetypes", "ashborn"), Content.table("ancestries"))
	assert_ok(mixed)
	assert_true((mixed.value as CharacterState).is_mixed_ancestry())
	# ashborn: willpower 7 + demonkin(+2)*0.5 = 8
	assert_eq((mixed.value as CharacterState).attribute("willpower"), 8)
	assert_fail(CharacterFactory.create("   ", "ashborn", Content.get_def("archetypes", "ashborn"), Content.table("ancestries")), "blank name")


func test_experience_and_levels() -> void:
	var c := _char()
	var prog := Content.balance("progression")
	var growth := DictUtil.get_dict(Content.get_def("archetypes", "village_hunter"), "level_growth")
	var end_before := c.attribute("endurance")
	assert_eq(ProgressionRules.add_experience(c, 0, prog, growth), 0)
	var need := ProgressionRules.xp_for_next_level(1, prog)
	assert_eq(ProgressionRules.add_experience(c, need - 1, prog, growth), 0)
	assert_eq(c.level, 1)
	assert_eq(ProgressionRules.add_experience(c, 1, prog, growth), 1)
	assert_eq(c.level, 2)
	assert_eq(c.experience, 0)
	assert_eq(c.attribute("endurance"), end_before + 1)
	# Multi-level jump
	var big := ProgressionRules.xp_for_next_level(2, prog) + ProgressionRules.xp_for_next_level(3, prog) + 3
	assert_eq(ProgressionRules.add_experience(c, big, prog, growth), 2)
	assert_eq(c.level, 4)
	assert_eq(c.experience, 3)
	assert_true(c.validate().is_empty(), str(c.validate()))


func test_class_prerequisites() -> void:
	var c := _char()
	var classes := Content.table("classes")
	assert_true(ClassRules.meets_prerequisites(c, classes["survivor"]))
	assert_false(ClassRules.meets_prerequisites(c, classes["warden"]))
	c.level = 5
	c.morality = 25
	assert_true(ClassRules.meets_prerequisites(c, classes["warden"]))
	assert_false(ClassRules.meets_prerequisites(c, classes["reaver"]))
	var newly := ClassRules.refresh_unlocks(c, classes)
	assert_eq(newly, ["warden"])
	assert_eq(ClassRules.refresh_unlocks(c, classes), [])


func test_combat_damage() -> void:
	var rules := Content.balance("combat")
	assert_eq(CombatRules.resolve_damage(5, 0, rules, null), 5)
	assert_eq(CombatRules.resolve_damage(5, 4, rules, null), 3)   # 5 - floor(4*0.5)
	assert_eq(CombatRules.resolve_damage(1, 10, rules, null), 1)  # never below min
	var rng := RngStream.new("combat", 1)
	for i in 100:
		var d := CombatRules.resolve_damage(10, 0, rules, rng)
		assert_true(d >= 8 and d <= 12, "variance out of range: %d" % d)
	var scaled := CombatRules.scaled_enemy_stats(Content.get_def("enemies", "marauder"), {"enemy_health_multiplier": 0.5, "enemy_damage_multiplier": 2.0})
	assert_eq(scaled["max_health"], 6)
	assert_eq(scaled["attack"], 6)


func test_combatant() -> void:
	var c := Combatant.create("e", 10, 3, 1)
	assert_eq(c.apply_damage(4), 4)
	assert_eq(c.health, 6)
	assert_eq(c.apply_damage(100), 6)
	assert_false(c.is_alive)
	assert_eq(c.apply_damage(5), 0, "dead combatants take no damage")


func test_construction_rules_all_or_nothing() -> void:
	var s := TestFixtures.new_save().universe.home_settlement()
	var defs := Content.table("buildings")
	var counters := {}
	s.resources = {"wood": 5, "stone": 0, "food": 0, "iron": 0}
	var r := ConstructionRules.build(s, "shelter", defs, counters, 1)
	assert_fail(r, "not enough wood")
	assert_eq(s.resources["wood"], 5, "failed build must not deduct")
	assert_eq(s.buildings.size(), 0)
	s.resources["wood"] = 10
	assert_fail(ConstructionRules.build(s, "palisade", defs, counters, 1), "palisade requires shelter")
	r = ConstructionRules.build(s, "shelter", defs, counters, 1)
	assert_ok(r)
	assert_eq(s.resources["wood"], 0)
	assert_eq(s.buildings.size(), 1)
	assert_eq(String(s.buildings[0]["instance_id"]), "bld_000001")
	assert_eq(SettlementRules.population_capacity(s, defs), s.base_population_capacity + 4)
	assert_fail(ConstructionRules.build(s, "unknown_building", defs, counters, 1))


func test_settlement_tick_and_storage_cap() -> void:
	var s := TestFixtures.new_save().universe.home_settlement()
	var defs := Content.table("buildings")
	var bal := Content.balance("settlement")
	s.resources = {"wood": 30, "stone": 0, "food": 0, "iron": 0}
	s.base_storage_capacity = 32
	s.buildings.append({"instance_id": "bld_x", "definition_id": "woodcutters_camp", "built_day": 1})
	var morale_before := s.morale
	var summary := SettlementRules.tick_day(s, defs, bal)
	assert_eq(s.resources["wood"], 32, "capped at storage")
	assert_eq(summary["produced"]["wood"], 2)
	assert_true(summary["starved"], "no food -> starving")
	assert_true(s.morale < morale_before)
	s.resources["food"] = 10
	SettlementRules.tick_day(s, defs, bal)
	assert_true(s.resources["food"] < 10, "food is consumed")


func test_morality_and_reputation_are_independent() -> void:
	var save := TestFixtures.new_save()
	var c := save.character
	var f := save.universe.faction("crown_of_aurel")
	var rep_before := f.player_reputation
	assert_eq(MoralityRules.apply_event(c, "evt1", "test", 15, "u"), 15)
	assert_eq(c.morality, 15)
	assert_eq(f.player_reputation, rep_before, "morality change must not touch reputation")
	assert_eq(MoralityRules.apply_event(c, "evt1", "test", 15, "u"), 0, "same event id applies once")
	assert_eq(ReputationRules.apply_event(f, "evt2", "test", -30, 1), -30)
	assert_eq(c.morality, 15, "reputation change must not touch morality")
	assert_eq(ReputationRules.apply_event(f, "evt2", "test", -30, 1), 0)
	c.morality = 95
	assert_eq(MoralityRules.apply_event(c, "evt3", "test", 50, "u"), 5, "clamped at 100")


func test_initial_reputation_for_mixed_ancestry() -> void:
	var human := TestFixtures.new_save(1, "challenging", "village_hunter")
	var mixed := TestFixtures.new_save(1, "challenging", "ashborn")
	var crown_def := Content.get_def("factions", "crown_of_aurel")
	assert_eq(human.universe.faction("crown_of_aurel").player_reputation, 10)
	# human 10 + demonkin(-60)*0.5 + penalty(-40) = -60
	assert_eq(mixed.universe.faction("crown_of_aurel").player_reputation, -60)
	assert_eq(ReputationRules.initial_reputation(mixed.character, crown_def), -60)


func test_threat_grace_period() -> void:
	var t := ThreatRules.init_state(2)
	var bal := Content.balance("threat")
	assert_eq(ThreatRules.on_expedition_resolved(t, 0, bal), 0)
	assert_eq(ThreatRules.on_expedition_resolved(t, 0, bal), 0)
	assert_eq(t["awareness"], 0)
	assert_eq(ThreatRules.expeditions_remaining_in_grace(t), 0)
	assert_true(ThreatRules.on_expedition_resolved(t, 2, bal) > 0, "awareness rises after grace")
	assert_eq(t["completed_expeditions"], 3)
	assert_eq(ThreatRules.band(t, bal)["label"], "Stirring")


func test_difficulty_rules() -> void:
	var table := Content.table("difficulty")
	var r := DifficultyRules.from_preset("hard", table)
	assert_ok(r)
	assert_eq(r.value["grace_period_expeditions"], 4)
	assert_fail(DifficultyRules.from_preset("impossible", table))
	var custom := DifficultyRules.customize(r.value, {"enemy_damage_multiplier": 2.5}, table)
	assert_ok(custom)
	assert_true(custom.value["custom"])
	assert_fail(DifficultyRules.customize(r.value, {"enemy_damage_multiplier": 99.0}, table), "out of range")
	assert_fail(DifficultyRules.customize(r.value, {"grace_period_expeditions": "five"}, table), "non numeric")
	assert_true(DifficultyRules.is_functional("enemy_damage_multiplier", table))
	assert_false(DifficultyRules.is_functional("raid_frequency_multiplier", table))
