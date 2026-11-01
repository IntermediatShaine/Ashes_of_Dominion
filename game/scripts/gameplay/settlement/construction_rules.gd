class_name ConstructionRules
extends RefCounted
## Construction: validate -> check resources -> deduct -> apply, as one
## all-or-nothing operation. Nothing is mutated unless every check passes.


## Why a building cannot be built right now; empty means it can.
static func blocking_reasons(s: SettlementState, definition_id: String, building_defs: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if not building_defs.has(definition_id):
		reasons.append("Unknown building '%s'" % definition_id)
		return reasons
	var d: Dictionary = building_defs[definition_id]
	var max_count := DictUtil.get_int(d, "max_count", 1)
	if s.building_count(definition_id) >= max_count:
		reasons.append("Already built (max %d)" % max_count)
	for req in DictUtil.get_array(d, "requires"):
		if s.building_count(String(req)) == 0:
			var req_name := DictUtil.get_string(building_defs.get(String(req), {}), "name", String(req))
			reasons.append("Requires " + req_name)
	var cost := DictUtil.get_dict(d, "cost")
	for r in DictUtil.sorted_keys(cost):
		var need := DictUtil.get_int(cost, String(r))
		if s.resource_amount(String(r)) < need:
			reasons.append("Need %d %s (have %d)" % [need, String(r), s.resource_amount(String(r))])
	return reasons


## Performs construction. value = the new building instance dictionary.
static func build(s: SettlementState, definition_id: String, building_defs: Dictionary, id_counters: Dictionary, day: int) -> OpResult:
	var reasons := blocking_reasons(s, definition_id, building_defs)
	if not reasons.is_empty():
		return OpResult.failure("Cannot build %s: %s" % [definition_id, "; ".join(reasons)])
	var d: Dictionary = building_defs[definition_id]
	var cost := DictUtil.get_dict(d, "cost")
	for r in DictUtil.sorted_keys(cost):
		s.resources[r] = s.resource_amount(String(r)) - DictUtil.get_int(cost, String(r))
	var instance := {
		"instance_id": IdFactory.next_sequential(id_counters, "bld"),
		"definition_id": definition_id,
		"built_day": day,
	}
	s.buildings.append(instance)
	return OpResult.success(instance)
