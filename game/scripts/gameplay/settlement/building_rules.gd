class_name BuildingRules
extends RefCounted
## Levels, condition and effects of building instances. Pure functions over a
## building definition (data/buildings.json) and an instance dictionary
## (SettlementState.buildings[*]) — the two are never merged or copied.
##
## Level 1 comes from the definition's cost / build_days / requires / effects;
## level N > 1 from upgrades[N - 2]. A level's effects REPLACE the previous
## level's. A building whose condition is 0 is destroyed: it keeps its level
## but has no effects until it is repaired.


static func level_of(instance: Dictionary) -> int:
	return maxi(1, DictUtil.get_int(instance, "level", 1))


static func condition_of(instance: Dictionary) -> int:
	return clampi(DictUtil.get_int(instance, "condition", SettlementState.MAX_CONDITION), 0, SettlementState.MAX_CONDITION)


static func is_functional(instance: Dictionary) -> bool:
	return not instance.is_empty() and condition_of(instance) > 0


static func max_level(definition: Dictionary) -> int:
	return 1 + DictUtil.get_array(definition, "upgrades").size()


## {level, cost, days, effects, requires} for one level, or {} if the
## definition has no such level.
static func level_spec(definition: Dictionary, level: int) -> Dictionary:
	if definition.is_empty() or level < 1 or level > max_level(definition):
		return {}
	if level == 1:
		return {
			"level": 1,
			"cost": DictUtil.get_dict(definition, "cost"),
			"days": maxi(0, DictUtil.get_int(definition, "build_days", 0)),
			"effects": DictUtil.get_dict(definition, "effects"),
			"requires": DictUtil.get_array(definition, "requires"),
		}
	var raw = DictUtil.get_array(definition, "upgrades")[level - 2]
	var upgrade: Dictionary = raw if raw is Dictionary else {}
	return {
		"level": level,
		"cost": DictUtil.get_dict(upgrade, "cost"),
		"days": maxi(0, DictUtil.get_int(upgrade, "days", 0)),
		"effects": DictUtil.get_dict(upgrade, "effects"),
		"requires": DictUtil.get_array(upgrade, "requires"),
	}


## Effects currently provided by an instance ({} while destroyed).
static func effects_for(instance: Dictionary, building_defs: Dictionary) -> Dictionary:
	if not is_functional(instance):
		return {}
	var definition := DictUtil.get_dict(building_defs, DictUtil.get_string(instance, "definition_id"))
	return DictUtil.get_dict(level_spec(definition, level_of(instance)), "effects")


static func worker_slots(instance: Dictionary, building_defs: Dictionary) -> int:
	return maxi(0, DictUtil.get_int(effects_for(instance, building_defs), "worker_slots", 0))


## Label of the band a condition value falls in (bands: [{min, label}]).
static func condition_label(condition: int, bands: Array) -> String:
	var best_min := -1
	var label := ""
	for band in bands:
		if not (band is Dictionary):
			continue
		var band_min := DictUtil.get_int(band, "min", 0)
		if condition >= band_min and band_min > best_min:
			best_min = band_min
			label = DictUtil.get_string(band, "label")
	return label


## Why an instance cannot be upgraded right now; empty means it can.
static func upgrade_blocking_reasons(s: SettlementState, instance: Dictionary, building_defs: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if instance.is_empty():
		reasons.append("Unknown building")
		return reasons
	var definition_id := DictUtil.get_string(instance, "definition_id")
	if not building_defs.has(definition_id):
		reasons.append("Unknown building '%s'" % definition_id)
		return reasons
	var definition: Dictionary = building_defs[definition_id]
	var level := level_of(instance)
	if level >= max_level(definition):
		reasons.append("Already at the highest level")
		return reasons
	if not s.job_for_instance(DictUtil.get_string(instance, "instance_id")).is_empty():
		reasons.append("Work is already under way here")
	if not is_functional(instance):
		reasons.append("Must be repaired first")
	var spec := level_spec(definition, level + 1)
	for req in DictUtil.get_array(spec, "requires"):
		if s.building_count(String(req)) == 0:
			reasons.append("Requires " + DictUtil.get_string(DictUtil.get_dict(building_defs, String(req)), "name", String(req)))
	reasons.append_array(cost_blocking_reasons(s, DictUtil.get_dict(spec, "cost")))
	return reasons


static func cost_blocking_reasons(s: SettlementState, cost: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var error := ResourceTransaction.validate_amounts(cost, cost)
	if error != "":
		reasons.append(error)
		return reasons
	for r in DictUtil.sorted_keys(cost):
		var need := DictUtil.get_int(cost, String(r))
		if s.resource_amount(String(r)) < need:
			reasons.append("Need %d %s (have %d)" % [need, String(r), s.resource_amount(String(r))])
	return reasons


## Resources needed to bring an instance back to full condition.
static func repair_cost(instance: Dictionary, building_defs: Dictionary, settlement_balance: Dictionary) -> Dictionary:
	var missing := SettlementState.MAX_CONDITION - condition_of(instance)
	if missing <= 0:
		return {}
	var definition := DictUtil.get_dict(building_defs, DictUtil.get_string(instance, "definition_id"))
	var base := DictUtil.get_dict(level_spec(definition, level_of(instance)), "cost")
	if base.is_empty():
		base = DictUtil.get_dict(definition, "cost")
	var ratio := DictUtil.get_float(settlement_balance, "repair_cost_ratio", 0.5)
	var out := {}
	var total := 0
	for r in DictUtil.sorted_keys(base):
		var amount := int(ceil(DictUtil.get_int(base, String(r)) * ratio * float(missing) / float(SettlementState.MAX_CONDITION)))
		if amount > 0:
			out[r] = amount
			total += amount
	if total == 0 and not base.is_empty():
		out[DictUtil.sorted_keys(base)[0]] = 1
	return out


## Whole days a repair takes: proportional to how long the level took to build.
static func repair_days(instance: Dictionary, building_defs: Dictionary) -> int:
	var missing := SettlementState.MAX_CONDITION - condition_of(instance)
	var definition := DictUtil.get_dict(building_defs, DictUtil.get_string(instance, "definition_id"))
	var days := DictUtil.get_int(level_spec(definition, level_of(instance)), "days", 0)
	return int(ceil(days * float(missing) / float(SettlementState.MAX_CONDITION)))


static func repair_blocking_reasons(s: SettlementState, instance: Dictionary, building_defs: Dictionary, settlement_balance: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if instance.is_empty():
		reasons.append("Unknown building")
		return reasons
	if condition_of(instance) >= SettlementState.MAX_CONDITION:
		reasons.append("Nothing to repair")
		return reasons
	if not s.job_for_instance(DictUtil.get_string(instance, "instance_id")).is_empty():
		reasons.append("Work is already under way here")
	reasons.append_array(cost_blocking_reasons(s, repair_cost(instance, building_defs, settlement_balance)))
	return reasons


## Lowers (or with a negative amount raises) an instance's condition.
## Returns the new condition.
static func apply_damage(instance: Dictionary, amount: int) -> int:
	var value := clampi(condition_of(instance) - amount, 0, SettlementState.MAX_CONDITION)
	instance["condition"] = value
	return value
