class_name ThreatRules
extends RefCounted
## Enemy awareness and the expedition grace period.
##
## threat_state = {completed_expeditions, awareness (0..100), grace_period}
## Awareness only starts rising once completed_expeditions exceeds the grace
## period. No raids are implemented: awareness is information, not an attack.


static func init_state(grace_period: int) -> Dictionary:
	return {"completed_expeditions": 0, "awareness": 0, "grace_period": maxi(0, grace_period)}


## Call exactly once per resolved expedition (the caller guarantees that via
## ExpeditionRecord.resolved). Returns the awareness delta.
static func on_expedition_resolved(threat: Dictionary, building_count: int, threat_balance: Dictionary) -> int:
	threat["completed_expeditions"] = int(threat.get("completed_expeditions", 0)) + 1
	if int(threat["completed_expeditions"]) <= int(threat.get("grace_period", 5)):
		return 0
	var before := int(threat.get("awareness", 0))
	var delta := DictUtil.get_int(threat_balance, "awareness_per_expedition_after_grace", 8)
	delta += building_count * DictUtil.get_int(threat_balance, "awareness_per_building", 2)
	threat["awareness"] = clampi(before + delta, 0, 100)
	return int(threat["awareness"]) - before


static func expeditions_remaining_in_grace(threat: Dictionary) -> int:
	return maxi(0, int(threat.get("grace_period", 5)) - int(threat.get("completed_expeditions", 0)))


## Vague band for the player interface (the exact number stays hidden).
static func band(threat: Dictionary, threat_balance: Dictionary) -> Dictionary:
	var awareness := int(threat.get("awareness", 0))
	for b in DictUtil.get_array(threat_balance, "bands"):
		if awareness <= DictUtil.get_int(b, "max", 100):
			return b
	return {"label": "Unknown", "text": ""}
