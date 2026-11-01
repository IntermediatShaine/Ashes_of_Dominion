extends Node
## Development tool: walks through every screen with a real new game and
## writes PNG screenshots. Needs a rendering context (not --headless):
##   godot --path . --rendering-driver opengl3 res://tools/screenshot_tour.tscn -- --out=C:/temp/shots
## Writes to user://screenshots when --out is not given. Also useful as a
## runtime smoke test of the full scene flow.

var out_dir := "user://screenshots"


func _ready() -> void:
	if has_meta("is_runner"):
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Survive scene changes: run the tour from a node parented to the root.
	var runner := Node.new()
	runner.name = "TourRunner"
	runner.set_script(load("res://tools/screenshot_tour.gd"))
	runner.set_meta("is_runner", true)
	runner.out_dir = out_dir
	get_tree().root.add_child.call_deferred(runner)
	runner.call_deferred("_tour")


func _tour() -> void:
	var tree := get_tree()
	Session.repository = SaveRepository.new("user://_tour_saves")
	await _settle(tree, 5)
	Router.go("main_menu")
	await _settle(tree, 10)
	await _shot("01_main_menu")
	Router.go("new_game")
	await _settle(tree, 10)
	await _shot("02_new_game")
	var d := DifficultyRules.from_preset("challenging", Content.table("difficulty"))
	var r := Session.new_game({"name": "Ren", "archetype_id": "ashborn", "difficulty": d.value, "mist_enabled": true, "seed": 777}, 1)
	if not r.ok:
		push_error("tour: new_game failed: " + r.error)
	Router.go("settlement")
	await _settle(tree, 10)
	await _shot("03_settlement")
	Router.go("world_map")
	await _settle(tree, 10)
	var map := tree.current_scene
	map._select("ashen_crossroads")
	await _settle(tree, 5)
	await _shot("04_world_map")
	map._on_begin()
	await _settle(tree, 30)
	await _shot("05_exploration_start")
	Input.action_press("move_right")
	await _settle(tree, 70)
	Input.action_release("move_right")
	Input.action_press("move_down")
	await _settle(tree, 40)
	Input.action_release("move_down")
	await _settle(tree, 20)
	await _shot("06_exploration_moving")
	var scene := tree.current_scene
	if scene.has_method("_on_npc_talked") and scene._npc != null:
		Session.expeditions.active().add_haul("food", 2)
		scene._on_npc_talked("stranded_survivor")
		await _settle(tree, 5)
		await _shot("07_decision")
		scene.hud.close_decision()
	scene.hud.toggle_pause(true)
	await _settle(tree, 3)
	await _shot("08_pause")
	scene.hud.toggle_pause(false)
	scene._on_exit_requested()
	await _settle(tree, 10)
	await _shot("09_settlement_after_return")
	Router.go("load_game")
	await _settle(tree, 10)
	await _shot("10_load_game")
	TestCase.remove_dir_recursive("user://_tour_saves")
	print("screenshot tour complete -> " + ProjectSettings.globalize_path(out_dir))
	tree.quit(0)


func _settle(tree: SceneTree, frames: int) -> void:
	for i in frames:
		await tree.process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	var err := img.save_png(path)
	if err != OK:
		push_error("tour: cannot save %s (%s)" % [path, error_string(err)])
	else:
		print("shot " + path)
