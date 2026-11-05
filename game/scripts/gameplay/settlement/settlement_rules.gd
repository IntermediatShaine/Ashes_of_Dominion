class_name SettlementRules
extends RefCounted
## Derived settlement values and the daily tick. Pure functions over
## SettlementState + building definitions + balance.


static func population_capacity(s: SettlementState, building_defs: Dictionary) -> int:
	return s.base_population_capacity + _sum_effect(s, building_defs, "population_capacity")


static func storage_capacity(s: SettlementState, building_defs: Dictionary) -> int:
	return s.base_storage_capacity + _sum_effect(s, building_defs, "storage_capacity")


static func military_strength(s: SettlementState, building_defs: Dictionary) -> int:
	var strength := s.military_strength + _sum_effect(s, building_defs, "military_strength")
	for b in s.buildings:
		var effects := BuildingRules.effects_for(b, building_defs)
		strength += mini(s.workers_assigned_to(String(b["instance_id"])).size(), DictUtil.get_int(effects, "worker_slots")) * DictUtil.get_int(effects, "military_strength_per_worker")
	return strength


## resource_id -> units produced per day (before productivity scaling).
## A building's level decides its effects; residents assigned to it add
## `production_per_worker` each; a destroyed building produces nothing.
static func daily_production(s: SettlementState, building_defs: Dictionary, bonus: Dictionary = {}) -> Dictionary:
	var out := bonus.duplicate()
	for b in s.buildings:
		var effects := BuildingRules.effects_for(b, building_defs)
		var prod := DictUtil.get_dict(effects, "production")
		for r in DictUtil.sorted_keys(prod):
			out[r] = int(out.get(r, 0)) + DictUtil.get_int(prod, String(r), 0)
		var per_worker := DictUtil.get_dict(effects, "production_per_worker")
		if per_worker.is_empty():
			continue
		var workers := mini(s.workers_assigned_to(String(b.get("instance_id", ""))).size(), DictUtil.get_int(effects, "worker_slots", 0))
		for r in DictUtil.sorted_keys(per_worker):
			if workers > 0:
				out[r] = int(out.get(r, 0)) + workers * DictUtil.get_int(per_worker, String(r), 0)
	return out


## Adds resources respecting the storage cap. Returns {added:{}, lost:{}}.
static func add_resources(s: SettlementState, amounts: Dictionary, building_defs: Dictionary, settlement_balance: Dictionary) -> Dictionary:
	var cap := storage_capacity(s, building_defs)
	var lose_overflow := DictUtil.get_bool(settlement_balance, "overflow_resources_lost", true)
	var added := {}
	var lost := {}
	for r in DictUtil.sorted_keys(amounts):
		var want := int(amounts[r])
		if want <= 0:
			continue
		var have := s.resource_amount(String(r))
		var room := maxi(0, cap - have) if lose_overflow else want
		var put := mini(want, room)
		s.resources[r] = have + put
		added[r] = put
		if want - put > 0:
			lost[r] = want - put
	return {"added": added, "lost": lost}


## One in-game day of settlement life. Returns a summary dictionary.
## Deterministic: no randomness is used here; `events` stream reserved for
## future random events. `day` is the calendar day that has just begun (used
## to date finished construction and log entries).
static func tick_day(s: SettlementState, building_defs: Dictionary, settlement_balance: Dictionary, day: int = 0, production_bonus: Dictionary = {}) -> Dictionary:
	var summary := {"produced": {}, "consumed": {}, "starved": false, "lost": {}, "jobs_completed": []}
	# production, scaled by productivity (50 = nominal)
	var prod := daily_production(s, building_defs, production_bonus)
	var scaled := {}
	for r in DictUtil.sorted_keys(prod):
		scaled[r] = int(round(int(prod[r]) * (float(s.productivity) / 50.0)))
	var result := add_resources(s, scaled, building_defs, settlement_balance)
	summary["produced"] = result["added"]
	summary["lost"] = result["lost"]
	# food consumption
	var per_person := DictUtil.get_float(settlement_balance, "food_consumption_per_person_day", 0.2)
	var need := int(ceil(s.population * per_person))
	var have := s.resource_amount("food")
	var eaten := mini(need, have)
	s.resources["food"] = have - eaten
	summary["consumed"]["food"] = eaten
	if eaten < need and need > 0:
		summary["starved"] = true
		s.morale = clampi(s.morale - DictUtil.get_int(settlement_balance, "starvation_morale_penalty_per_day", 3), 0, 100)
	else:
		s.morale = clampi(s.morale + DictUtil.get_int(settlement_balance, "fed_morale_recovery_per_day", 1), 0, 100)
	# wear (off unless balance.json enables it), then a day of construction work
	var decay := DictUtil.get_int(settlement_balance, "condition_decay_per_day", 0)
	if decay > 0:
		for b in s.buildings:
			if b is Dictionary:
				BuildingRules.apply_damage(b, decay)
		PopulationRules.release_invalid(s, building_defs)
	summary["jobs_completed"] = ConstructionJobRules.tick_day(s, building_defs, settlement_balance, day)
	return summary


## Moves pending recruits into the population, bounded by capacity. Each
## arrival becomes a resident (named later by PopulationRules.ensure_names).
static func settle_recruits(s: SettlementState, building_defs: Dictionary, day: int = 0) -> int:
	if s.pending_recruits <= 0:
		return 0
	var cap := population_capacity(s, building_defs)
	var room := maxi(0, cap - s.population)
	var moved := mini(room, s.pending_recruits)
	for i in moved:
		s.add_resident("recruit", day)
	s.pending_recruits -= moved
	return moved


static func _sum_effect(s: SettlementState, building_defs: Dictionary, effect: String) -> int:
	var total := 0
	for b in s.buildings:
		total += DictUtil.get_int(BuildingRules.effects_for(b, building_defs), effect, 0)
	return total
