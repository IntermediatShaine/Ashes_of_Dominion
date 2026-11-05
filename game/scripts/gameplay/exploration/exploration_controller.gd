extends Node2D
## Orchestrates one explorable area for the active expedition:
## generates the WildernessMap, spawns terrain/entities, wires HUD and
## entity signals to the ExpeditionService, and handles the three exits
## (return, retreat, defeat). No game rules live here.

const TerrainRendererScript := preload("res://scripts/gameplay/exploration/terrain_renderer.gd")
const EnemyScript := preload("res://scripts/gameplay/exploration/enemy_controller.gd")
const ResourceNodeScript := preload("res://scripts/gameplay/exploration/resource_node.gd")
const SurvivorScript := preload("res://scripts/gameplay/exploration/survivor_npc.gd")
const ExitZoneScript := preload("res://scripts/gameplay/exploration/exit_zone.gd")
const HudScript := preload("res://scripts/interface/exploration_hud.gd")

var map: WildernessMap
var player: CharacterBody2D
var hud: CanvasLayer
var _entities: Node2D
var _ending: bool = false
var _npc: Area2D = null
var _last_player_health: int = 0


func _ready() -> void:
	if not Session.has_game() or Session.expeditions.active() == null:
		push_error("Exploration opened without an active expedition")
		Router.go("settlement" if Session.has_game() else "main_menu")
		return
	var expedition := Session.expeditions.active()
	map = Session.expeditions.build_area()
	Telemetry.record_event("area_entered", {"enemies": map.enemy_spawns.size(), "resources": map.resource_nodes.size()})
	var biome := Content.get_def("biomes", map.biome_id)
	var u := Session.universe()

	var terrain := Node2D.new()
	terrain.set_script(TerrainRendererScript)
	add_child(terrain)
	terrain.setup(map, biome)

	# entity layer and protagonist: the same kit the village and POIs use
	_entities = ExplorationKit.create_entities_layer(self)
	player = ExplorationKit.spawn_player(_entities, map.cell_center(map.spawn), map.world_size(), true)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.interact_target_changed.connect(_on_interact_target_changed)

	# resources
	for r in map.resource_nodes:
		var node := Area2D.new()
		node.set_script(ResourceNodeScript)
		node.setup(String(r["key"]), String(r["resource_id"]), int(r["amount"]), Content.get_def("resources", String(r["resource_id"])), bool(r.get("depleted", false)))
		node.position = map.cell_center(r["cell"])
		node.harvested.connect(_on_harvested)
		_entities.add_child(node)

	# enemies
	var combat_rng := Session.rng.stream("combat")
	for e in map.enemy_spawns:
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		var eid := String(e["enemy_id"])
		enemy.setup(eid, String(e["key"]), Content.get_def("enemies", eid), u.difficulty, combat_rng, Content.balance("combat"), StableHash.derive_seed(map.area_seed, String(e["key"])))
		enemy.position = map.cell_center(e["cell"])
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.damaged.connect(_on_enemy_damaged)
		_entities.add_child(enemy)

	# decision npc
	if not map.npc_spawn.is_empty():
		_npc = Area2D.new()
		_npc.set_script(SurvivorScript)
		var npc_decision_id := String(map.npc_spawn["decision_id"])
		_npc.setup(npc_decision_id, Content.get_def("decisions", npc_decision_id))
		_npc.position = map.cell_center(map.npc_spawn["cell"])
		_npc.talked.connect(_on_npc_talked)
		_entities.add_child(_npc)

	# exit
	var exit_zone := Area2D.new()
	exit_zone.set_script(ExitZoneScript)
	exit_zone.position = map.cell_center(map.exit)
	exit_zone.exit_requested.connect(_on_exit_requested)
	_entities.add_child(exit_zone)

	# hud
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.set_health(player.combatant.health, player.combatant.max_health)
	_last_player_health = player.combatant.health
	var dest := Session.world.node(expedition.destination_id)
	hud.set_expedition("%s · %s · day %d · %d enemies about" % [String(dest["name"]), DictUtil.get_string(biome, "name"), u.current_day, map.enemy_spawns.size()])
	hud.set_haul(expedition.haul)
	hud.retreat_requested.connect(_on_retreat)
	hud.main_menu_requested.connect(_on_abandon)
	hud.decision_chosen.connect(_on_decision_chosen)
	Session.expeditions.haul_changed.connect(func(h): hud.set_haul(h))
	Session.expeditions.experience_gained.connect(_on_experience)
	hud.toast("Expedition to %s. Find the marked exit to return home." % String(dest["name"]), 4.0)


func _process(_delta: float) -> void:
	if player and Router.debug_extra.size() < 2:
		Router.debug_extra = ["player cell %s  pos %s" % [str(Vector2i(player.position / map.cell_size)), str(player.position.round())], "area %s seed %d repairs %d" % [map.area_id, map.area_seed, map.repairs_applied]]
	elif player:
		Router.debug_extra[0] = "player cell %s  pos %s" % [str(Vector2i(player.position / map.cell_size)), str(player.position.round())]


func _unhandled_input(event: InputEvent) -> void:
	if _ending:
		return
	if event.is_action_pressed("pause"):
		if not hud.is_modal_open():
			hud.toggle_pause(true)
		elif hud._pause.visible:
			hud.toggle_pause(false)


func _on_player_health_changed(current: int, maximum: int) -> void:
	hud.set_health(current, maximum)
	Session.universe().protagonist_condition["health"] = current
	if current < _last_player_health:
		Telemetry.record_event("player_damaged", {"amount": _last_player_health - current, "health": current})
		hud.spawn_damage_number(player.global_position, _last_player_health - current, player.camera(), Color(1, 0.45, 0.4))
	_last_player_health = current


