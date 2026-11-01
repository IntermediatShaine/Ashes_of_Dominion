class_name ReputationRules
extends RefCounted
## Faction reputation (universe scope). A single action may affect several
## factions differently; it never changes morality.


## Starting reputation from ancestry attitudes:
##   primary attitude + (if mixed: secondary attitude * 0.5 + mixed penalty)
static func initial_reputation(c: CharacterState, faction_def: Dictionary) -> int:
	var attitudes := DictUtil.get_dict(faction_def, "ancestry_attitudes")
	var rep := DictUtil.get_int(attitudes, c.primary_ancestry, 0)
	if c.is_mixed_ancestry():
		rep += int(DictUtil.get_int(attitudes, c.secondary_ancestry, 0) * 0.5)
		rep += DictUtil.get_int(faction_def, "mixed_ancestry_penalty", 0)
	return clampi(rep, -100, 100)


## Applies a reputation change once per (faction, event id). Returns delta applied.
static func apply_event(f: FactionState, event_id: String, kind: String, delta: int, day: int) -> int:
	for e in f.reputation_log:
		if String(e.get("id", "")) == event_id:
			return 0
	var before := f.player_reputation
	f.player_reputation = clampi(f.player_reputation + delta, -100, 100)
	f.reputation_log.append({"id": event_id, "kind": kind, "delta": f.player_reputation - before, "day": day})
	return f.player_reputation - before


static func label(reputation: int) -> String:
	if reputation >= 60:
		return "Honoured"
	if reputation >= 20:
		return "Friendly"
	if reputation > -20:
		return "Neutral"
	if reputation > -60:
		return "Distrusted"
	return "Hunted"
