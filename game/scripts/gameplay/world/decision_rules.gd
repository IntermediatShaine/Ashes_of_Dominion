class_name DecisionRules
extends RefCounted
## Narrative decisions with persistent consequences. A decision resolves at
## most once per universe; its effects fan out to the separate morality,
## reputation, haul and settlement systems.


static func is_available(u: UniverseState, decision_id: String) -> bool:
	return not u.decision_log.has(decision_id)


static func option_blocking_reason(option: Dictionary, expedition: ExpeditionRecord) -> String:
	var req := DictUtil.get_dict(option, "requires_haul")
	for r in DictUtil.sorted_keys(req):
		if int(expedition.haul.get(r, 0)) < DictUtil.get_int(req, String(r)):
			return "Needs %d %s in your pack" % [DictUtil.get_int(req, String(r)), String(r)]
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
	var block := option_blocking_reason(option, exp)
	if block != "":
		return OpResult.failure(block)

	var effects := DictUtil.get_dict(option, "effects")
	var event_id := "%s:%s:%s" % [u.universe_id, decision_id, option_id]
	var summary := {"morality": 0, "reputation": {}, "haul": {}, "recruits": 0}
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
	exp.events.append({"kind": "decision", "decision_id": decision_id, "option": option_id})
	return OpResult.success(summary)
