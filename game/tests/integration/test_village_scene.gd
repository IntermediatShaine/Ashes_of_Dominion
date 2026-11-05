extends TestCase
## The walkable village as the player meets it: the real scene with a real
## session, physics running headless. Covers the Stage 1 hand-over checks:
## the village opens, the player moves in eight directions and collides, the
## four buildings can be walked up to and inspected, what they show is the
## settlement state, leaving and coming back keeps the village, save/load
## restores it, and swapping a visual registry entry changes how an object
## looks without touching gameplay.

const VILLAGE_BUILDINGS := ["site_shelter", "site_workshop", "site_stockpile", "site_watchpost"]

var _nav: Array[String] = []
var _saved_repo: SaveRepository
var _scene: Node = null


func before_each() -> void:
	_saved_repo = Session.repository
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	Router.navigation_hook = func(key: String): _nav.append(key)
	_nav.clear()
	_scene = null


func after_each() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	Session.end_session()
	Session.repository = _saved_repo
	Router.navigation_hook = Callable()
	tree.paused = false
	Visuals.load_registry(VisualResolver.DEFAULT_REGISTRY_PATH)


func _new_game(seed_value: int = 2468) -> void:
	var d := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	assert_ok(Session.new_game({"name": "Villager", "archetype_id": "village_hunter", "difficulty": d.value, "mist_enabled": true, "seed": seed_value}, 1))
	# Preserve the Stage 1 staffing scenarios; solo start has its own acceptance test.
	Session.settlement().population = 6
	Session.settlement_service.normalize()


func _open_village() -> Node:
	var packed: PackedScene = load(Router.SCENES["settlement"])
	_scene = packed.instantiate()
	tree.root.add_child(_scene)
	await tree.physics_frame
	await tree.physics_frame
	return _scene


func _close_village() -> void:
	_scene.free()
	_scene = null
	tree.paused = false
	await tree.process_frame


func _stock() -> void:
	Session.settlement().base_storage_capacity = 1000
	Session.settlement().resources = {"wood": 300, "stone": 300, "iron": 40, "salvage": 40, "food": 100}


func _physics(frames: int) -> void:
	for i in frames:
		await tree.physics_frame


## Puts the player on a spot and lets the physics server notice.
func _stand_at(scene: Node, spot: Vector2) -> void:
	scene.player.position = spot
	scene.player.velocity = Vector2.ZERO
	await _physics(3)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tree.root.push_input(event)


func test_village_opens_with_everything_in_place() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	assert_true(scene.player != null, "player spawned")
	assert_eq(scene.player.position, scene.map_def.entry_position("spawn"), "at the player spawn point")
	assert_true(scene.player.is_in_group("player"))
	assert_false(scene.player.combat_enabled, "no fighting in the village")
	assert_eq(scene.site_views.size(), 9, "hearth + four buildings + four building sites")
	for site_id in ["site_hearth"] + VILLAGE_BUILDINGS:
		var view: Node = scene.site_views[site_id]
		var definition_id := DictUtil.get_string(service.inspect_site(site_id), "definition_id")
		assert_eq(view.visual_id(), "building.%s.level_0" % definition_id, site_id + " starts as its ruin")
		assert_true(view.is_solid(), site_id + " blocks the way")
		assert_true(view.sprite().texture != null, site_id + " is drawn")
		assert_eq(view.sprite().resolved_visual_id, view.visual_id(), site_id + " has its own artwork, not a fallback")
	for site_id in ["plot_1", "plot_2", "plot_3", "plot_4"]:
		var plot: Node = scene.site_views[site_id]
		assert_eq(plot.visual_id(), "site.plot.empty")
		assert_false(plot.is_solid(), "an empty plot can be walked over")
		assert_true(plot.interaction_area().enabled, "and still inspected")
	assert_true(scene.exit_areas.has("gate"), "village exit")
	assert_true(scene.hud != null)
	assert_false(tree.paused)
	assert_eq(scene.hud.current_modal(), "")
	assert_true(scene.ground != null)
	# every interactable follows the shared protocol the player controller uses
	var interactables := 0
	for node in tree.get_nodes_in_group("interactables"):
		if scene.is_ancestor_of(node):
			interactables += 1
			assert_true(node.has_method("interact") and node.has_method("interaction_prompt"))
			assert_eq(node.collision_layer, 32, "physics layer 6")
	assert_eq(interactables, 10, "nine sites and the gate")


