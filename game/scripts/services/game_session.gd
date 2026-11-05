extends Node
## Autoload "Session": owns the loaded SaveGame and the services bound to it.
##
## This is deliberately a thin owner, not a god object: rules live in
## scripts/gameplay, persistence in scripts/persistence, generation in
## scripts/generation. Scenes talk to Session (and the services it exposes)
## instead of to each other.

signal state_changed()
signal game_saved(slot: int, result: OpResult)
## Emitted just before the state is written, so whoever shows the current map
## can record where the player stands (see MapTravelService.remember_position).
signal saving()

var save: SaveGame = null
var world: WorldGraph = null
var rng: RngRegistry = null
var expeditions: ExpeditionService = null
var transitions: TransitionService = null
## The one door to the home settlement's state (snapshots, requests, signals).
var settlement_service: SettlementService = null
## Entering/leaving maps and return destinations.
var travel: MapTravelService = null
var current_slot: int = 0
var repository: SaveRepository = SaveRepository.new("user://saves")
## Summary of the last resolved expedition, for the settlement screen to show once.
var pending_expedition_summary: Dictionary = {}
var last_messages: Array[String] = []


func has_game() -> bool:
	return save != null


## options: {name: String, archetype_id: String, difficulty: Dictionary,
##           mist_enabled: bool, seed: int}
func new_game(options: Dictionary, slot: int) -> OpResult:
	if not repository.is_valid_slot(slot):
		return OpResult.failure("Invalid slot %d" % slot)
	var archetype_id := DictUtil.get_string(options, "archetype_id")
	var c := CharacterFactory.create(DictUtil.get_string(options, "name"), archetype_id, Content.get_def("archetypes", archetype_id), Content.table("ancestries"))
	if not c.ok:
		return c
	var difficulty := DictUtil.get_dict(options, "difficulty")
	var diff_errors := DifficultyRules.validate(difficulty, Content.table("difficulty"))
	if not diff_errors.is_empty():
		return OpResult.failure("Difficulty invalid: " + "; ".join(diff_errors))
	var m := MultiverseState.new()
	var u := UniverseFactory.create(DictUtil.get_int(options, "seed", 0), difficulty, {"mist_enabled": DictUtil.get_bool(options, "mist_enabled", true)}, c.value, m, Content)
	if not u.ok:
		return u
	var s := SaveGame.new()
	s.character = c.value
	s.universe = u.value
	s.multiverse = m
	_bind(s)
	current_slot = slot
	var w := save_game()
	if not w.ok:
		_unbind()
		return w
	Telemetry.record_event("game_created", {"slot": slot})
	state_changed.emit()
	return OpResult.success(s)


func load_slot(slot: int) -> OpResult:
	var r := repository.load_slot(slot)
	if not r.ok:
		Telemetry.record_event("game_load_failed", {"slot": slot})
		return r
	_bind(r.value)
	current_slot = slot
	last_messages.clear()
	for w in r.warnings:
		last_messages.append(w)
	# Finish anything a crash interrupted, then persist the recovered state.
	var rec := transitions.recover_pending()
	if not rec.ok:
		Telemetry.record_event("game_load_failed", {"slot": slot})
		return rec
	if rec.value is Dictionary and DictUtil.get_bool(rec.value, "recovered", false):
		last_messages.append("Completed an interrupted transition.")
		pending_expedition_summary = DictUtil.get_dict(rec.value, "result")
		save_game()
	Telemetry.record_event("game_loaded", {"slot": slot})
	_telemetry_state_check()
	state_changed.emit()
	return OpResult.success(save)


## Most recently saved slot, or 0.
func latest_slot() -> int:
	var best := 0
	var best_t := -1
	var slots := repository.list_slots()
	for slot in slots.keys():
		var meta = slots[slot]
		if meta is Dictionary and DictUtil.get_int(meta, "saved_at_unix", 0) > best_t:
			best_t = DictUtil.get_int(meta, "saved_at_unix", 0)
			best = int(slot)
	return best


