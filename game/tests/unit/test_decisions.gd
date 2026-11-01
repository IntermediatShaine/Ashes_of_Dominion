extends TestCase
## Narrative decisions and faction reactivity through the pure rules
## (no scenes): per-area selection, reputation-gated prompts and options,
## consequences of every Crown patrol choice, once-only resolution, and the
## morality / reputation separation.


func _bound(archetype: String = "village_hunter", seed_value: int = 4711) -> TestFixtures.Bound:
	var b := TestFixtures.bind(TestFixtures.new_save(seed_value, "challenging", archetype))
	var r := b.expeditions.start("ashen_crossroads", b.expeditions.plan_routes("ashen_crossroads")[0])
	assert_ok(r)
	return b


func _patrol() -> Dictionary:
	return Content.get_def("decisions", "crown_patrol")


func _crown(b: TestFixtures.Bound) -> FactionState:
	return b.save.universe.faction("crown_of_aurel")


func test_selection_priority_then_patrol_after_survivor() -> void:
	var b := _bound()
	var u := b.save.universe
	var decisions := Content.table("decisions")
	assert_eq(DecisionRules.select_for_area(decisions, u, "marches", "ashen_crossroads"), "stranded_survivor", "lower priority number goes first")
	assert_eq(DecisionRules.select_for_area(decisions, u, "eldergrove", "greywood_edge"), "stranded_survivor")
	assert_eq(DecisionRules.select_for_area(decisions, u, "crypt", "sunken_chapel"), "", "no decision for the crypt")
	u.decision_log["stranded_survivor"] = "ignore"
	assert_eq(DecisionRules.select_for_area(decisions, u, "marches", "ashen_crossroads"), "crown_patrol")
	assert_eq(DecisionRules.select_for_area(decisions, u, "marches", "aurel_border_fort"), "crown_patrol")
	assert_eq(DecisionRules.select_for_area(decisions, u, "marches", "emberfall"), "", "patrol is restricted to its landmarks")
	assert_eq(DecisionRules.select_for_area(decisions, u, "eldergrove", "greywood_edge"), "", "patrol never appears in the forest")
	u.decision_log["crown_patrol"] = "trade"
	assert_eq(DecisionRules.select_for_area(decisions, u, "marches", "ashen_crossroads"), "", "everything resolved => no npc")


func test_prompt_and_options_follow_crown_reputation_bands() -> void:
	var b := _bound()
	var u := b.save.universe
	var exp := u.active_expedition()
	var patrol := _patrol()
	# village hunter starts Neutral (+10)
	assert_eq(ReputationRules.label(_crown(b).player_reputation), "Neutral")
	assert_eq(DecisionRules.prompt_for(patrol, u), DictUtil.get_string(patrol, "prompt"), "neutral band uses the default prompt")
	var opts := DecisionRules.visible_options(patrol, u)
	assert_eq(DictUtil.sorted_keys(opts), ["bribe", "defy", "escort", "trade"], "'fight' is hidden unless the Crown distrusts you")
	assert_ne(DecisionRules.blocking_reason(opts["escort"], exp, u), "", "escort needs Friendly standing")
	assert_eq(DecisionRules.blocking_reason(opts["trade"], exp, u), "")
	assert_ne(DecisionRules.blocking_reason(opts["bribe"], exp, u), "", "bribe needs iron in the pack")
	# Friendly (>= 20): escort unlocks, prompt changes
	_crown(b).player_reputation = 20
	assert_true(DecisionRules.prompt_for(patrol, u).contains("remembers its debts"))
	assert_eq(DecisionRules.blocking_reason(opts["escort"], exp, u), "")
	assert_eq(DictUtil.sorted_keys(DecisionRules.visible_options(patrol, u)), ["bribe", "defy", "escort", "trade"])
	# Distrusted (<= -20): hostile prompt, trade and escort blocked, fight appears
	_crown(b).player_reputation = -20
	assert_true(DecisionRules.prompt_for(patrol, u).contains("has your description"))
	var hostile := DecisionRules.visible_options(patrol, u)
	assert_eq(DictUtil.sorted_keys(hostile), ["bribe", "defy", "escort", "fight", "trade"])
	assert_ne(DecisionRules.blocking_reason(hostile["trade"], exp, u), "", "they will not deal with you")
	assert_ne(DecisionRules.blocking_reason(hostile["escort"], exp, u), "")
	assert_eq(DecisionRules.blocking_reason(hostile["fight"], exp, u), "")
	assert_eq(DecisionRules.blocking_reason(hostile["defy"], exp, u), "", "defiance is always open")
	# exactly at the threshold edges
	_crown(b).player_reputation = -19
	assert_eq(DecisionRules.blocking_reason(DecisionRules.visible_options(patrol, u)["trade"], exp, u), "", "-19 is still Neutral")
	assert_false(DecisionRules.visible_options(patrol, u).has("fight"))
	_crown(b).player_reputation = 19
	assert_ne(DecisionRules.blocking_reason(DecisionRules.visible_options(patrol, u)["escort"], exp, u), "", "19 is not yet Friendly")


func test_archetypes_land_in_different_bands_by_ancestry() -> void:
	# The same encounter reads differently per protagonist before any choice is made.
	var human := _bound("village_hunter")
	var ashborn := _bound("ashborn")
	assert_eq(ReputationRules.label(_crown(human).player_reputation), "Neutral")
	assert_eq(ReputationRules.label(_crown(ashborn).player_reputation), "Hunted", "human/demonkin starts hunted by the Crown")
	assert_true(DecisionRules.visible_options(_patrol(), ashborn.save.universe).has("fight"))
	assert_false(DecisionRules.visible_options(_patrol(), human.save.universe).has("fight"))
	# morality is identical: standing comes from ancestry and deeds, not from character alignment
	assert_eq(human.save.character.morality, ashborn.save.character.morality)