func test_eight_direction_movement() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var player: Node = scene.player
	var d := 0.70710678
	var cases := [
		[["move_right"], Vector2(1, 0)], [["move_right", "move_down"], Vector2(d, d)],
		[["move_down"], Vector2(0, 1)], [["move_left", "move_down"], Vector2(-d, d)],
		[["move_left"], Vector2(-1, 0)], [["move_left", "move_up"], Vector2(-d, -d)],
		[["move_up"], Vector2(0, -1)], [["move_right", "move_up"], Vector2(d, -d)],
	]
	var open_ground := Vector2(704, 720)   # on the road south of the hearth, nothing nearby
	var distances: Array[float] = []
	for c in cases:
		await _stand_at(scene, open_ground)
		for action in c[0]:
			Input.action_press(action)
		await _physics(12)
		for action in c[0]:
			Input.action_release(action)
		var moved: Vector2 = player.position - open_ground
		var expected: Vector2 = c[1]
		assert_true(moved.length() > 15.0, "moved %s" % str(c[0]))
		assert_true(moved.normalized().dot(expected) > 0.999, "%s goes %s, went %s" % [str(c[0]), str(expected), str(moved.normalized())])
		assert_eq(player.facing, expected, "facing %s" % str(c[0]))
		distances.append(moved.length())
		await _physics(1)
	for dist in distances:
		assert_true(absf(dist - distances[0]) < 0.5, "same speed in every direction (diagonals are not faster)")
	assert_eq(player.velocity, Vector2.ZERO, "stops when the keys are released")


func test_collision_with_buildings_and_borders() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var player: Node = scene.player
	var m: MapDefinition = scene.map_def
	# straight north from the spawn point lies the hearth ruin
	var hearth_rect: Rect2 = m.site_rect(m.site("site_hearth"))
	Input.action_press("move_up")
	await _physics(150)
	Input.action_release("move_up")
	assert_true(player.position.y > hearth_rect.end.y, "stopped by the hearth (y %.1f, footprint ends at %.1f)" % [player.position.y, hearth_rect.end.y])
	assert_true(player.position.y < hearth_rect.end.y + 16.0, "and right up against it")
	# the closed border: walking south from the gate entry ends at the tree line
	await _stand_at(scene, m.entry_position("gate"))
	Input.action_press("move_down")
	await _physics(150)
	Input.action_release("move_down")
	assert_true(player.position.y < m.playable_rect().end.y, "cannot leave the map on foot")
	# an empty plot is open ground; once something is built there it is not
	var plot_rect: Rect2 = m.site_rect(m.site("plot_3"))
	var west_of_plot := Vector2(plot_rect.position.x - 20.0, plot_rect.get_center().y)
	await _stand_at(scene, west_of_plot)
	Input.action_press("move_right")
	await _physics(40)
	Input.action_release("move_right")
	assert_true(player.position.x > plot_rect.position.x + 20.0, "walked onto the empty plot")
	_stock()
	assert_ok(scene.request_improvement("plot_3", "build", "woodcutters_camp"))
	await _stand_at(scene, west_of_plot)
	Input.action_press("move_right")
	await _physics(40)
	Input.action_release("move_right")
	assert_true(player.position.x < plot_rect.position.x, "the new building blocks the way")
	assert_true(scene.site_views["plot_3"].is_solid())


