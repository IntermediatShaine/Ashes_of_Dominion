class_name WorldSimulation
extends RefCounted
## Controlled world tick. Runs only when the calendar advances (expedition
## resolution), never per rendered frame. Deterministic: given the same saved
## state and the same number of days, the same result follows. The "events"
## rng stream is reserved for future random world events; nothing here draws
## from any other stream.


## Advances `days` days. Returns an Array of per-day summaries.
static func advance_days(save: SaveGame, days: int, content) -> Array:
	var u := save.universe
	var out: Array = []
	var building_defs: Dictionary = content.table("buildings")
	var settlement_bal: Dictionary = content.balance("settlement")
	for i in maxi(0, days):
		u.current_day += 1
		var day_summary := {"day": u.current_day, "settlements": {}}
		for sid in DictUtil.sorted_keys(u.settlements):
			day_summary["settlements"][sid] = SettlementRules.tick_day(u.settlements[sid], building_defs, settlement_bal, u.current_day, personal_production(save, u.settlements[sid], content))
		out.append(day_summary)
	return out


## Installed tools use recipe-defined production and require their workshop.
## Only the home settlement benefits; previews and the tick share this calculation.
static func personal_production(save: SaveGame, settlement: SettlementState, content) -> Dictionary:
	var out := {}
	if settlement.settlement_id != save.universe.home_settlement_id:
		return out
	var tools := DictUtil.get_array(save.universe.protagonist_condition, "tools")
	for recipe in content.table("recipes").values():
		if not tools.has(DictUtil.get_string(recipe, "tool")):
			continue
		for building in settlement.buildings:
			if String(building["definition_id"]) == DictUtil.get_string(recipe, "requires") and BuildingRules.is_functional(building):
				for rid in DictUtil.get_dict(recipe, "production"):
					out[rid] = int(out.get(rid, 0)) + int(recipe["production"][rid])
				break
	return out