func _on_interact_target_changed(target: Node) -> void:
	hud.set_prompt(target.interaction_prompt() if target != null and is_instance_valid(target) else "")


func _on_harvested(node_key: String, resource_id: String, amount: int) -> void:
	Session.expeditions.collect_resource(node_key, resource_id, amount)
	Telemetry.record_event("resource_collected", {"amount": amount})
	hud.toast("+%d %s" % [amount, resource_id], 1.5)
	hud.set_prompt("")


func _on_enemy_damaged(amount: int, pos: Vector2) -> void:
	hud.spawn_damage_number(pos, amount, player.camera())


func _on_enemy_defeated(enemy: Node) -> void:
	var summary := Session.expeditions.on_enemy_defeated(enemy.enemy_id)
	Telemetry.record_event("enemy_defeated", {"xp": int(summary["xp"])})
	var parts: Array[String] = ["%s defeated (+%d xp)" % [DictUtil.get_string(enemy.definition, "name", enemy.enemy_id), int(summary["xp"])]]
	for r in DictUtil.sorted_keys(summary["drops"]):
		parts.append("+%d %s" % [int(summary["drops"][r]), String(r)])
	hud.toast(", ".join(parts), 2.5)


func _on_experience(_amount: int, levels: int) -> void:
	if levels > 0:
		var c := Session.character()
		hud.toast("Level %d! You feel steadier." % c.level, 3.0)
		# Level-up heals (see balance.json); refresh the live combatant from state.
		player.combatant.max_health = ProgressionRules.max_health(c, Content.balance("character"))
		player.combatant.attack = ProgressionRules.attack(c, Content.balance("character"))
		player.combatant.defense = ProgressionRules.defense(c, Content.balance("character"))
		player.combatant.health = DictUtil.get_int(Session.universe().protagonist_condition, "health", player.combatant.max_health)
		player.move_speed = ProgressionRules.move_speed(c, Content.balance("character"))
		hud.set_health(player.combatant.health, player.combatant.max_health)


func _on_npc_talked(decision_id: String) -> void:
	hud.show_decision(decision_id, Content.get_def("decisions", decision_id), Session.expeditions.active(), Session.universe())


func _on_decision_chosen(decision_id: String, option_id: String) -> void:
	var decision := Content.get_def("decisions", decision_id)
	var r := DecisionRules.resolve(Session.save, decision_id, decision, option_id)
	if not r.ok:
		Telemetry.record_event("decision_rejected")
		hud.show_decision_result("Something stops you: " + r.error)
		return
	Telemetry.record_event("decision_resolved")
	hud.set_haul(Session.expeditions.active().haul)
	if _npc:
		_npc.mark_resolved()
	hud.set_prompt("")
	var result := DictUtil.get_string(DictUtil.get_dict(DictUtil.get_dict(decision, "options"), option_id), "result", "")
	var effects: Dictionary = r.value
	if int(effects.get("health", 0)) != 0:
		# The rule already changed the persisted condition; mirror it on the live body.
		player.combatant.health = DictUtil.get_int(Session.universe().protagonist_condition, "health", player.combatant.health)
		hud.set_health(player.combatant.health, player.combatant.max_health)
		_last_player_health = player.combatant.health
	var notes: Array[String] = []
	if int(effects.get("morality", 0)) != 0:
		notes.append("Morality %+d" % int(effects["morality"]))
	for fid in DictUtil.sorted_keys(DictUtil.get_dict(effects, "reputation")):
		notes.append("%s %+d" % [DictUtil.get_string(Content.get_def("factions", String(fid)), "name"), int(effects["reputation"][fid])])
	if int(effects.get("recruits", 0)) > 0:
		notes.append("+%d recruit" % int(effects["recruits"]))
	if int(effects.get("health", 0)) != 0:
		notes.append("Health %+d" % int(effects["health"]))
	hud.show_decision_result(result + ("\n\n" + " · ".join(notes) if not notes.is_empty() else ""))


func _on_exit_requested() -> void:
	_end_expedition("returned")


func _on_retreat() -> void:
	_end_expedition("retreated")


func _on_abandon() -> void:
	Telemetry.record_event("expedition_abandoned")
	_ending = true
	get_tree().paused = false
	Session.end_session()
	Router.go("main_menu")


func _on_player_died() -> void:
	if _ending:
		return
	Telemetry.record_event("player_defeated")
	_ending = true
	player.input_enabled = false
	hud.set_prompt("")
	hud.show_death()
	await get_tree().create_timer(2.0).timeout
	var r := Session.transitions.on_protagonist_defeated({"area": map.area_id})
	if not r.ok:
		Telemetry.record_event("resurrection_failed")
		push_error("Resurrection failed: " + r.error)
		hud.toast("ERROR: " + r.error, 5.0)
		return
	Telemetry.record_event("expedition_finished", {"outcome": 2})
	Session.pending_expedition_summary = DictUtil.get_dict(r.value, "result")
	_save_and_go_home()


func _end_expedition(reason: String) -> void:
	if _ending:
		return
	_ending = true
	player.input_enabled = false
	var r := Session.expeditions.finish(reason)
	if not r.ok:
		Telemetry.record_event("expedition_failed")
		push_error("Cannot end expedition: " + r.error)
		hud.toast("ERROR: " + r.error, 5.0)
		_ending = false
		player.input_enabled = true
		return
	Telemetry.record_event("expedition_finished", {"outcome": 0 if reason == "returned" else 1})
	Session.pending_expedition_summary = r.value
	_save_and_go_home()


func _save_and_go_home() -> void:
	var w := Session.save_game()
	if not w.ok:
		push_error("Autosave failed: " + w.error)
		Session.last_messages.append("Autosave failed: " + w.error)
	Router.go("settlement")