func test_all_four_buildings_are_interactable_and_show_the_settlement_state() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	var m: MapDefinition = scene.map_def
	# first as ruins, then rebuilt
	for round in ["ruin", "built"]:
		if round == "built":
			_stock()
			for site_id in VILLAGE_BUILDINGS:
				assert_ok(scene.request_improvement(site_id, "build"))
			scene.rest_until_dawn()
			assert_ok(service.damage_building(DictUtil.get_string(Session.settlement().building_at_site("site_stockpile"), "instance_id"), 45, "test"))
		for site_id in VILLAGE_BUILDINGS:
			var view: Node = scene.site_views[site_id]
			var truth := service.inspect_site(site_id)
			# walk up to it: standing just south of the footprint is close enough
			await _stand_at(scene, m.site_anchor(m.site(site_id)) + Vector2(0, 22))
			assert_eq(scene.player._interact_target, view.interaction_area(), "%s (%s) is the interaction target" % [site_id, round])
			assert_true(scene.hud._prompt.text.contains(String(truth["name"])), "prompt names it: " + scene.hud._prompt.text)
			scene.player._interact_target.interact(scene.player)
			assert_eq(scene.hud.current_modal(), "inspect")
			assert_eq(scene.hud.inspected_site_id(), site_id)
			assert_true(tree.paused, "the world waits while the card is open")
			# identity, condition, level and improvements — exactly the state's
			assert_eq(view.inspection, truth, "the view shows the service's inspection")
			var text: String = scene.hud.panel_text("inspect")
			assert_true(text.contains(String(truth["name"])), "identity: " + site_id)
			assert_true(text.contains("Level %d of %d" % [int(truth["level"]), int(truth["max_level"])]), "level: " + site_id + "\n" + text)
			assert_true(text.contains("Condition: %s (%d%%)" % [String(truth["condition_label"]), int(truth["condition"])]), "condition: " + site_id + "\n" + text)
			var offered: Array = scene.hud.offered_improvements("inspect")
			var available: Array = []
			for improvement in truth["improvements"]:
				if improvement["available"]:
					available.append({"site_id": site_id, "action": improvement["action"], "definition_id": improvement["definition_id"]})
			assert_eq(offered, available, "the enabled buttons are the available improvements: " + site_id)
			assert_true(truth["improvements"].size() >= 1, site_id + " has something to improve")
			if round == "ruin":
				assert_eq(int(truth["level"]), 0)
				assert_true(text.contains("Rebuild " + String(truth["name"])), text)
			else:
				assert_eq(int(truth["level"]), 1)
				assert_eq(int(truth["level"]), int(Session.settlement().building_at_site(site_id)["level"]))
				assert_eq(int(truth["condition"]), int(Session.settlement().building_at_site(site_id)["condition"]))
				assert_true(text.contains("Upgrade to level 2"), text)
			scene.hud.close_modal()
			assert_false(tree.paused)
	assert_eq(int(service.inspect_site("site_stockpile")["condition"]), 55, "the damaged one was shown as damaged")


func test_four_building_sites_are_interactable_and_can_be_built_on() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	var m: MapDefinition = scene.map_def
	_stock()
	var choices := ["woodcutters_camp", "storehouse", "shelter", "palisade"]
	var plots := ["plot_1", "plot_2", "plot_3", "plot_4"]
	assert_ok(scene.request_improvement("site_shelter", "build"))   # the palisade requires a shelter
	for i in plots.size():
		var site_id: String = plots[i]
		var view: Node = scene.site_views[site_id]
		# an empty plot is open ground: stand on it and it is the interaction target
		await _stand_at(scene, m.site_rect(m.site(site_id)).get_center())
		assert_eq(scene.player._interact_target, view.interaction_area(), site_id + " is in reach")
		assert_eq(scene.hud._prompt.text, "[E] Inspect the empty plot")
		scene.player._interact_target.interact(scene.player)
		assert_eq(scene.hud.inspected_site_id(), site_id)
		var text: String = scene.hud.panel_text("inspect")
		assert_true(text.contains("Empty plot") and text.contains("Free building plot"), text)
		var offered: Array = scene.hud.offered_improvements("inspect")
		assert_true(offered.has({"site_id": site_id, "action": "build", "definition_id": choices[i]}), "%s offers %s" % [site_id, choices[i]])
		for offer in offered:
			assert_ne(String(offer["definition_id"]), "workshop", "reserved buildings are not offered on plots")
		# build through the card's own request, as the button does
		scene.hud.improvement_requested.emit(site_id, "build", choices[i])
		assert_eq(String(service.inspect_site(site_id)["definition_id"]), choices[i])
		assert_eq(view.visual_id(), "building.%s.level_1" % choices[i])
		assert_true(view.is_solid())
		assert_true(scene.hud.panel_text("inspect").contains(String(service.inspect_site(site_id)["name"])), "the open card follows the change")
		scene.hud.close_modal()
		await _stand_at(scene, m.entry_position("spawn"))
	assert_eq(Session.settlement().buildings.size(), 5)