func continue_latest() -> OpResult:
	var slot := latest_slot()
	if slot == 0:
		return OpResult.failure("No saved games")
	return load_slot(slot)


func save_game() -> OpResult:
	if save == null:
		return OpResult.failure("No game to save")
	if current_slot == 0:
		return OpResult.failure("No save slot selected")
	var started := Time.get_ticks_msec()
	saving.emit()
	save.universe.rng_states = rng.to_dict()
	_telemetry_state_check()
	var r := repository.write(current_slot, save)
	Telemetry.record_event("save_succeeded" if r.ok else "save_failed", {"slot": current_slot, "elapsed_ms": Time.get_ticks_msec() - started})
	game_saved.emit(current_slot, r)
	return r


func _telemetry_state_check() -> void:
	if Telemetry.is_enabled() and save != null:
		Telemetry.record_event("state_checked", {"errors": save.validate().size()})


## Builds `definition_id` on the site it belongs to (its reserved village site,
## else the first free plot). Kept for callers that predate building sites;
## new code uses `settlement_service.request_construction(site_id, id)`.
## value = the new building instance, or {} while it is still under construction.
func construct_building(definition_id: String) -> OpResult:
	if save == null:
		return OpResult.failure("No game")
	var r := settlement_service.request_construction_anywhere(definition_id)
	if r.ok:
		r.value = DictUtil.get_dict(r.value, "instance")
	return r


func _on_settlement_changed(_reason: String) -> void:
	state_changed.emit()


func _on_settlement_event(event: Dictionary) -> void:
	if DictUtil.get_string(event, "type") == "building_constructed":
		Telemetry.record_event("building_built")


func end_session() -> void:
	Telemetry.record_event("game_ended")
	_unbind()
	state_changed.emit()


func _bind(s: SaveGame) -> void:
	save = s
	var bal := Content.table("balance")
	world = WorldGraphGenerator.generate(s.universe.world_seed, s.universe.generation_version, Content.table("landmarks"), Content.table("biomes"), DictUtil.get_dict(bal, "world_map"))
	rng = RngRegistry.from_dict(s.universe.rng_states, s.universe.world_seed)
	expeditions = ExpeditionService.new(s, world, rng, Content)
	transitions = TransitionService.new(s, expeditions)
	settlement_service = SettlementService.new(s, Content)
	travel = MapTravelService.new(s, Content)
	# Finishes what a migration from an older save format could not know
	# (resident names, building sites); a no-op for a current save.
	settlement_service.normalize()
	settlement_service.settlement_changed.connect(_on_settlement_changed)
	settlement_service.event_recorded.connect(_on_settlement_event)


func _unbind() -> void:
	save = null
	world = null
	rng = null
	expeditions = null
	transitions = null
	settlement_service = null
	travel = null
	current_slot = 0
	pending_expedition_summary = {}


## Convenience accessors for UI
func character() -> CharacterState:
	return save.character if save else null


func universe() -> UniverseState:
	return save.universe if save else null


func settlement() -> SettlementState:
	return save.universe.home_settlement() if save else null


func debug_lines() -> Array[String]:
	var lines: Array[String] = []
	if save == null:
		lines.append("no game loaded")
		return lines
	var u := save.universe
	lines.append("universe %s  seed %d  gen v%d  day %d" % [u.universe_id, u.world_seed, u.generation_version, u.current_day])
	lines.append("slot %d  character %s L%d  morality %d" % [current_slot, save.character.character_name, save.character.level, save.character.morality])
	lines.append("expedition %s  threat %s  deaths %d" % [u.active_expedition_id if u.active_expedition_id != "" else "-", str(u.threat_state), u.death_count])
	lines.append("difficulty %s" % DifficultyRules.display_name(u.difficulty, Content.table("difficulty")))
	var streams: Array[String] = []
	for name in RngRegistry.STREAM_NAMES:
		streams.append("%s:%d" % [name, rng.stream(name).draw_count])
	lines.append("rng draws " + " ".join(streams))
	return lines