func test_escort_choice_consequences() -> void:
	var b := _bound()
	var u := b.save.universe
	_crown(b).player_reputation = 20
	var legion_before := u.faction("ashen_legion").player_reputation
	var r := DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "escort")
	assert_ok(r)
	assert_eq(b.save.character.morality, 5)
	assert_eq(_crown(b).player_reputation, 30)
	assert_eq(u.faction("ashen_legion").player_reputation, legion_before - 5, "riding with the Crown costs Legion standing")
	assert_eq(int(u.active_expedition().haul.get("iron", 0)), 2, "paid in iron")
	assert_eq(u.decision_log["crown_patrol"], "escort")


func test_trade_bribe_defy_consequences_are_distinct() -> void:
	var trade := _bound()
	assert_ok(DecisionRules.resolve(trade.save, "crown_patrol", _patrol(), "trade"))
	assert_eq(trade.save.character.morality, 0, "trade is morally neutral")
	assert_eq(_crown(trade).player_reputation, 13)
	assert_eq(int(trade.save.universe.active_expedition().haul.get("food", 0)), 2)

	var bribe := _bound()
	assert_fail(DecisionRules.resolve(bribe.save, "crown_patrol", _patrol(), "bribe"), "no iron, no bribe")
	assert_false(bribe.save.universe.decision_log.has("crown_patrol"), "a refused option leaves the decision open")
	bribe.save.universe.active_expedition().add_haul("iron", 1)
	assert_ok(DecisionRules.resolve(bribe.save, "crown_patrol", _patrol(), "bribe"))
	assert_eq(int(bribe.save.universe.active_expedition().haul.get("iron", 0)), 0, "the iron is spent")
	assert_eq(_crown(bribe).player_reputation, 15)

	var defy := _bound()
	var legion_before := defy.save.universe.faction("ashen_legion").player_reputation
	assert_ok(DecisionRules.resolve(defy.save, "crown_patrol", _patrol(), "defy"))
	assert_eq(_crown(defy).player_reputation, 0)
	assert_eq(defy.save.universe.faction("ashen_legion").player_reputation, legion_before + 5)
	assert_eq(defy.save.universe.home_settlement().pending_recruits, 1, "a conscript deserts to Emberfall")
	assert_eq(defy.save.character.morality, 0, "defiance is not a moral act")


func test_fight_only_when_distrusted_and_wounds_but_never_kills() -> void:
	var b := _bound()
	var u := b.save.universe
	assert_fail(DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "fight"), "hidden option cannot be forced while Neutral")
	_crown(b).player_reputation = -20
	u.protagonist_condition["health"] = 4
	var r := DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "fight")
	assert_ok(r)
	assert_eq(int(u.protagonist_condition["health"]), 1, "a dialogue wound stops at 1 health")
	assert_eq(int(r.value["health"]), -3, "summary reports the damage actually applied")
	assert_eq(b.save.character.morality, -10)
	assert_eq(_crown(b).player_reputation, -40)
	assert_eq(int(u.active_expedition().haul.get("iron", 0)), 1)


func test_resolving_twice_never_duplicates_consequences() -> void:
	var b := _bound()
	var u := b.save.universe
	assert_ok(DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "defy"))
	var snapshot := b.save.to_dict()
	assert_fail(DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "defy"))
	assert_fail(DecisionRules.resolve(b.save, "crown_patrol", _patrol(), "trade"), "a different option is refused too")
	assert_eq(b.save.to_dict(), snapshot, "nothing changed on the repeated attempts")
	# the event-id guards also hold if someone bypasses the decision log
	var f := _crown(b)
	var event_id := "%s:crown_patrol:defy" % u.universe_id
	assert_eq(ReputationRules.apply_event(f, event_id, "crown_patrol", -10, u.current_day), 0)
	assert_eq(f.player_reputation, 0)


func test_reputation_gate_never_reads_morality() -> void:
	var b := _bound()
	var u := b.save.universe
	b.save.character.morality = -100
	_crown(b).player_reputation = 50
	assert_eq(DecisionRules.blocking_reason(_patrol()["options"]["escort"], u.active_expedition(), u), "", "a monster the Crown trusts is still trusted")
	b.save.character.morality = 100
	_crown(b).player_reputation = -60
	assert_ne(DecisionRules.blocking_reason(_patrol()["options"]["trade"], u.active_expedition(), u), "", "a saint the Crown hunts is still hunted")
	assert_true(DecisionRules.visible_options(_patrol(), u).has("fight"))


func test_stranded_survivor_still_works() -> void:
	var b := _bound()
	var u := b.save.universe
	var survivor := Content.get_def("decisions", "stranded_survivor")
	assert_eq(DecisionRules.prompt_for(survivor, u), DictUtil.get_string(survivor, "prompt"), "no reputation variants => plain prompt")
	assert_eq(DictUtil.sorted_keys(DecisionRules.visible_options(survivor, u)), ["help", "ignore", "rob"])
	u.active_expedition().add_haul("food", 2)
	assert_ok(DecisionRules.resolve(b.save, "stranded_survivor", survivor, "help"))
	assert_eq(b.save.character.morality, 15)
	assert_eq(_crown(b).player_reputation, 20)
	assert_eq(u.home_settlement().pending_recruits, 1)