func test_hearth_and_shortcut_open_village_management() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	var m: MapDefinition = scene.map_def
	await _stand_at(scene, m.entry_position("hearth"))
	var hearth_view: Node = scene.site_views["site_hearth"]
	assert_eq(scene.player._interact_target, hearth_view.interaction_area())
	assert_true(scene.hud._prompt.text.contains("manage the village"), scene.hud._prompt.text)
	scene.player._interact_target.interact(scene.player)
	assert_eq(scene.hud.current_modal(), "management")
	assert_eq(scene.hud.current_tab(), "overview")
	# Overview: real settlement data
	var snap := service.snapshot()
	var overview: String = scene.hud.panel_text("management")
	assert_true(overview.contains("Village Hearth"), "the hearth is inspected here")
	assert_true(overview.contains("Level 0 of 3"))
	assert_true(overview.contains("Population %d of %d housed" % [int(snap["population"]["count"]), int(snap["population"]["capacity"])]), overview)
	assert_true(overview.contains("Day %d · %s" % [int(snap["time"]["day"]), String(snap["time"]["clock"])]))
	for rid in snap["resources"].keys():
		assert_true(overview.contains("%s %d" % [DictUtil.get_string(Content.get_def("resources", String(rid)), "name"), int(snap["resources"][rid])]), "stock of " + String(rid))
	assert_true(overview.contains("Enemy awareness: " + String(snap["threat"]["label"])))
	for resident in snap["population"]["residents"]:
		assert_true(overview.contains(String(resident["name"])), "resident " + String(resident["name"]))
	assert_true(overview.contains("Villager"), "the protagonist's own line")
	# Buildings: every site, from the same snapshot
	scene.hud._show_tab("buildings")
	assert_eq(scene.hud.current_tab(), "buildings")
	var buildings: String = scene.hud.panel_text("management")
	for site in snap["sites"]:
		assert_true(buildings.contains(String(site["name"])), "lists " + String(site["name"]))
	var affordable := 0
	for site in snap["sites"]:
		for improvement in site["improvements"]:
			if improvement["available"]:
				affordable += 1
	assert_true(affordable >= 1 and affordable < snap["sites"].size(), "the starting stock pays for something, not everything")
	assert_eq(scene.hud.offered_improvements("management").size(), affordable, "one enabled button per affordable improvement")
	# the panel follows the state while it is open
	_stock()
	assert_ok(scene.request_improvement("site_hearth", "build"))
	assert_true(scene.hud.panel_text("management").contains("Level 1 of 3"), "refreshed after the change")
	scene.hud.close_modal()
	assert_eq(scene.hud.current_modal(), "")

	# the documented keyboard shortcut (V) opens and closes it; Esc closes it too
	_press("village_management")
	assert_eq(scene.hud.current_modal(), "management")
	assert_true(tree.paused)
	_press("village_management")
	assert_eq(scene.hud.current_modal(), "")
	_press("village_management")
	_press("pause")
	assert_eq(scene.hud.current_modal(), "", "Esc closes the panel")
	assert_false(tree.paused)
	_press("pause")
	assert_eq(scene.hud.current_modal(), "pause", "Esc with nothing open is the pause menu")
	_press("village_management")
	assert_eq(scene.hud.current_modal(), "pause", "the shortcut does not replace another panel")
	_press("pause")
	assert_eq(scene.hud.current_modal(), "")


