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
			day_summary["settlements"][sid] = SettlementRules.tick_day(u.settlements[sid], building_defs, settlement_bal)
		out.append(day_summary)
	return out
