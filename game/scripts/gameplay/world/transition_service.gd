class_name TransitionService
extends RefCounted
## Death → resurrection → transition pipeline, split into explicit steps:
##
##   record_death()        -> death event id (universe scope, counted once)
##   resolve_resurrection()-> outcome stored in MultiverseState BEFORE use;
##                            a stored outcome is returned as-is (no reroll)
##   begin_transition()    -> pending record in MultiverseState
##   execute_transition()  -> applies effects idempotently, marks completed
##   recover_pending()     -> on load: finish any transition left pending
##
## Only one outcome kind exists today: "return_home" (the design document's
## established resurrection at the village). Universe transfer rules are not
## designed; the record format carries a `kind` so they can be added without
## changing the save schema, and the transfer counters are never touched here.

const KIND_RETURN_HOME := "return_home"
const TRANSITION_RESURRECTION := "resurrection_return"

var save: SaveGame
var expeditions: ExpeditionService


func _init(p_save: SaveGame, p_expeditions: ExpeditionService) -> void:
	save = p_save
	expeditions = p_expeditions


## Step 1: record the death event in universe state. Returns the event id.
func record_death(context: Dictionary = {}) -> String:
	var u := save.universe
	var id := IdFactory.next_sequential(u.id_counters, "death")
	u.death_count += 1
	u.world_events.append({"id": id, "kind": "protagonist_death", "day": u.current_day, "expedition_id": u.active_expedition_id, "context": context})
	return id


## Step 2: decide (once) what the curse does. Stored before it is applied.
func resolve_resurrection(death_event_id: String) -> Dictionary:
	var m := save.multiverse
	if m.resolved_resurrection_outcomes.has(death_event_id):
		return m.resolved_resurrection_outcomes[death_event_id]
	var outcome := {
		"kind": KIND_RETURN_HOME,
		"death_event_id": death_event_id,
		"universe_id": save.universe.universe_id,
		"day": save.universe.current_day,
		"transition_id": IdFactory.next_sequential(m.id_counters, "tr"),
	}
	m.resolved_resurrection_outcomes[death_event_id] = outcome
	return outcome


## Step 3: open an explicit transition record. Idempotent per transition id.
func begin_transition(outcome: Dictionary) -> Dictionary:
	var m := save.multiverse
	var tid: String = outcome["transition_id"]
	if m.has_completed_transition(tid):
		return {"transition_id": tid, "kind": TRANSITION_RESURRECTION, "status": "completed", "payload": outcome}
	if m.pending_transition is Dictionary and String(m.pending_transition.get("transition_id", "")) == tid:
		return m.pending_transition
	m.pending_transition = {"transition_id": tid, "kind": TRANSITION_RESURRECTION, "status": "pending", "payload": outcome.duplicate(true)}
	return m.pending_transition


## Step 4: apply the transition. Safe to call repeatedly.
func execute_transition(transition: Dictionary) -> OpResult:
	var m := save.multiverse
	var tid := String(transition.get("transition_id", ""))
	if tid == "":
		return OpResult.failure("Transition has no id")
	if m.has_completed_transition(tid):
		return OpResult.success({"already_completed": true})
	var kind := String(transition.get("kind", ""))
	var result := {}
	match kind:
		TRANSITION_RESURRECTION:
			# The expedition resolution is itself idempotent (resolved flag).
			var u := save.universe
			var exp := u.active_expedition()
			if exp != null:
				var r := expeditions.finish("defeated")
				if not r.ok:
					return r
				result = r.value
			else:
				# Expedition already resolved by an earlier, interrupted attempt.
				result = {"already_resolved": true}
			u.protagonist_condition["health"] = ProgressionRules.max_health(save.character, expeditions.content.balance("character"))
		_:
			return OpResult.failure("Unsupported transition kind " + kind)
	m.completed_transition_ids.append(tid)
	if m.pending_transition is Dictionary and String(m.pending_transition.get("transition_id", "")) == tid:
		m.pending_transition = null
	return OpResult.success(result)


## Full pipeline used by the exploration scene when the protagonist falls.
func on_protagonist_defeated(context: Dictionary = {}) -> OpResult:
	var death_id := record_death(context)
	var outcome := resolve_resurrection(death_id)
	var transition := begin_transition(outcome)
	var r := execute_transition(transition)
	if r.ok:
		r.value = {"death_event_id": death_id, "outcome": outcome, "result": r.value}
	return r


## Called after loading: completes a transition interrupted by a crash.
func recover_pending() -> OpResult:
	var m := save.multiverse
	if not (m.pending_transition is Dictionary):
		return OpResult.success({"recovered": false})
	var r := execute_transition(m.pending_transition)
	if r.ok:
		r.with_warning("Recovered an interrupted transition")
		r.value = {"recovered": true, "result": r.value}
	return r
