class_name ExpeditionService
extends RefCounted
## Expedition lifecycle: start -> (exploration events) -> finish -> resolve.
##
## Resolution is idempotent: ExpeditionRecord.resolved guards every effect,
## so a crash between "finish" and "save" cannot double-apply a haul, count an
## expedition twice or advance the calendar twice.

signal haul_changed(haul: Dictionary)
signal experience_gained(amount: int, levels: int)

var save: SaveGame
var world: WorldGraph
var rng: RngRegistry
var content


func _init(p_save: SaveGame, p_world: WorldGraph, p_rng: RngRegistry, p_content) -> void:
	save = p_save
	world = p_world
	rng = p_rng
	content = p_content


func universe() -> UniverseState:
	return save.universe


func active() -> ExpeditionRecord:
	return universe().active_expedition()


func home_landmark_id() -> String:
	return universe().home_landmark_id()


## Landmarks the player may travel to right now.
func available_destinations() -> Array[String]:
	var out: Array[String] = []
	for id in world.node_ids():
		var n := world.node(String(id))
		if not n["explorable"]:
			continue
		if universe().is_landmark_discovered(String(id)):
			out.append(String(id))
	return out


func plan_routes(destination_id: String) -> Array[Dictionary]:
	var day_cost := DictUtil.get_float(content.balance("expedition"), "day_cost_units", 150.0)
	return RoutePlanner.plan_alternatives(world, home_landmark_id(), destination_id, day_cost, 1)


func start(destination_id: String, route: Dictionary) -> OpResult:
	var u := universe()
	if active() != null:
		return OpResult.failure("An expedition is already active")
	if not available_destinations().has(destination_id):
		return OpResult.failure("Destination %s is not known or not explorable" % destination_id)
	if route.is_empty() or route.get("node_ids", []).is_empty():
		return OpResult.failure("No route to " + destination_id)
	var e := ExpeditionRecord.new()
	e.expedition_id = IdFactory.next_sequential(u.id_counters, "exp")
	e.origin_id = home_landmark_id()
	e.destination_id = destination_id
	e.route_node_ids = DictUtil.string_array(route["node_ids"])
	e.route_edge_ids = DictUtil.string_array(route["edge_ids"])
	e.travel_days = int(route.get("travel_days", 1))
	e.status = ExpeditionRecord.STATUS_ACTIVE
	e.started_day = u.current_day
	u.expeditions[e.expedition_id] = e
	u.active_expedition_id = e.expedition_id
	return OpResult.success(e.expedition_id)


## Builds the explorable area for the active expedition's destination.
func build_area() -> WildernessMap:
	var e := active()
	assert(e != null, "build_area without active expedition")
	var u := universe()
	var node := world.node(e.destination_id)
	var biome_id: String = node["biome"]
	var mods := DictUtil.get_dict(u.world_modifications, e.destination_id)
	var decision_id := DecisionRules.select_for_area(content.table("decisions"), u, biome_id, e.destination_id)
	var params := {
		"biome": content.get_def("biomes", biome_id),
		"danger": int(node["danger"]),
		"resource_abundance": DictUtil.get_float(u.difficulty, "resource_abundance_multiplier", 1.0),
		"decision_id": decision_id,
		"harvested": DictUtil.get_dict(mods, "harvested"),
		"current_day": u.current_day,
		"regrowth_days": DictUtil.get_int(content.balance("expedition"), "resource_regrowth_days", 10),
	}
	return WildernessGenerator.generate(u.world_seed, u.generation_version, e.destination_id, biome_id, params, content.balance("wilderness"))


## Called by the exploration scene when a resource node is harvested.
func collect_resource(node_key: String, resource_id: String, amount: int) -> void:
	var e := active()
	if e == null or amount <= 0:
		return
	var u := universe()
	if not u.world_modifications.has(e.destination_id):
		u.world_modifications[e.destination_id] = {"harvested": {}}
	var area: Dictionary = u.world_modifications[e.destination_id]
	if not area.has("harvested"):
		area["harvested"] = {}
	(area["harvested"] as Dictionary)[node_key] = u.current_day
	e.add_haul(resource_id, amount)
	haul_changed.emit(e.haul)


## Called when an enemy dies. Rolls drops on the rewards stream, grants XP.
func on_enemy_defeated(enemy_id: String) -> Dictionary:
	var e := active()
	var summary := {"xp": 0, "levels": 0, "drops": {}}
	if e == null:
		return summary
	var def: Dictionary = content.get_def("enemies", enemy_id)
	e.enemies_defeated += 1
	var rewards := rng.stream("rewards")
	var drops := DictUtil.get_dict(def, "drops")
	for rid in DictUtil.sorted_keys(drops):
		var range_arr: Array = drops[rid]
		if range_arr.size() != 2:
			continue
		var n := rewards.randi_range(int(range_arr[0]), int(range_arr[1]))
		if n > 0:
			e.add_haul(String(rid), n)
			summary["drops"][rid] = n
	var xp := DictUtil.get_int(def, "experience", 0)
	if xp > 0:
		var levels := grant_experience(xp)
		summary["xp"] = xp
		summary["levels"] = levels
	if not summary["drops"].is_empty():
		haul_changed.emit(e.haul)
	return summary