func test_requests_go_through_the_service_and_views_follow() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	var s := Session.settlement()
	# refused: nothing changes, the player is told why
	var before := s.to_dict()
	assert_fail(scene.request_improvement("site_shelter", "build"))
	assert_eq(s.to_dict(), before)
	assert_true(scene.hud.toast_text().contains("Need 10 wood"), scene.hud.toast_text())
	assert_false(Session.repository.slot_exists(1) and Session.save.meta.get("save_count", 0) > 1, "a refused request does not autosave")

	_stock()
	assert_ok(scene.request_improvement("site_hearth", "build"))
	assert_eq(scene.site_views["site_hearth"].visual_id(), "building.village_hearth.level_1")
	assert_eq(int(Session.save.meta["save_count"]), 2, "autosaved (new game was the first save)")
	# a building that takes time: scaffolding, then the building
	assert_ok(scene.request_improvement("site_workshop", "build"))
	var workshop: Node = scene.site_views["site_workshop"]
	assert_eq(workshop.visual_id(), "building.workshop.level_0", "still the ruin underneath")
	assert_eq(workshop.overlay_visual_id(), "site.construction")
	scene.rest_until_dawn()
	assert_eq(workshop.visual_id(), "building.workshop.level_1")
	assert_eq(workshop.overlay_visual_id(), "")
	assert_true(scene.hud.toast_text().contains("Work on the Workshop is finished"), scene.hud.toast_text())
	# an upgrade in progress: the building with a work badge, then the next level
	assert_ok(scene.request_improvement("site_workshop", "upgrade"))
	assert_eq(workshop.visual_id(), "building.workshop.level_1")
	assert_eq(workshop.overlay_visual_id(), "marker.work_in_progress")
	scene.rest_until_dawn()
	scene.rest_until_dawn()
	assert_eq(workshop.visual_id(), "building.workshop.level_2")
	assert_eq(int(s.building_at_site("site_workshop")["level"]), 2)
	# workers and cancelling, through the same door
	assert_ok(scene.request_improvement("site_watchpost", "build"))
	var job_id := DictUtil.get_string(s.job_at_site("site_watchpost"), "job_id")
	assert_ok(scene.change_workers(job_id, 1))
	assert_eq(s.workers_assigned_to(job_id).size(), 1)
	assert_ok(scene.change_workers(job_id, -1))
	assert_fail(scene.change_workers(job_id, -1))
	assert_ok(scene.cancel_job(job_id))
	assert_eq(scene.site_views["site_watchpost"].visual_id(), "building.watchpost.level_0")
	# every view shows exactly what the service reports
	for site_id in scene.site_views.keys():
		assert_eq(scene.site_views[site_id].inspection, service.inspect_site(String(site_id)), String(site_id))
	assert_true(Session.save.validate().is_empty(), "; ".join(Session.save.validate()))


