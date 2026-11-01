class_name MoralityRules
extends RefCounted
## Personal morality of the protagonist (character scope). Entirely separate
## from faction reputation: changing one never touches the other.


## Applies a morality event once. Events are keyed by id so a replayed scene
## cannot apply the same event twice. Returns the delta actually applied.
static func apply_event(c: CharacterState, event_id: String, kind: String, delta: int, universe_id: String) -> int:
	for e in c.morality_log:
		if String(e.get("id", "")) == event_id:
			return 0
	var before := c.morality
	c.morality = clampi(c.morality + delta, -100, 100)
	c.morality_log.append({"id": event_id, "kind": kind, "delta": c.morality - before, "universe_id": universe_id})
	return c.morality - before


static func label(morality: int) -> String:
	if morality >= 60:
		return "Virtuous"
	if morality >= 20:
		return "Decent"
	if morality > -20:
		return "Unaligned"
	if morality > -60:
		return "Ruthless"
	return "Monstrous"