func grant_experience(xp: int) -> int:
	var arch: Dictionary = content.get_def("archetypes", save.character.archetype_id)
	var levels := ProgressionRules.add_experience(save.character, xp, content.balance("progression"), DictUtil.get_dict(arch, "level_growth"))
	var e := active()
	if e != null:
		e.experience_gained += xp
	if levels > 0:
		ClassRules.refresh_unlocks(save.character, content.table("classes"))
		if DictUtil.get_bool(content.balance("progression"), "heal_on_level_up", true):
			universe().protagonist_condition["health"] = ProgressionRules.max_health(save.character, content.balance("character"))
	experience_gained.emit(xp, levels)
	return levels


## Ends the active expedition with the given reason and resolves it.
## exit_reason: "returned" | "retreated" | "defeated"
func finish(exit_reason: String) -> OpResult:
	var e := active()
	if e == null:
		return OpResult.failure("No active expedition to finish")
	match exit_reason:
		"returned":
			e.status = ExpeditionRecord.STATUS_COMPLETED
		"retreated":
			e.status = ExpeditionRecord.STATUS_ABORTED
		"defeated":
			e.status = ExpeditionRecord.STATUS_DEFEATED
		_:
			return OpResult.failure("Unknown exit reason " + exit_reason)
	e.exit_reason = exit_reason
	return resolve(e.expedition_id)


## Applies an ended expedition's outcome exactly once. Safe to call again.
func resolve(expedition_id: String) -> OpResult:
	var u := universe()
	if not u.expeditions.has(expedition_id):
		return OpResult.failure("Unknown expedition " + expedition_id)
	var e: ExpeditionRecord = u.expeditions[expedition_id]
	if e.is_active():
		return OpResult.failure("Expedition %s is still active" % expedition_id)
	var summary := {"expedition_id": expedition_id, "status": e.status, "delivered": {}, "lost": {}, "days_passed": 0, "recruits": 0, "discovered": [], "already_resolved": e.resolved, "sim": []}
	if e.resolved:
		return OpResult.success(summary)
	var exp_bal: Dictionary = content.balance("expedition")
	var settlement := u.home_settlement()
	var building_defs: Dictionary = content.table("buildings")

	# 1. haul
	var deliver := true
	if e.status == ExpeditionRecord.STATUS_DEFEATED and DictUtil.get_bool(exp_bal, "defeat_loses_haul", true):
		deliver = false
	if e.status == ExpeditionRecord.STATUS_ABORTED and not DictUtil.get_bool(exp_bal, "retreat_keeps_haul", true):
		deliver = false
	if deliver:
		var r := SettlementRules.add_resources(settlement, e.haul, building_defs, content.balance("settlement"))
		summary["delivered"] = r["added"]
		summary["lost"] = r["lost"]
	else:
		summary["lost"] = e.haul.duplicate()

	# 2. discovery (completed expeditions chart the route and reveal neighbours)
	if e.status == ExpeditionRecord.STATUS_COMPLETED:
		for eid in e.route_edge_ids:
			u.reveal_edge(eid)
		for nid in e.route_node_ids:
			if world.node(nid).get("persistent", false) and u.discover_landmark(nid):
				summary["discovered"].append(nid)
		for nid in world.neighbor_ids(e.destination_id):
			if world.node(nid).get("persistent", false) and u.discover_landmark(nid):
				summary["discovered"].append(nid)
	else:
		# Even a failed trip teaches the first leg.
		if not e.route_edge_ids.is_empty():
			u.reveal_edge(e.route_edge_ids[0])

	# 3. calendar + world simulation
	var days := e.travel_days * (2 if e.status != ExpeditionRecord.STATUS_DEFEATED else 1)
	summary["days_passed"] = days
	summary["sim"] = WorldSimulation.advance_days(save, days, content)
	e.ended_day = u.current_day

	# 4. settlement arrivals, protagonist recovery
	summary["recruits"] = SettlementRules.settle_recruits(settlement, building_defs)
	u.protagonist_condition["health"] = ProgressionRules.max_health(save.character, content.balance("character"))

	# 5. threat progression (exactly once per expedition)
	ThreatRules.on_expedition_resolved(u.threat_state, settlement.buildings.size(), content.balance("threat"))

	# 6. bookkeeping
	e.resolved = true
	u.expedition_history.append(expedition_id)
	if u.active_expedition_id == expedition_id:
		u.active_expedition_id = ""
	return OpResult.success(summary)
