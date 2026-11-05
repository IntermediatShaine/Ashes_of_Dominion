extends TestCase
## Scene-level integration: every gameplay scene instantiates with a real
## session, and the exploration scene can be played through programmatically
## (move, hit an enemy, harvest, talk, exit) with physics running headless.

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


func _new_game() -> void:
	var d := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	var r := Session.new_game({"name": "SceneTester", "archetype_id": "village_hunter", "difficulty": d.value, "mist_enabled": true, "seed": 2468}, 1)
	assert_ok(r)


func _instance(path: String) -> Node:
	var packed: PackedScene = load(path)
	assert_true(packed != null, "scene loads: " + path)
	var node := packed.instantiate()
	tree.root.add_child(node)
	return node


func test_menu_scenes_instantiate() -> void:
	for key in ["main_menu", "new_game", "load_game", "settings"]:
		var node := _instance(Router.SCENES[key])
		await tree.process_frame
		assert_true(node.get_child_count() > 0, key + " built its UI")
		node.queue_free()
		await tree.process_frame


func test_settlement_and_map_with_game() -> void:
	_new_game()
	# The management screen from before the walkable village; "settlement" is
	# the village scene now (tests/integration/test_village_scene.gd).
	var settlement := _instance(Router.SCENES["settlement_legacy"])
	await tree.process_frame
	assert_true(settlement.get_child_count() > 0)
	# Construction through the real UI path: Session.construct_building + autosave
	Session.settlement().resources["wood"] = 20
	settlement._on_build("shelter")
	assert_eq(Session.settlement().buildings.size(), 1)
	assert_true(Session.repository.slot_exists(1))
	settlement.queue_free()
	await tree.process_frame

	var map := _instance(Router.SCENES["world_map"])
	await tree.process_frame
	assert_true(map._is_visible_node("emberfall"))
	assert_false(map._is_visible_node("cinder_pass"), "mist hides undiscovered landmarks")
	map._select("greywood_edge")
	assert_true(map._routes.size() >= 1)
	map._on_begin()
	assert_eq(_nav, ["exploration"])
	assert_true(Session.expeditions.active() != null)
	map.queue_free()
	await tree.process_frame


func test_exploration_playthrough() -> void:
	_new_game()
	var routes := Session.expeditions.plan_routes("ashen_crossroads")
	assert_ok(Session.expeditions.start("ashen_crossroads", routes[0]))
	var scene := _instance(Router.SCENES["exploration"])
	await tree.physics_frame
	await tree.physics_frame
	var player: Node = scene.player
	assert_true(player != null)
	var enemies := tree.get_nodes_in_group("enemies")
	assert_true(enemies.size() >= 3, "enemies spawned")
	var interactables := tree.get_nodes_in_group("interactables")
	assert_true(interactables.size() >= 3, "resources + exit spawned")

	# movement: push input and let physics run
	Input.action_press("move_right")
	var start_x: float = player.position.x
	for i in 10:
		await tree.physics_frame
	Input.action_release("move_right")
	assert_true(player.position.x > start_x + 10.0, "player moved right")
	assert_eq(player.facing, Vector2(1, 0))

	# combat: hit an enemy directly through the same entry point the hitbox uses
	var enemy: Node = enemies[0]
	var hp_before: int = enemy.combatant.health
	var kills_before: int = Session.expeditions.active().enemies_defeated
	enemy.take_hit(player)
	assert_true(enemy.combatant.health < hp_before)
	while enemy.combatant.is_alive:
		enemy.take_hit(player)
	await tree.physics_frame
	assert_eq(Session.expeditions.active().enemies_defeated, kills_before + 1)
	assert_true(Session.character().experience > 0 or Session.character().level > 1)

	# enemy strikes the player
	var php_before: int = player.combatant.health
	enemy = enemies[1]
	enemy._player = player
	enemy._strike(0.0, 100.0)
	assert_true(player.combatant.health < php_before, "enemy damage applied")
	assert_eq(Session.universe().protagonist_condition["health"], player.combatant.health)

	# harvest
	var resource: Node = null
	for n in interactables:
		if n.has_method("interaction_prompt") and "resource_id" in n and not n.depleted:
			resource = n
			break
	assert_true(resource != null, "found a resource node")
	var haul_before := int(Session.expeditions.active().haul.get(resource.resource_id, 0))
	resource.interact(player)
	assert_eq(int(Session.expeditions.active().haul.get(resource.resource_id, 0)), haul_before + resource.amount)
	resource.interact(player)
	assert_eq(int(Session.expeditions.active().haul.get(resource.resource_id, 0)), haul_before + resource.amount, "harvest once")

	# decision via the HUD path
	assert_true(scene._npc != null, "survivor present in the marches")
	Session.expeditions.active().add_haul("food", 2)
	scene._on_npc_talked("stranded_survivor")
	assert_true(scene.hud.is_modal_open())
	scene._on_decision_chosen("stranded_survivor", "help")
	assert_eq(Session.character().morality, 15)
	assert_true(scene._npc.resolved)
	scene.hud.close_decision()

	# return home
	scene._on_exit_requested()
	assert_eq(_nav, ["settlement"])
	assert_true(Session.expeditions.active() == null)
	assert_eq(Session.universe().expedition_history.size(), 1)
	assert_true(Session.repository.slot_exists(1), "autosaved on return")
	assert_false(Session.pending_expedition_summary.is_empty())
	scene.queue_free()
	await tree.process_frame


func test_exploration_defeat_returns_home_once() -> void:
	_new_game()
	var routes := Session.expeditions.plan_routes("greywood_edge")
	assert_ok(Session.expeditions.start("greywood_edge", routes[0]))
	var scene := _instance(Router.SCENES["exploration"])
	await tree.physics_frame
	var player: Node = scene.player
	player.combatant.apply_damage(9999)
	assert_false(player.combatant.is_alive)
	# death handler waits 2 s of game time before resolving
	await tree.create_timer(2.4).timeout
	assert_eq(_nav, ["settlement"])
	assert_eq(Session.universe().death_count, 1)
	assert_true(Session.expeditions.active() == null)
	assert_eq(Session.save.multiverse.pending_transition, null)
	assert_eq(Session.universe().threat_state["completed_expeditions"], 1)
	scene.queue_free()
	await tree.process_frame
