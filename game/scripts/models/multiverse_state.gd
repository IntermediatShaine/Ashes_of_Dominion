class_name MultiverseState
extends RefCounted
## State that spans universe replacement.
##
## Transfer rules (natural/forced) are NOT designed yet, so the counters exist
## but nothing increments them. Resurrection outcomes are recorded here keyed
## by death-event id so that a reload can never reroll them; transitions are
## explicit records with a pending/completed status so a crash mid-transition
## is recoverable without double application.

var natural_transfer_count: int = 0
var forced_transfer_count: int = 0
## death_event_id -> outcome dictionary ({kind, transition_id, universe_id, day})
var resolved_resurrection_outcomes: Dictionary = {}
## null, or {transition_id, kind, status, payload}
var pending_transition: Variant = null
var completed_transition_ids: Array[String] = []
var persistent_multiverse_flags: Dictionary = {}
var universe_counter: int = 0
var id_counters: Dictionary = {}


func has_completed_transition(transition_id: String) -> bool:
	return completed_transition_ids.has(transition_id)


func to_dict() -> Dictionary:
	return {
		"natural_transfer_count": natural_transfer_count,
		"forced_transfer_count": forced_transfer_count,
		"resolved_resurrection_outcomes": resolved_resurrection_outcomes.duplicate(true),
		"pending_transition": pending_transition.duplicate(true) if pending_transition is Dictionary else null,
		"completed_transition_ids": completed_transition_ids.duplicate(),
		"persistent_multiverse_flags": persistent_multiverse_flags.duplicate(true),
		"universe_counter": universe_counter,
		"id_counters": id_counters.duplicate(),
	}


static func from_dict(d: Dictionary) -> MultiverseState:
	var m := MultiverseState.new()
	m.natural_transfer_count = DictUtil.get_int(d, "natural_transfer_count")
	m.forced_transfer_count = DictUtil.get_int(d, "forced_transfer_count")
	m.resolved_resurrection_outcomes = DictUtil.get_dict(d, "resolved_resurrection_outcomes").duplicate(true)
	var pt = d.get("pending_transition", null)
	m.pending_transition = pt.duplicate(true) if pt is Dictionary else null
	m.completed_transition_ids = DictUtil.string_array(DictUtil.get_array(d, "completed_transition_ids"))
	m.persistent_multiverse_flags = DictUtil.get_dict(d, "persistent_multiverse_flags").duplicate(true)
	m.universe_counter = DictUtil.get_int(d, "universe_counter")
	m.id_counters = DictUtil.int_map(DictUtil.get_dict(d, "id_counters"))
	return m


func validate() -> Array[String]:
	var errors: Array[String] = []
	if natural_transfer_count < 0 or forced_transfer_count < 0:
		errors.append("transfer counts must be >= 0")
	if universe_counter < 1:
		errors.append("universe_counter must be >= 1")
	if pending_transition is Dictionary:
		var pt: Dictionary = pending_transition
		if String(pt.get("transition_id", "")) == "" or String(pt.get("kind", "")) == "":
			errors.append("pending_transition is malformed")
		elif completed_transition_ids.has(String(pt.get("transition_id"))):
			errors.append("pending_transition is already listed as completed")
	for k in resolved_resurrection_outcomes.keys():
		if not (resolved_resurrection_outcomes[k] is Dictionary):
			errors.append("malformed resurrection outcome for " + String(k))
	return errors
