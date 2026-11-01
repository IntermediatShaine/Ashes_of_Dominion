extends TestCase
## The Crown patrol encounter through the real game path: it is reached by
## normal play (second marches expedition after the survivor), the HUD shows
## the reputation-aware dialog, the scene applies the choice, and the result
## survives save → load (in-process) with the NPC gone on the next visit.

var _nav: Array[String] = []
var _saved_repo: SaveRepository


func before_each() -> void:
	_saved_repo = Session.repository
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	Router.navigation_hook = func(key: String): _nav.append(key)
	_nav.clear()


func after_each() -> void:
	Session.end_session()
	Session.repository = _saved_repo
	Router.navigation_hook = Callable()
	tree.paused = false


func _new_game(archetype: String = "village_hunter", seed_value: int = 2468) -> void:
	var d := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	assert_ok(Session.new_game({"name": "Envoy", "archetype_id": archetype, "difficulty": d.value, "mist_enabled": true, "seed": seed_value}, 1))


func _open_exploration(destination: String) -> Node:
	var routes := Session.expeditions.plan_routes(destination)
	assert_ok(Session.expeditions.start(destination, routes[0]))
	var packed: PackedScene = load(Router.SCENES["exploration"])
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	await tree.physics_frame
	await tree.physics_frame
	return scene


func _close(scene: Node) -> void:
	scene.queue_free()
	await tree.process_frame


func _buttons(scene: Node) -> Dictionary:
	var out := {}
	for c in scene.hud._decision_body.get_children():
		if c is Button:
			out[c.text] = c
	return out


func test_patrol_is_reached_by_normal_play_and_reacts_to_standing() -> void:
	_new_game()
	# First marches trip: the survivor, as before. Help her (Crown +10 => Friendly).
	var first := await _open_exploration("ashen_crossroads")
	assert_eq(first._npc.decision_id, "stranded_survivor")
	assert_eq(first._npc.interaction_prompt(), "Talk")
	Session.expeditions.active().add_haul("food", 2)
	first._on_npc_talked("stranded_survivor")
	first._on_decision_chosen("stranded_survivor", "help")
	first.hud.close_decision()
	first._on_exit_requested()
	assert_eq(_nav, ["settlement"])
	await _close(first)
	assert_eq(Session.universe().faction("crown_of_aurel").player_reputation, 20)

	# Second marches trip: the patrol is the area's NPC, placed on a reachable cell.
	var second := await _open_exploration("ashen_crossroads")
	assert_true(second._npc != null, "a decision NPC spawned")
	assert_eq(second._npc.decision_id, "crown_patrol")
	assert_eq(second._npc.interaction_prompt(), "Hail the patrol")
	assert_true(second.map.reachable_from_spawn().has(second.map.npc_spawn["cell"]), "patrol reachable on foot")
	# Friendly dialog: warm prompt, escort enabled, no 'fight'
	second._on_npc_talked("crown_patrol")
	assert_true(second.hud.is_modal_open())
	var labels: Array[String] = []
	for c in second.hud._decision_body.get_children():
		if c is Label:
			labels.append(c.text)
	assert_true("".join(labels).contains("remembers its debts"), "friendly prompt shown")
	var buttons := _buttons(second)
	assert_eq(buttons.size(), 4)
	assert_true(buttons.has("Offer to guide them through marauder country"))
	assert_false(buttons["Offer to guide them through marauder country"].disabled, "escort offered to a trusted character")
	var fight_shown := false
	for text in buttons.keys():
		if String(text).begins_with("Cut your way"):
			fight_shown = true
	assert_false(fight_shown, "no fight option for a friend of the Crown")
	# choose escort through the scene path
	var iron_before := int(Session.expeditions.active().haul.get("iron", 0))
	second._on_decision_chosen("crown_patrol", "escort")
	assert_eq(Session.universe().faction("crown_of_aurel").player_reputation, 30)
	assert_eq(Session.character().morality, 20)
	assert_eq(int(Session.expeditions.active().haul.get("iron", 0)), iron_before + 2)
	assert_true(second._npc.resolved)
	assert_eq(second._npc.interaction_prompt(), "Nothing more to say")
	second.hud.close_decision()
	second._on_exit_requested()
	await _close(second)
	assert_true(Session.repository.slot_exists(1))

	# Reload: the choice is recorded, and the third visit has no NPC left.
	Session.end_session()
	assert_ok(Session.continue_latest())
	assert_eq(Session.universe().decision_log["crown_patrol"], "escort")
	assert_eq(Session.universe().faction("crown_of_aurel").player_reputation, 30)
	assert_eq(Session.character().morality, 20)
	var third := await _open_exploration("ashen_crossroads")
	assert_true(third._npc == null, "both marches decisions resolved => no npc")
	third._on_retreat()
	await _close(third)


func test_hostile_patrol_for_a_hunted_character_and_wound_applies_to_live_player() -> void:
	_new_game("ashborn", 9001)   # human/demonkin: Crown reputation starts at -60 ("Hunted")
	Session.universe().decision_log["stranded_survivor"] = "ignore"   # skip straight to the patrol
	var scene := await _open_exploration("ashen_crossroads")
	assert_eq(scene._npc.decision_id, "crown_patrol")
	scene._on_npc_talked("crown_patrol")
	var buttons := _buttons(scene)
	assert_eq(buttons.size(), 5, "'fight' is now listed")
	assert_true(buttons["Offer to guide them through marauder country  — " + DecisionRules.blocking_reason(Content.get_def("decisions", "crown_patrol")["options"]["escort"], Session.expeditions.active(), Session.universe())].disabled)
	var trade_key := ""
	for text in buttons.keys():
		if String(text).begins_with("Trade news"):
			trade_key = String(text)
	assert_true(trade_key.contains("Hunted"), "the reason names the player's standing")
	assert_true(buttons[trade_key].disabled, "the Crown will not trade with the hunted")
	var hp_before: int = scene.player.combatant.health
	scene._on_decision_chosen("crown_patrol", "fight")
	assert_eq(scene.player.combatant.health, hp_before - 6, "the live body takes the dialogue wound")
	assert_eq(int(Session.universe().protagonist_condition["health"]), hp_before - 6)
	assert_eq(Session.universe().faction("crown_of_aurel").player_reputation, -80)
	assert_eq(Session.character().morality, -10)
	scene.hud.close_decision()
	scene._on_exit_requested()
	await _close(scene)
	# the wound persists into the autosave
	Session.end_session()
	assert_ok(Session.continue_latest())
	assert_eq(Session.universe().decision_log["crown_patrol"], "fight")
	assert_eq(ReputationRules.label(Session.universe().faction("crown_of_aurel").player_reputation), "Hunted")


func test_patrol_never_spawns_in_the_forest_and_survivor_unchanged_there() -> void:
	_new_game()
	Session.universe().decision_log["stranded_survivor"] = "ignore"
	var forest := await _open_exploration("greywood_edge")
	assert_true(forest._npc == null, "no Crown patrol in the Greywood")
	forest._on_retreat()
	await _close(forest)
	Session.end_session()
	_new_game("village_hunter", 777)
	var forest2 := await _open_exploration("greywood_edge")
	assert_eq(forest2._npc.decision_id, "stranded_survivor", "the survivor still appears in the forest first")
	forest2._on_retreat()
	await _close(forest2)