func test_leaving_and_returning_preserves_the_village() -> void:
	_new_game()
	var scene: Node = await _open_village()
	var service := Session.settlement_service
	_stock()
	for pair in [["site_hearth", ""], ["site_shelter", ""], ["site_stockpile", ""], ["plot_2", "storehouse"]]:
		assert_ok(scene.request_improvement(pair[0], "build", pair[1]))
	scene.rest_until_dawn()
	assert_ok(scene.request_improvement("site_shelter", "upgrade"))   # still in progress when we leave
	var before := service.snapshot()
	var visuals_before := {}
	for site_id in scene.site_views.keys():
		visuals_before[site_id] = [scene.site_views[site_id].visual_id(), scene.site_views[site_id].overlay_visual_id()]

	# out through the gate to the world map, and straight back
	await _stand_at(scene, scene.map_def.exits[0]["rect"].get_center() - Vector2(0, 30))
	assert_eq(scene.player._interact_target, scene.exit_areas["gate"], "the gate is in reach")
	scene.player._interact_target.interact(scene.player)
	assert_eq(_nav, ["world_map"])
	assert_eq(Session.travel.current_entry_id(), "gate")
	await _close_village()
	scene = await _open_village()
	assert_eq(scene.player.position, scene.map_def.entry_position("gate"), "back in through the gate")
	assert_eq(service.snapshot(), before, "nothing changed while away")
	for site_id in scene.site_views.keys():
		assert_eq([scene.site_views[site_id].visual_id(), scene.site_views[site_id].overlay_visual_id()], visuals_before[site_id], String(site_id))

	# a whole expedition: days pass, the village is the same village, grown by the work that was under way
	await _close_village()
	var routes := Session.expeditions.plan_routes("greywood_edge")
	assert_ok(Session.expeditions.start("greywood_edge", routes[0]))
	assert_eq(Session.travel.current_map_id(), "wilderness:greywood_edge")
	var result := Session.expeditions.finish("returned")
	assert_ok(result)
	Session.pending_expedition_summary = result.value
	scene = await _open_village()
	assert_eq(scene.hud.current_modal(), "message", "the expedition summary is shown on arrival")
	assert_true(scene.hud.panel_text("message").contains("work on the Shelter was finished"), scene.hud.panel_text("message"))
	scene.hud.close_modal()
	assert_eq(scene.player.position, scene.map_def.entry_position("gate"))
	var after := service.snapshot()
	assert_true(int(after["time"]["day"]) > int(before["time"]["day"]))
	for i in before["sites"].size():
		var was: Dictionary = before["sites"][i]
		var now: Dictionary = after["sites"][i]
		assert_eq(now["instance_id"], was["instance_id"], "same building on " + String(was["site_id"]))
		assert_eq(now["definition_id"], was["definition_id"])
		if was["site_id"] == "site_shelter":
			assert_eq(int(now["level"]), 2, "the upgrade finished while away")
		else:
			assert_eq(now["level"], was["level"])
		assert_eq(now["condition"], was["condition"])
	assert_eq(scene.site_views["site_shelter"].visual_id(), "building.shelter.level_2")
	assert_eq(scene.site_views["plot_2"].visual_id(), "building.storehouse.level_1")


func test_saving_and_loading_restores_village_progress() -> void:
	_new_game()
	var scene: Node = await _open_village()
	_stock()
	assert_ok(scene.request_improvement("site_hearth", "build"))
	assert_ok(scene.request_improvement("site_shelter", "build"))
	assert_ok(scene.request_improvement("site_watchpost", "build"))
	assert_ok(scene.request_improvement("plot_1", "build", "woodcutters_camp"))
	scene.rest_until_dawn()
	assert_ok(scene.request_improvement("site_shelter", "upgrade"))
	scene.rest_until_dawn()
	assert_ok(scene.request_improvement("site_hearth", "upgrade"))   # left unfinished
	assert_ok(scene.change_workers(DictUtil.get_string(Session.settlement().building_at_site("plot_1"), "instance_id"), 1))
	Session.settlement().resources["wood"] = 123
	Session.settlement().pending_recruits = 1
	# save while standing right up against a building — where a player who has
	# just used it would be
	await _stand_at(scene, scene.map_def.entry_position("spawn"))
	Input.action_press("move_up")
	await _physics(150)
	Input.action_release("move_up")
	await _physics(2)
	var spot: Vector2 = scene.player.position
	assert_true(spot.y < scene.map_def.site_rect(scene.map_def.site("site_hearth")).end.y + 16.0, "touching the hearth")
	assert_ok(scene.save_game())
	var saved_snapshot := Session.settlement_service.snapshot()
	var saved_document := Session.save.to_dict()
	var saved_visuals := {}
	for site_id in scene.site_views.keys():
		saved_visuals[site_id] = [scene.site_views[site_id].visual_id(), scene.site_views[site_id].overlay_visual_id(), scene.site_views[site_id].is_solid()]

	# quit to the menu, then load the slot again
	scene.quit_to_main_menu()
	assert_eq(_nav, ["main_menu"])
	assert_false(Session.has_game())
	await _close_village()
	assert_ok(Session.load_slot(1))
	assert_true(Session.last_messages.is_empty(), "no migration, no recovery: " + str(Session.last_messages))
	assert_eq(Session.save.to_dict(), saved_document, "the whole state document is identical")
	scene = await _open_village()
	var s := Session.settlement()
	assert_eq(Session.settlement_service.snapshot(), saved_snapshot)
	assert_eq(int(s.building_at_site("site_shelter")["level"]), 2, "building upgrade")
	assert_eq(s.resource_amount("wood"), 123, "resource stockpile")
	assert_eq(String(s.building_at_site("plot_1")["definition_id"]), "woodcutters_camp", "village layout change")
	assert_eq(s.population, 6, "population")
	assert_eq(s.pending_recruits, 1)
	assert_eq(s.workers_assigned_to(String(s.building_at_site("plot_1")["instance_id"])).size(), 1, "worker assignment")
	assert_eq(String(s.job_at_site("site_hearth")["kind"]), "upgrade", "construction job")
	for site_id in scene.site_views.keys():
		assert_eq([scene.site_views[site_id].visual_id(), scene.site_views[site_id].overlay_visual_id(), scene.site_views[site_id].is_solid()], saved_visuals[site_id], String(site_id))
	assert_true(scene.player.position.distance_to(spot) < 1.0, "the player stands where they stood when saving (%s vs %s)" % [str(scene.player.position), str(spot)])
	# and the unfinished work carries on
	scene.rest_until_dawn()
	assert_eq(scene.site_views["site_hearth"].visual_id(), "building.village_hearth.level_2")


