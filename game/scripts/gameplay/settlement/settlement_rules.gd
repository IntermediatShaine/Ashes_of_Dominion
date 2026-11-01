class_name SettlementRules
extends RefCounted
## Derived settlement values and the daily tick. Pure functions over
## SettlementState + building definitions + balance.


static func population_capacity(s: SettlementState, building_defs: Dictionary) -> int:
	return s.base_population_capacity + _sum_effect(s, building_defs, "population_capacity")


static func storage_capacity(s: SettlementState, building_defs: Dictionary) -> int:
	return s.base_storage_capacity + _sum_effect(s, building_defs, "storage_capacity")


static func military_strength(s: SettlementState, building_defs: Dictionary) -> int:
	return s.military_strength + _sum_effect(s, building_defs, "military_strength")


## resource_id -> units produced per day (before productivity scaling)
static func daily_production(s: SettlementState, building_defs: Dictionary) -> Dictionary:
	var out := {}
	for b in s.buildings:
		var d: Dictionary = building_defs.get(String(b.get("definition_id", "")), {})
		var prod := DictUtil.get_dict(DictUtil.get_dict(d, "effects"), "production")
		for r in DictUtil.sorted_keys(prod):
			out[r] = int(out.get(r, 0)) + DictUtil.get_int(prod, String(r), 0)
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
## future random events.
static func tick_day(s: SettlementState, building_defs: Dictionary, settlement_balance: Dictionary) -> Dictionary:
	var summary := {"produced": {}, "consumed": {}, "starved": false, "lost": {}}
	# production, scaled by productivity (50 = nominal)
	var prod := daily_production(s, building_defs)
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
	return summary


## Moves pending recruits into the population, bounded by capacity.
static func settle_recruits(s: SettlementState, building_defs: Dictionary) -> int:
	if s.pending_recruits <= 0:
		return 0
	var cap := population_capacity(s, building_defs)
	var room := maxi(0, cap - s.population)
	var moved := mini(room, s.pending_recruits)
	s.population += moved
	s.pending_recruits -= moved
	return moved


static func _sum_effect(s: SettlementState, building_defs: Dictionary, effect: String) -> int:
	var total := 0
	for b in s.buildings:
		var d: Dictionary = building_defs.get(String(b.get("definition_id", "")), {})
		total += DictUtil.get_int(DictUtil.get_dict(d, "effects"), effect, 0)
	return total
