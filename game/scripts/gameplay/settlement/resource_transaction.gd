class_name ResourceTransaction
extends RefCounted
## Validate the entire transaction before mutating any stock. Integer units only.

static func validate_amounts(amounts: Dictionary, definitions: Dictionary) -> String:
	for id in amounts:
		var n = amounts[id]
		if not definitions.has(id) or not (n is int or n is float):
			return "Unknown resource or invalid amount: " + str(id)
		if not is_finite(float(n)) or float(n) < 0 or float(n) != floor(float(n)):
			return "Resource amounts must be nonnegative whole units"
	return ""

static func spend(s: SettlementState, cost: Dictionary, definitions: Dictionary) -> OpResult:
	var error := validate_amounts(cost, definitions)
	if error != "":
		return OpResult.failure(error)
	for id in cost:
		if s.resource_amount(id) < int(cost[id]):
			return OpResult.failure("Not enough " + str(id))
	for id in cost:
		s.resources[id] = s.resource_amount(id) - int(cost[id])
	return OpResult.success(cost.duplicate())