func test_registry_swap_changes_appearance_and_nothing_else() -> void:
	_new_game()
	var scene: Node = await _open_village()
	_stock()
	assert_ok(scene.request_improvement("site_workshop", "build"))
	scene.rest_until_dawn()
	var view: Node = scene.site_views["site_workshop"]
	assert_eq(view.visual_id(), "building.workshop.level_1")
	var old_texture: Texture2D = view.sprite().texture
	assert_eq(old_texture, Visuals.texture("building.workshop.level_1"))
	var state_before := Session.save.universe.to_dict()
	var inspection_before := Session.settlement_service.inspect_site("site_workshop")
	var body_shape: RectangleShape2D = view._body_shape.shape
	var collision_before := body_shape.size
	var area_shape: RectangleShape2D = view.interaction_area()._shape.shape
	var interaction_before := area_shape.size

	# Swap the art in the registry: a different image, of a different size.
	var doc: Dictionary = JSON.parse_string(TestCase.read_text(VisualResolver.DEFAULT_REGISTRY_PATH))
	var replacement: String = doc["visuals"]["building.watchpost.level_2"]["texture"]
	assert_ne(String(doc["visuals"]["building.workshop.level_1"]["texture"]), replacement)
	doc["visuals"]["building.workshop.level_1"]["texture"] = replacement
	var registry_path := temp_dir + "/swapped_registry.json"
	TestCase.write_text(registry_path, JSON.stringify(doc))
	assert_true(Visuals.load_registry(registry_path), "; ".join(Visuals.load_errors))

	var new_texture: Texture2D = view.sprite().texture
	assert_ne(new_texture, old_texture, "the workshop looks different")
	assert_eq(new_texture, Visuals.texture("building.watchpost.level_2"), "it shows the image the registry now names")
	assert_ne(new_texture.get_size(), old_texture.get_size(), "(an image of another size)")
	# …and nothing but the picture changed
	assert_eq(view.visual_id(), "building.workshop.level_1", "the object still asks for the same visual id")
	assert_eq(Session.save.universe.to_dict(), state_before, "settlement state untouched")
	assert_eq(Session.settlement_service.inspect_site("site_workshop"), inspection_before, "inspection untouched")
	assert_eq(body_shape.size, collision_before, "collision does not depend on the artwork")
	assert_eq(area_shape.size, interaction_before, "nor does the interaction area")
	assert_eq(scene.site_views["site_shelter"].sprite().texture, Visuals.texture("building.shelter.level_0"), "other objects are unaffected")
	# the same building is still interactable and upgradeable
	await _stand_at(scene, scene.map_def.site_anchor(scene.map_def.site("site_workshop")) + Vector2(0, 22))
	assert_eq(scene.player._interact_target, view.interaction_area())
	assert_ok(scene.request_improvement("site_workshop", "upgrade"))

	# restoring the registry restores the look
	assert_true(Visuals.load_registry(VisualResolver.DEFAULT_REGISTRY_PATH))
	assert_eq(view.sprite().texture, old_texture)


