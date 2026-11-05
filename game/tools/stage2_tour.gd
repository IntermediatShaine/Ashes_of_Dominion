extends Node
## Scripted rendering review, not a substitute for human play. Uses private saves.
## godot --path . res://tools/stage2_tour.tscn -- --out=<absolute directory>

var out_dir := "user://stage2_screenshots"
var scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Router.navigation_hook = func(_key): pass
	Session.repository = SaveRepository.new("user://_stage2_tour_saves")
	call_deferred("_tour")

func _open(key: String) -> void:
	if is_instance_valid(scene):
		scene.free()
	get_tree().paused = false
	scene = load(Router.SCENES[key]).instantiate()
	add_child(scene)
	await _frames(12)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name_text: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_text + ".png"))
	if error != OK:
		push_error("Stage 2 screenshot failed: " + name_text)
	print("STAGE2 SHOT: " + name_text)

func _tour() -> void:
	var difficulty := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	var result := Session.new_game({"name": "Survivor", "archetype_id": "village_hunter", "difficulty": difficulty.value, "mist_enabled": true, "seed": 20261105}, 1)
	if not result.ok:
		push_error(result.error)
		get_tree().quit(1)
		return
	await _open("settlement")
	scene.hud.open_inspect("site_shelter")
	await _shot("01_shelter_ruin")
	await _open("world_map")
	await _shot("02_poi_departures")
	PoiRules.start(Session.expeditions, "lumber_camp")
	await _open("poi")
	scene.player.position = Vector2(680, 600)
	await _frames(40)
	await _shot("03_lumber_camp")
	scene.claim("timber_a")
	scene.claim("survivor")
	scene.return_home()
	await _open("settlement")
	scene.request_improvement("site_shelter", "build")
	scene.hud.open_inspect("site_shelter")
	await _shot("04_rebuilt_shelter")
	scene.hud.close_modal()
	PoiRules.start(Session.expeditions, "ruined_watchtower")
	await _open("poi")
	scene.player.position = Vector2(680, 620)
	await _frames(20)
	await _shot("05_watchtower_guards")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		for hit in 30:
			if enemy.combatant.is_alive:
				enemy.take_hit(scene.player)
	scene.claim("cache")
	scene.return_home()
	scene.free()
	scene = null
	PoiRules.start(Session.expeditions, "forgotten_shrine")
	await _open("poi")
	scene.interact_object("altar")
	await _shot("06_shrine_choice")
	scene.claim("altar", "honor")
	scene.return_home()
	await _open("settlement")
	# Presentation fixture only: show the workshop UI without grinding supplies.
	Session.settlement().base_storage_capacity = 400
	Session.settlement().resources = {"wood": 100, "stone": 100, "salvage": 20, "food": 40, "iron": 0}
	scene.request_improvement("site_workshop", "build")
	scene.rest_until_dawn()
	scene.hud.open_inspect("site_workshop")
	await _shot("07_workshop_crafting")
	print("STAGE2 TOUR PASSED: seven rendered scenes")
	get_tree().quit(0)
