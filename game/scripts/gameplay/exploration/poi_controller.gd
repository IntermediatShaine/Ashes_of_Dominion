extends MapSceneBase
## Only scene wiring here. Rules, rewards and persistent flags are PoiRules.

const EnemyScript := preload("res://scripts/gameplay/exploration/enemy_controller.gd")
var definition: Dictionary
var objects: Dictionary = {}
var status: Label
var prompt_label: Label
var choices_box: VBoxContainer

func _load_map_definition() -> MapDefinition:
	var id := PoiRules.active_id(Session.expeditions)
	if id == "":
		return null
	definition = Content.table("pois")[id]
	return MapDefinition.from_dict(definition["layout"])

func _combat_enabled() -> bool:
	return true

func _build_content() -> void:
	for object in definition["objects"]:
		var key := String(object["id"])
		var area := InteractableArea.new()
		area.target_id = key
		area.prompt = String(object["prompt"])
		area.position = Vector2(float(object["at"][0]), float(object["at"][1])) * map_def.cell_size
		area.set_rect(Vector2(28, 28))
		area.interacted.connect(func(_body): interact_object(key))
		entities.add_child(area)
		var sprite := Visuals.make_sprite(String(object["visual"]))
		area.add_child(sprite)
		objects[key] = area
		area.modulate.a = 1.0 if PoiRules.available(Session.expeditions, key) else 0.3
	for spawn in definition["enemies"]:
		var key := String(spawn["id"])
		if MapStateStore.is_done(Session.universe(), map_def.map_id, key):
			continue
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		var enemy_id := String(spawn["enemy_id"])
		enemy.setup(enemy_id, key, Content.get_def("enemies", enemy_id), Session.universe().difficulty, Session.rng.stream("combat"), Content.balance("combat"), StableHash.derive_seed(Session.universe().world_seed, map_def.map_id + key))
		enemy.position = Vector2(float(spawn["at"][0]), float(spawn["at"][1])) * map_def.cell_size
		enemy.defeated.connect(func(_enemy):
			PoiRules.enemy_defeated(Session.expeditions, key)
			_autosave("Guard defeated."))
		entities.add_child(enemy)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := UiKit.panel(Vector2(480, 0))
	panel.position = Vector2(12, 12)
	panel.theme = UiKit.theme()
	layer.add_child(panel)
	var col := UiKit.vbox(6)
	panel.add_child(col)
	col.add_child(UiKit.title(String(definition["name"]), 22))
	col.add_child(UiKit.muted("WASD move · E interact · Space / click attack", 13))
	status = UiKit.label("")
	col.add_child(status)
	prompt_label = UiKit.label("")
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size.x = 440
	col.add_child(prompt_label)
	choices_box = UiKit.vbox(5)
	col.add_child(choices_box)
	col.add_child(UiKit.button("Save", func(): _autosave("Progress saved.")))
	col.add_child(UiKit.button("Return to Emberfall", return_home))
	_refresh_status()

func _after_ready() -> void:
	player.health_changed.connect(func(current, _maximum):
		Session.universe().protagonist_condition["health"] = current
		_refresh_status())
	player.died.connect(_on_player_died)
	Session.expeditions.experience_gained.connect(_on_experience)
	# Equipment may have been obtained on a prior visit.
	_refresh_status()

func _on_experience(_amount: int, levels: int) -> void:
	if levels <= 0:
		return
	var character := Session.character()
	var balance := Content.balance("character")
	player.combatant.max_health = ProgressionRules.max_health(character, balance)
	player.combatant.attack = ProgressionRules.attack(character, balance) + DictUtil.get_int(Session.universe().protagonist_condition, "equipment_attack")
	player.combatant.defense = ProgressionRules.defense(character, balance)
	player.combatant.health = DictUtil.get_int(Session.universe().protagonist_condition, "health")
	player.move_speed = ProgressionRules.move_speed(character, balance)
	_refresh_status()

func _refresh_status() -> void:
	if status != null:
		status.text = "Health %d · Pack %s" % [int(Session.universe().protagonist_condition["health"]), str(Session.expeditions.active().haul) if Session.expeditions.active() != null else "{}"]

func _show_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text

func _notify(text: String) -> void:
	_show_prompt(text)

func interact_object(key: String) -> void:
	if _leaving or not player.combatant.is_alive:
		return
	var object := PoiRules.object_definition(Session.expeditions, key)
	if not PoiRules.available(Session.expeditions, key):
		_notify("Nothing remains here. Renewable supplies recover after ten days.")
		return
	var choices := DictUtil.get_dict(object, "choices")
	if not choices.is_empty():
		_clear_choices()
		player.input_enabled = false
		get_tree().paused = true
		choices_box.process_mode = Node.PROCESS_MODE_ALWAYS
		for choice_id in choices:
			var selected := String(choice_id)
			var description := UiKit.muted(String(choices[selected]["description"]), 13)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			choices_box.add_child(description)
			choices_box.add_child(UiKit.button(String(choices[selected]["name"]), func(): claim(key, selected)))
		choices_box.add_child(UiKit.button("Leave it for now", _close_choices))
		return
	claim(key)

func claim(key: String, choice: String = "") -> OpResult:
	var result := PoiRules.claim(Session.expeditions, key, choice)
	_close_choices()
	if result.ok:
		objects[key].modulate.a = 0.3
		player.combatant.attack = ProgressionRules.attack(Session.character(), Content.balance("character")) + DictUtil.get_int(Session.universe().protagonist_condition, "equipment_attack")
		_autosave(DictUtil.get_string(result.value, "lore", "Collected. " + str(DictUtil.get_dict(result.value, "reward"))))
	else:
		_notify(result.error)
	_refresh_status()
	return result

func _clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()

func _close_choices() -> void:
	_clear_choices()
	get_tree().paused = false
	if player != null:
		player.input_enabled = true

func _on_exit_used(_exit_def: Dictionary) -> void:
	return_home()

func return_home() -> void:
	if _leaving or not player.combatant.is_alive:
		return
	var r := Session.expeditions.finish("returned")
	if not r.ok:
		_notify(r.error)
		return
	Session.pending_expedition_summary = r.value
	_leaving = true
	player.input_enabled = false
	_save_return()

func _on_player_died() -> void:
	if _leaving:
		return
	_leaving = true
	player.input_enabled = false
	# Reuse all existing resurrection IDs and transition recovery bookkeeping.
	var r := Session.transitions.on_protagonist_defeated({"area": map_def.map_id})
	if not r.ok:
		_notify(r.error)
		return
	Session.pending_expedition_summary = DictUtil.get_dict(r.value, "result")
	_save_return()

func _save_return() -> void:
	var saved := Session.save_game()
	if saved.ok:
		_leave_to("settlement")
	else:
		_notify("SAVE FAILED: " + saved.error + ". Use Save to retry the return.")

func _autosave(message: String) -> void:
	if _leaving:
		_save_return()
		return
	var r := Session.save_game()
	_notify(message if r.ok else "SAVE FAILED: " + r.error)
	_refresh_status()

func _exit_tree() -> void:
	super._exit_tree()
	if is_inside_tree():
		get_tree().paused = false
