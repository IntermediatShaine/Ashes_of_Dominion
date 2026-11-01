class_name DecisionRules
extends RefCounted
## Narrative decisions with persistent consequences. A decision resolves at
## most once per universe; its effects fan out to the separate morality,
## reputation, haul, settlement and protagonist-condition systems.
##
## Faction reactivity: an option may carry
##   requires_reputation: {faction, min?, max?, hide_when_blocked?}
## and a decision may carry
##   prompts_by_reputation: [{faction, min?, max?, text}, ...]
## Both read the universe's faction reputation only — never morality — so the
## two scales stay independent (reputation gates what a faction offers you;
## morality is what you did to earn it).


static func is_available(u: UniverseState, decision_id: String) -> bool:
	return not u.decision_log.has(decision_id)


## Picks the single decision NPC for an area: the unresolved decision whose
## appears_in_biomes contains the biome (and whose appears_at_landmarks, when
## present, contains the destination), lowest `priority` first, then id.
## Deterministic by construction: depends only on content + decision_log.
static func select_for_area(decisions: Dictionary, u: UniverseState, biome_id: String, landmark_id: String) -> String:
	var best := ""
	var best_priority := 0
	for did in DictUtil.sorted_keys(decisions):
		var d: Dictionary = decisions[did]
		if not is_available(u, String(did)):
			continue
		if not DictUtil.get_array(d, "appears_in_biomes").has(biome_id):
			continue
		var landmarks := DictUtil.get_array(d, "appears_at_landmarks")
		if not landmarks.is_empty() and not landmarks.has(landmark_id):
			continue
		var priority := DictUtil.get_int(d, "priority", 100)
		if best == "" or priority < best_priority:
			best = String(did)
			best_priority = priority
	return best


## True when the player's standing with the gate's faction is inside [min, max].
static func reputation_gate_passes(gate: Dictionary, u: UniverseState) -> bool:
	if gate.is_empty():
		return true
	var f := u.faction(DictUtil.get_string(gate, "faction"))
	if f == null:
		return false
	var rep := f.player_reputation
	if gate.has("min") and rep < DictUtil.get_int(gate, "min"):
		return false
	if gate.has("max") and rep > DictUtil.get_int(gate, "max"):
		return false
	return true


## The prompt text for the player's current standing, else the default prompt.
static func prompt_for(decision: Dictionary, u: UniverseState) -> String:
	for variant in DictUtil.get_array(decision, "prompts_by_reputation"):
		if variant is Dictionary and reputation_gate_passes(variant, u):
			return DictUtil.get_string(variant, "text")
	return DictUtil.get_string(decision, "prompt")


## Options the player should see: everything except gated options marked
## hide_when_blocked whose gate fails. Blocked-but-visible options are shown
## disabled with blocking_reason() so the player can tell what trust unlocks.
static func visible_options(decision: Dictionary, u: UniverseState) -> Dictionary:
	var out := {}
	var options := DictUtil.get_dict(decision, "options")
	for oid in DictUtil.sorted_keys(options):
		var opt: Dictionary = options[oid]
		var gate := DictUtil.get_dict(opt, "requires_reputation")
		if DictUtil.get_bool(gate, "hide_when_blocked", false) and not reputation_gate_passes(gate, u):
			continue
		out[oid] = opt
	return out


## Why an option cannot be chosen right now ("" when it can): pack contents
## first, then faction standing.
static func blocking_reason(option: Dictionary, expedition: ExpeditionRecord, u: UniverseState) -> String:
	var req := DictUtil.get_dict(option, "requires_haul")
	for r in DictUtil.sorted_keys(req):
		if int(expedition.haul.get(r, 0)) < DictUtil.get_int(req, String(r)):
			return "Needs %d %s in your pack" % [DictUtil.get_int(req, String(r)), String(r)]
	var gate := DictUtil.get_dict(option, "requires_reputation")
	if u != null and not gate.is_empty() and not reputation_gate_passes(gate, u):
		var f := u.faction(DictUtil.get_string(gate, "faction"))
		var standing := ReputationRules.label(f.player_reputation) if f != null else "unknown"
		if gate.has("min"):
			return "Needs %s standing of at least %s (you are %s)" % [_faction_name(gate, u), ReputationRules.label(DictUtil.get_int(gate, "min")), standing]
		return "Not while %s considers you %s" % [_faction_name(gate, u), standing]
	return ""


## Applies the chosen option. Returns OpResult with a summary of changes.
static func resolve(save: SaveGame, decision_id: String, decision: Dictionary, option_id: String) -> OpResult:
	var u := save.universe
	if not is_available(u, decision_id):
		return OpResult.failure("Decision %s already resolved" % decision_id)
	var options := DictUtil.get_dict(decision, "options")
	if not options.has(option_id):
		return OpResult.failure("Unknown option %s" % option_id)
	var option: Dictionary = options[option_id]
	var exp := u.active_expedition()
	if exp == null:
		return OpResult.failure("No active expedition for decision")
	var block := blocking_reason(option, exp, u)
	if block != "":
		return OpResult.failure(block)

	var effects := DictUtil.get_dict(option, "effects")
	var event_id := "%s:%s:%s" % [u.universe_id, decision_id, option_id]
	var summary := {"morality": 0, "reputation": {}, "haul": {}, "recruits": 0, "health": 0}
	u.decision_log[decision_id] = option_id

	summary["morality"] = MoralityRules.apply_event(save.character, event_id, decision_id, DictUtil.get_int(effects, "morality", 0), u.universe_id)
	var reps := DictUtil.get_dict(effects, "reputation")
	for fid in DictUtil.sorted_keys(reps):
		var f := u.faction(String(fid))
		if f != null:
			summary["reputation"][fid] = ReputationRules.apply_event(f, event_id, decision_id, DictUtil.get_int(reps, String(fid)), u.current_day)
	var haul := DictUtil.get_dict(effects, "haul")
	for r in DictUtil.sorted_keys(haul):
		exp.add_haul(String(r), DictUtil.get_int(haul, String(r)))
		summary["haul"][r] = DictUtil.get_int(haul, String(r))
	var recruits := DictUtil.get_int(effects, "recruits", 0)
	if recruits > 0:
		u.home_settlement().pending_recruits += recruits
		summary["recruits"] = recruits
	var health_delta := DictUtil.get_int(effects, "health", 0)
	if health_delta != 0:
		# A dialogue can wound or mend, never kill: death stays a combat outcome.
		var before := DictUtil.get_int(u.protagonist_condition, "health", 1)
		var after := maxi(1, before + health_delta)
		u.protagonist_condition["health"] = after
		summary["health"] = after - before
	exp.events.append({"kind": "decision", "decision_id": decision_id, "option": option_id})
	return OpResult.success(summary)


## Rules have no access to content tables, so the id is prettified ("Crown Of Aurel").
static func _faction_name(gate: Dictionary, _u: UniverseState) -> String:
	return DictUtil.get_string(gate, "faction").capitalize()