func test_defeat_returns_to_the_hearth() -> void:
	_new_game()
	var routes := Session.expeditions.plan_routes("greywood_edge")
	assert_ok(Session.expeditions.start("greywood_edge", routes[0]))
	assert_ok(Session.transitions.on_protagonist_defeated())
	var scene: Node = await _open_village()
	assert_eq(scene.player.position, scene.map_def.entry_position("hearth"), "the curse sets you down by the hearth")


func test_pause_menu_settings_and_main_menu() -> void:
	_new_game()
	var scene: Node = await _open_village()
	_press("pause")
	assert_eq(scene.hud.current_modal(), "pause")
	assert_true(tree.paused)
	scene.hud.close_modal()
	assert_false(tree.paused)
	# M leaves through the gate, like using it
	_press("world_map")
	assert_eq(_nav, ["world_map"])
	assert_eq(Session.travel.current_entry_id(), "gate")
	await _close_village()
	_nav.clear()
	# settings and back: the player returns to the same spot
	scene = await _open_village()
	await _stand_at(scene, Vector2(900, 700))
	scene.open_settings()
	assert_eq(_nav, ["settings"])
	await _close_village()
	scene = await _open_village()
	assert_eq(scene.player.position, Vector2(900, 700))
	_nav.clear()
	scene.quit_to_main_menu()
	assert_eq(_nav, ["main_menu"])
	assert_false(Session.has_game())
	assert_false(tree.paused)


func test_interface_is_styled_by_the_theme_only() -> void:
	_new_game()
	var scene: Node = await _open_village()
	_stock()
	assert_ok(scene.request_improvement("site_hearth", "build"))
	assert_ok(scene.request_improvement("site_workshop", "build"))
	var root: Control = scene.hud._root
	assert_eq(root.theme.resource_path, "res://ui/themes/village_theme.tres")
	for tab in ["overview", "buildings"]:
		scene.hud.open_management(tab)
		_assert_no_overrides(root)
	scene.hud.open_inspect("site_workshop")
	_assert_no_overrides(root)
	scene.hud.close_modal()
	# the variations the interface asks for all exist in the theme
	var used := {}
	_collect_variations(root, used)
	for variation in used.keys():
		assert_true(root.theme.get_type_variation_base(variation) != &"", "theme defines the variation " + String(variation))
	assert_true(used.size() >= 6)
	# icons come from the visual registry
	# (newer engines add TextureRects of their own inside some containers, so
	# only the interface's icons — the ones tagged with a visual id — count)
	var icons := 0
	for node in root.find_children("*", "TextureRect", true, false):
		if not node.has_meta("visual_id"):
			continue
		icons += 1
		assert_true(Visuals.has_visual(String(node.get_meta("visual_id"))), "icon uses a registered visual id")
		assert_eq((node as TextureRect).texture, Visuals.ui_texture(String(node.get_meta("visual_id"))))
	assert_true(icons >= 5, "resource and population icons are shown")


func _assert_no_overrides(node: Node) -> void:
	if node is Control:
		var c: Control = node
		for item in ["font_color", "font_shadow_color", "font_outline_color"]:
			assert_false(c.has_theme_color_override(item), "%s overrides %s" % [c.get_path(), item])
		assert_false(c.has_theme_font_size_override("font_size"), "%s overrides font_size" % c.get_path())
		assert_false(c.has_theme_font_override("font"), "%s overrides font" % c.get_path())
		for item in ["normal", "panel", "fill", "background", "hover", "pressed"]:
			assert_false(c.has_theme_stylebox_override(item), "%s overrides stylebox %s" % [c.get_path(), item])
		assert_false(c.has_theme_constant_override("separation"), "%s overrides separation" % c.get_path())
	for child in node.get_children():
		_assert_no_overrides(child)


func _collect_variations(node: Node, used: Dictionary) -> void:
	if node is Control and (node as Control).theme_type_variation != &"":
		used[(node as Control).theme_type_variation] = true
	for child in node.get_children():
		_collect_variations(child, used)
