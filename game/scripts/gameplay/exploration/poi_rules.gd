class_name PoiRules
extends RefCounted
## Hand-authored POIs share expedition records, haul, map flags and death rules.
## Rewards and their once markers belong to the same SaveGame transaction.

static func start(expeditions: ExpeditionService, id: String) -> OpResult:
	var u := expeditions.universe()
	var defs: Dictionary = expeditions.content.table("pois")
	if not defs.has(id) or expeditions.active() != null:
		return OpResult.failure("Unknown POI or an expedition is already active")
	if DictUtil.get_string(u.location, "map_id") != MapRegistry.map_for_settlement(expeditions.content.table("maps"), u.home_settlement_id):
		return OpResult.failure("Depart from the village")
	var e := ExpeditionRecord.new()
	e.expedition_id = IdFactory.next_sequential(u.id_counters, "exp")
	e.origin_id = expeditions.home_landmark_id()
	e.destination_id = id
	e.started_day = u.current_day
	e.travel_days = DictUtil.get_int(defs[id], "travel_days", 1)
	u.expeditions[e.expedition_id] = e
	u.active_expedition_id = e.expedition_id
	MapLocation.enter(u.location, id, "arrival", true, "gate")
	return OpResult.success(e.expedition_id)

static func active_id(expeditions: ExpeditionService) -> String:
	var e := expeditions.active()
	if e == null or not expeditions.content.table("pois").has(e.destination_id):
		return ""
	return e.destination_id

static func object_definition(expeditions: ExpeditionService, key: String) -> Dictionary:
	var id := active_id(expeditions)
	if id == "":
		return {}
	for object in expeditions.content.table("pois")[id]["objects"]:
		if String(object["id"]) == key:
			return object
	return {}

static func available(expeditions: ExpeditionService, key: String) -> bool:
	var object := object_definition(expeditions, key)
	if object.is_empty():
		return false
	var u := expeditions.universe()
	var id := active_id(expeditions)
	if not MapStateStore.is_done(u, id, key):
		return true
	var regrowth := DictUtil.get_int(object, "regrowth_days")
	var day := DictUtil.get_int(DictUtil.get_dict(MapStateStore.record(u, id), "once"), key)
	return regrowth > 0 and u.current_day - day >= regrowth

static func claim(expeditions: ExpeditionService, key: String, choice: String = "") -> OpResult:
	var object := object_definition(expeditions, key)
	if not available(expeditions, key):
		return OpResult.failure("Already collected or unknown object")
	var u := expeditions.universe()
	var id := active_id(expeditions)
	for enemy in DictUtil.get_array(object, "requires_defeated"):
		if not MapStateStore.is_done(u, id, String(enemy)):
			return OpResult.failure("Defeat the tower guards first")
	var effect: Dictionary = object
	var choices := DictUtil.get_dict(object, "choices")
	if not choices.is_empty():
		if not choices.has(choice):
			return OpResult.failure("Choose how to treat the shrine")
		effect = choices[choice]
	var reward := DictUtil.get_dict(effect, "reward")
	var error := ResourceTransaction.validate_amounts(reward, expeditions.content.table("resources"))
	if error != "":
		return OpResult.failure(error)
	# Commit after all validation. Reload restores both reward and marker together.
	var rec := MapStateStore.record(u, id)
	if not rec.has("once"):
		rec["once"] = {}
	rec["once"][key] = u.current_day
	for rid in reward:
		expeditions.active().add_haul(rid, int(reward[rid]))
	var recruits := DictUtil.get_int(effect, "recruits")
	u.home_settlement().pending_recruits += recruits
	var lore := DictUtil.get_string(effect, "lore")
	if lore != "" and not expeditions.save.character.persistent_lore.has(lore):
		expeditions.save.character.persistent_lore.append(lore)
	if not choices.is_empty():
		MapStateStore.set_flag(u, id, "decision", choice)
		MoralityRules.apply_event(expeditions.save.character, u.universe_id + ":" + id + ":" + key, choice, DictUtil.get_int(effect, "morality"), u.universe_id)
		# An enduring world consequence: protection or desecration, separate from reputation.
		MapStateStore.set_flag(u, id, "consequence", DictUtil.get_string(effect, "consequence"))
		MapStateStore.set_flag(u, id, "defense_bonus", DictUtil.get_int(effect, "defense_bonus"))
	var equipment := DictUtil.get_string(effect, "equipment")
	if equipment != "" and DictUtil.get_int(effect, "attack_bonus") > DictUtil.get_int(u.protagonist_condition, "equipment_attack"):
		u.protagonist_condition["equipment"] = equipment
		u.protagonist_condition["equipment_attack"] = DictUtil.get_int(effect, "attack_bonus")
	expeditions.haul_changed.emit(expeditions.active().haul)
	return OpResult.success(effect.duplicate(true))

static func enemy_defeated(expeditions: ExpeditionService, key: String) -> OpResult:
	var id := active_id(expeditions)
	if id == "":
		return OpResult.failure("No POI expedition")
	for enemy in expeditions.content.table("pois")[id]["enemies"]:
		if String(enemy["id"]) == key:
			if not MapStateStore.mark_done(expeditions.universe(), id, key):
				return OpResult.failure("Enemy already defeated")
			return OpResult.success(expeditions.on_enemy_defeated(String(enemy["enemy_id"])))
	return OpResult.failure("Unknown enemy")
