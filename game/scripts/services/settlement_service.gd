class_name SettlementService
extends RefCounted
## The one door to the home settlement.
##
## The settlement's changing values live in SettlementState (plus the universe
## clock and threat state); its static description lives in data/. This
## service is how everything else touches them:
##
##   read    snapshot(), inspect_site(), inspect_building()  -> fresh copies;
##           changing a returned dictionary changes nothing
##   check   validate_construction / validate_upgrade / validate_repair
##           -> the reasons a request would be refused (empty = allowed)
##   change  request_construction / request_upgrade / request_repair /
##           cancel_job / assign_worker / unassign_worker / advance_time /
##           damage_building -> OpResult; rules are applied all-or-nothing
##   listen  the signals below fire after a change has been applied
##
## UI and village objects call these methods and redraw from snapshots; they
## never write SettlementState and never keep their own copy of its values.
## The service holds no state of its own, so a new instance bound to the same
## save behaves identically (Session creates one per loaded game:
## `Session.settlement_service`). Rules live in scripts/gameplay/settlement/.

## Something about the settlement changed. `reason` is a short tag
## ("construction", "upgrade", "repair", "job_cancelled", "workers", "time",
## "damage", "resources", "normalized"). Views that show a whole snapshot only
## need this one.
signal settlement_changed(reason: String)
signal resources_changed(resources: Dictionary)
## A site's building appeared, changed level or condition. `instance_id` is ""
## while a first build is still under construction.
signal building_changed(site_id: String, instance_id: String)
## status: "started" | "progressed" | "completed" | "cancelled"
signal job_changed(job_id: String, status: String)
signal population_changed(population: int)
signal worker_assignment_changed(resident_id: String, target_id: String)
signal time_advanced(day: int, minute_of_day: int)
## Every entry appended to the persistent settlement event log.
signal event_recorded(event: Dictionary)

const ACTION_BUILD := "build"
const ACTION_UPGRADE := "upgrade"
const ACTION_REPAIR := "repair"

var save: SaveGame
var content
var settlement_id: String = ""


## `p_content` is the Content autoload or anything exposing table()/balance().
func _init(p_save: SaveGame, p_content, p_settlement_id: String = "") -> void:
	save = p_save
	content = p_content
	settlement_id = p_settlement_id if p_settlement_id != "" else p_save.universe.home_settlement_id


# --- access to the authoritative data (not copies; for rules, not for views) ---

func universe() -> UniverseState:
	return save.universe


func state() -> SettlementState:
	return save.universe.settlements.get(settlement_id)


func layout() -> Dictionary:
	return DictUtil.get_dict(content.table("village_layouts"), settlement_id)


func building_defs() -> Dictionary:
	return content.table("buildings")


func balance() -> Dictionary:
	return content.balance("settlement")


func site_ids() -> Array[String]:
	return SiteRules.site_ids(layout())


# --- read-only views -------------------------------------------------------------

## Everything a view needs about the settlement, as a fresh deep copy.
func snapshot() -> Dictionary:
	var s := state()
	var u := universe()
	var defs := building_defs()
	var residents: Array = []
	for r in s.residents:
		residents.append(_resident_view(r))
	var sites: Array = []
	for site_id in site_ids():
		sites.append(inspect_site(site_id))
	var unplaced: Array = []
	for b in s.buildings:
		if DictUtil.get_string(b, "site_id") == "":
			unplaced.append(inspect_building(DictUtil.get_string(b, "instance_id")))
	var jobs: Array = []
	for j in s.construction_jobs:
		jobs.append(_job_view(j))
	var band := ThreatRules.band(u.threat_state, content.balance("threat"))
	return {
		"settlement_id": s.settlement_id,
		"name": s.display_name,
		"map_id": DictUtil.get_string(layout(), "map_id"),
		"time": time_view(),
		"resources": s.resources.duplicate(),
		"storage_capacity": SettlementRules.storage_capacity(s, defs),
		"population": {
			"count": s.population,
			"capacity": SettlementRules.population_capacity(s, defs),
			"pending_recruits": s.pending_recruits,
			"idle": s.workers_assigned_to_none().size(),
			"residents": residents,
		},
		"stats": {
			"loyalty": s.loyalty,
			"morale": s.morale,
			"productivity": s.productivity,
			"freedom": s.freedom,
			"discipline": s.discipline,
			"military_strength": SettlementRules.military_strength(s, defs),
		},
		"production": SettlementRules.daily_production(s, defs),
		"threat": {
			"awareness": DictUtil.get_int(u.threat_state, "awareness"),
			"label": DictUtil.get_string(band, "label"),
			"text": DictUtil.get_string(band, "text"),
			"grace_remaining": ThreatRules.expeditions_remaining_in_grace(u.threat_state),
		},
		"sites": sites,
		"unplaced_buildings": unplaced,
		"jobs": jobs,
		"events": s.events.duplicate(true),
	}


## The universe clock as the settlement sees it: {day, minute_of_day, clock}.
func time_view() -> Dictionary:
	var u := universe()
	return {
		"day": u.current_day,
		"minute_of_day": u.time_of_day_minutes,
		"clock": "%02d:%02d" % [int(u.time_of_day_minutes / 60.0), u.time_of_day_minutes % 60],
	}


## What stands (or could stand) on a building site:
##   {site_id, kind, role, state, definition_id, name, category, description,
##    instance_id, level, max_level, condition, condition_label, functional,
##    built_day, effects, worker_slots, workers:[{resident_id, name}],
##    job:{} | {job_id, kind, target_level, work_done, work_required,
##    work_per_day, builders:[{resident_id, name}]},
##    improvements:[{action, definition_id, name, description, target_level,
##    cost, days, effects, blocked_by:[String], available}]}
## {} for an unknown site.
func inspect_site(site_id: String) -> Dictionary:
	var site_def := SiteRules.site(layout(), site_id)
	if site_def.is_empty():
		return {}
	return _inspection(site_def, state().building_at_site(site_id))


## Same shape as inspect_site, addressed by building instance (also works for
## a building that has no site). {} for an unknown instance.
func inspect_building(instance_id: String) -> Dictionary:
	var instance := state().building_by_id(instance_id)
	if instance.is_empty():
		return {}
	return _inspection(SiteRules.site(layout(), DictUtil.get_string(instance, "site_id")), instance)


## The improvements currently offered at a site (see inspect_site).
func available_improvements(site_id: String) -> Array:
	return DictUtil.get_array(inspect_site(site_id), "improvements")


# --- validation --------------------------------------------------------------------

func validate_construction(site_id: String, definition_id: String) -> Array[String]:
	return ConstructionJobRules.build_blocking_reasons(state(), layout(), site_id, definition_id, building_defs())


func validate_upgrade(instance_id: String) -> Array[String]:
	return BuildingRules.upgrade_blocking_reasons(state(), state().building_by_id(instance_id), building_defs())


func validate_repair(instance_id: String) -> Array[String]:
	return BuildingRules.repair_blocking_reasons(state(), state().building_by_id(instance_id), building_defs(), balance())


func validate_worker_assignment(resident_id: String, target_id: String) -> Array[String]:
	return PopulationRules.assign_blocking_reasons(state(), resident_id, target_id, building_defs(), balance())


# --- construction requests ---------------------------------------------------------

## Build `definition_id` on a site. value = {completed, instance, job}:
## `completed` is true when the building stands at once (0 build days),
## otherwise `job` is the construction job that was started.
func request_construction(site_id: String, definition_id: String) -> OpResult:
	var before := _event_mark()
	var r := ConstructionJobRules.start_build(state(), layout(), site_id, definition_id, building_defs(), universe().id_counters, universe().current_day, balance())
	if r.ok:
		_after_request(r, site_id, "construction", before)
	return r


## Build `definition_id` wherever it belongs: its reserved site if free, else
## the first free plot. Fails when there is no site for it.
func request_construction_anywhere(definition_id: String) -> OpResult:
	var defs := building_defs()
	var site_id := SiteRules.find_site_for(state(), layout(), definition_id, defs)
	if site_id == "":
		# Report the definition-level reasons first; they are the useful ones.
		var reasons := ConstructionRules.blocking_reasons(state(), definition_id, defs)
		if reasons.is_empty():
			reasons.append("No free building site")
		return OpResult.failure("Cannot build %s: %s" % [definition_id, "; ".join(reasons)])
	return request_construction(site_id, definition_id)


func request_upgrade(instance_id: String) -> OpResult:
	var before := _event_mark()
	var r := ConstructionJobRules.start_upgrade(state(), instance_id, building_defs(), universe().current_day, balance())
	if r.ok:
		_after_request(r, DictUtil.get_string(state().building_by_id(instance_id), "site_id"), "upgrade", before)
	return r


func request_repair(instance_id: String) -> OpResult:
	var before := _event_mark()
	var r := ConstructionJobRules.start_repair(state(), instance_id, building_defs(), universe().current_day, balance())
	if r.ok:
		_after_request(r, DictUtil.get_string(state().building_by_id(instance_id), "site_id"), "repair", before)
	return r


## Carries out one entry of a site's `improvements` list (what the UI offers).
func request_improvement(site_id: String, action: String, definition_id: String = "") -> OpResult:
	var instance := state().building_at_site(site_id)
	match action:
		ACTION_BUILD:
			var target := definition_id
			if target == "":
				var allowed := SiteRules.allowed_definitions(layout(), site_id, building_defs())
				if allowed.size() != 1:
					return OpResult.failure("Choose what to build on " + site_id)
				target = allowed[0]
			return request_construction(site_id, target)
		ACTION_UPGRADE:
			if instance.is_empty():
				return OpResult.failure("Nothing to upgrade on " + site_id)
			return request_upgrade(DictUtil.get_string(instance, "instance_id"))
		ACTION_REPAIR:
			if instance.is_empty():
				return OpResult.failure("Nothing to repair on " + site_id)
			return request_repair(DictUtil.get_string(instance, "instance_id"))
	return OpResult.failure("Unknown improvement '%s'" % action)


## Abandon a construction job. value = {job, refund}.
func cancel_job(job_id: String) -> OpResult:
	var before := _event_mark()
	var site_id := DictUtil.get_string(state().job_by_id(job_id), "site_id")
	var r := ConstructionJobRules.cancel(state(), job_id, universe().current_day, balance())
	if not r.ok:
		return r
	_emit_events_since(before)
	job_changed.emit(job_id, "cancelled")
	resources_changed.emit(state().resources.duplicate())
	if site_id != "":
		building_changed.emit(site_id, DictUtil.get_string(state().building_at_site(site_id), "instance_id"))
	settlement_changed.emit("job_cancelled")
	return r


# --- workers -----------------------------------------------------------------------

## Put a resident to work at a building (instance id) or on a construction
## job (job id). Moves them if they already work elsewhere.
func assign_worker(resident_id: String, target_id: String) -> OpResult:
	var before := _event_mark()
	var r := PopulationRules.assign(state(), resident_id, target_id, building_defs(), balance(), universe().current_day)
	if r.ok:
		_emit_events_since(before)
		worker_assignment_changed.emit(resident_id, target_id)
		settlement_changed.emit("workers")
	return r


func unassign_worker(resident_id: String) -> OpResult:
	var before := _event_mark()
	var r := PopulationRules.unassign(state(), resident_id, balance(), universe().current_day)
	if r.ok:
		_emit_events_since(before)
		worker_assignment_changed.emit(resident_id, "")
		settlement_changed.emit("workers")
	return r


## Assigns the first idle resident (roster order) to a target.
func assign_idle_worker(target_id: String) -> OpResult:
	var idle := state().workers_assigned_to_none()
	if idle.is_empty():
		return OpResult.failure("Nobody is idle")
	return assign_worker(idle[0], target_id)


## Frees the most recently listed worker of a target.
func unassign_one_worker(target_id: String) -> OpResult:
	var workers := state().workers_assigned_to(target_id)
	if workers.is_empty():
		return OpResult.failure("Nobody works there")
	return unassign_worker(workers[workers.size() - 1])


# --- simulation --------------------------------------------------------------------

## Advances the in-game clock. Each midnight crossed runs one world-simulation
## day (production, food, construction work — the same tick expeditions use).
## Returns {minutes, days_passed, sim: [per-day summaries], recruits}.
func advance_time(minutes: int) -> Dictionary:
	var u := universe()
	var out := {"minutes": maxi(0, minutes), "days_passed": 0, "sim": [], "recruits": 0}
	if minutes <= 0:
		return out
	var before := _event_mark()
	var jobs_before := _job_ids()
	var total := u.time_of_day_minutes + minutes
	var days := int(total / float(UniverseState.MINUTES_PER_DAY))
	u.time_of_day_minutes = total % UniverseState.MINUTES_PER_DAY
	if days > 0:
		out["days_passed"] = days
		out["sim"] = WorldSimulation.advance_days(save, days, content)
		_on_days_advanced(out, jobs_before)
	_emit_events_since(before)
	time_advanced.emit(u.current_day, u.time_of_day_minutes)
	settlement_changed.emit("time")
	return out


## Advances to the next occurrence of `minute_of_day` (always forward, so
## asking for the current minute skips a whole day).
func advance_to_minute(minute_of_day: int) -> Dictionary:
	var target := clampi(minute_of_day, 0, UniverseState.MINUTES_PER_DAY - 1)
	var delta := target - universe().time_of_day_minutes
	if delta <= 0:
		delta += UniverseState.MINUTES_PER_DAY
	return advance_time(delta)


## Rest until the next dawn (balance.json -> time.dawn_minute).
func rest_until_dawn() -> Dictionary:
	return advance_to_minute(DictUtil.get_int(content.balance("time"), "dawn_minute", 360))


## Damages (amount > 0) or mends (amount < 0) a building outside the normal
## repair flow — for raids, events and tests. value = the new condition.
func damage_building(instance_id: String, amount: int, cause: String = "") -> OpResult:
	var instance := state().building_by_id(instance_id)
	if instance.is_empty():
		return OpResult.failure("Unknown building " + instance_id)
	var before := _event_mark()
	var condition := BuildingRules.apply_damage(instance, amount)
	state().record_event("building_damaged", universe().current_day, {"instance_id": instance_id, "amount": amount, "condition": condition, "cause": cause}, universe().time_of_day_minutes, _event_limit())
	var released := PopulationRules.release_invalid(state(), building_defs())
	_emit_events_since(before)
	for resident_id in released:
		worker_assignment_changed.emit(resident_id, "")
	building_changed.emit(DictUtil.get_string(instance, "site_id"), instance_id)
	settlement_changed.emit("damage")
	return OpResult.success(condition)


## Adds resources to storage (respecting the storage cap). Returns
## {added, lost} like SettlementRules.add_resources.
func add_resources(amounts: Dictionary) -> Dictionary:
	var result := SettlementRules.add_resources(state(), amounts, building_defs(), balance())
	resources_changed.emit(state().resources.duplicate())
	settlement_changed.emit("resources")
	return result


## Brings a loaded state in line with the current content: names residents
## that have none, gives unplaced buildings a free site, drops assignments
## that are no longer possible. Deterministic and idempotent; Session calls it
## once after binding a save (it is what finishes a migration from the
## pre-village save format). Returns {named, placed, released}.
func normalize() -> Dictionary:
	var s := state()
	var out := {"named": 0, "placed": 0, "released": 0}
	if s == null:
		return out
	out["named"] = PopulationRules.ensure_names(s, PopulationRules.name_pool(content), universe().world_seed)
	out["placed"] = SiteRules.place_unplaced(s, layout(), building_defs())
	out["released"] = PopulationRules.release_invalid(s, building_defs()).size()
	if int(out["named"]) + int(out["placed"]) + int(out["released"]) > 0:
		settlement_changed.emit("normalized")
	return out


# --- internals ---------------------------------------------------------------------

func _inspection(site_def: Dictionary, instance: Dictionary) -> Dictionary:
	var s := state()
	var defs := building_defs()
	var bal := balance()
	var site_id := DictUtil.get_string(site_def, "id")
	var kind := DictUtil.get_string(site_def, "kind")
	var job := s.job_at_site(site_id) if site_id != "" else s.job_for_instance(DictUtil.get_string(instance, "instance_id"))
	var definition_id := DictUtil.get_string(instance, "definition_id")
	if definition_id == "" and not job.is_empty():
		definition_id = DictUtil.get_string(job, "definition_id")
	if definition_id == "" and kind == SiteRules.KIND_CORE:
		definition_id = DictUtil.get_string(site_def, "reserved_for")
	var definition := DictUtil.get_dict(defs, definition_id)
	var site_state := SiteRules.state(s, layout(), site_id) if site_id != "" else (SiteRules.STATE_STANDING if BuildingRules.is_functional(instance) else SiteRules.STATE_DESTROYED)
	var has_building := not instance.is_empty()
	var level := BuildingRules.level_of(instance) if has_building else 0
	var condition := BuildingRules.condition_of(instance) if has_building else 0
	var workers: Array = []
	if has_building:
		for resident_id in s.workers_assigned_to(DictUtil.get_string(instance, "instance_id")):
			workers.append({"resident_id": resident_id, "name": DictUtil.get_string(s.resident_by_id(resident_id), "name")})
	var display_name := DictUtil.get_string(definition, "name", definition_id)
	if definition_id == "":
		display_name = "Empty plot"
	return {
		"site_id": site_id,
		"kind": kind,
		"role": DictUtil.get_string(site_def, "role"),
		"state": site_state,
		"definition_id": definition_id,
		"name": display_name,
		"category": DictUtil.get_string(definition, "category"),
		"description": DictUtil.get_string(definition, "description", "Cleared ground, staked out for building." if definition_id == "" else ""),
		"instance_id": DictUtil.get_string(instance, "instance_id"),
		"level": level,
		"max_level": BuildingRules.max_level(definition) if not definition.is_empty() else 0,
		"condition": condition,
		"condition_label": BuildingRules.condition_label(condition, DictUtil.get_array(bal, "condition_bands")),
		"functional": has_building and BuildingRules.is_functional(instance),
		"built_day": DictUtil.get_int(instance, "built_day") if has_building else 0,
		"effects": BuildingRules.effects_for(instance, defs).duplicate(true) if has_building else {},
		"worker_slots": BuildingRules.worker_slots(instance, defs) if has_building else 0,
		"workers": workers,
		"job": _job_view(job) if not job.is_empty() else {},
		"improvements": _improvements(site_def, instance, job),
	}


func _improvements(site_def: Dictionary, instance: Dictionary, job: Dictionary) -> Array:
	var s := state()
	var defs := building_defs()
	var out: Array = []
	var site_id := DictUtil.get_string(site_def, "id")
	if instance.is_empty():
		if not job.is_empty() or site_id == "":
			return out
		for allowed_id in SiteRules.allowed_definitions(layout(), site_id, defs):
			var allowed_def: Dictionary = defs[allowed_id]
			var build_spec := BuildingRules.level_spec(allowed_def, 1)
			var blocked := ConstructionJobRules.build_blocking_reasons(s, layout(), site_id, allowed_id, defs)
			out.append(_improvement(ACTION_BUILD, allowed_id, allowed_def, 1, DictUtil.get_dict(build_spec, "cost"), DictUtil.get_int(build_spec, "days"), DictUtil.get_dict(build_spec, "effects"), blocked))
		return out
	var definition_id := DictUtil.get_string(instance, "definition_id")
	var definition := DictUtil.get_dict(defs, definition_id)
	var level := BuildingRules.level_of(instance)
	if level < BuildingRules.max_level(definition):
		var spec := BuildingRules.level_spec(definition, level + 1)
		out.append(_improvement(ACTION_UPGRADE, definition_id, definition, level + 1, DictUtil.get_dict(spec, "cost"), DictUtil.get_int(spec, "days"), DictUtil.get_dict(spec, "effects"), BuildingRules.upgrade_blocking_reasons(s, instance, defs)))
	if BuildingRules.condition_of(instance) < SettlementState.MAX_CONDITION:
		out.append(_improvement(ACTION_REPAIR, definition_id, definition, level, BuildingRules.repair_cost(instance, defs, balance()), BuildingRules.repair_days(instance, defs), DictUtil.get_dict(BuildingRules.level_spec(definition, level), "effects"), BuildingRules.repair_blocking_reasons(s, instance, defs, balance())))
	return out


func _improvement(action: String, definition_id: String, definition: Dictionary, target_level: int, cost: Dictionary, days: int, effects: Dictionary, blocked_by: Array[String]) -> Dictionary:
	return {
		"action": action,
		"definition_id": definition_id,
		"name": DictUtil.get_string(definition, "name", definition_id),
		"description": DictUtil.get_string(definition, "description"),
		"target_level": target_level,
		"cost": DictUtil.int_map(cost),
		"days": days,
		"effects": effects.duplicate(true),
		"blocked_by": blocked_by.duplicate(),
		"available": blocked_by.is_empty(),
	}


func _job_view(job: Dictionary) -> Dictionary:
	var s := state()
	var builders: Array = []
	for resident_id in s.workers_assigned_to(DictUtil.get_string(job, "job_id")):
		builders.append({"resident_id": resident_id, "name": DictUtil.get_string(s.resident_by_id(resident_id), "name")})
	var out: Dictionary = job.duplicate(true)
	out["name"] = DictUtil.get_string(DictUtil.get_dict(building_defs(), DictUtil.get_string(job, "definition_id")), "name", DictUtil.get_string(job, "definition_id"))
	out["work_per_day"] = ConstructionJobRules.work_per_day(s, job, balance())
	out["builders"] = builders
	return out


func _resident_view(resident: Dictionary) -> Dictionary:
	var s := state()
	var out: Dictionary = resident.duplicate(true)
	var target := DictUtil.get_string(resident, "assigned_to")
	var label := "Idle"
	if target != "":
		var building := s.building_by_id(target)
		if not building.is_empty():
			label = DictUtil.get_string(DictUtil.get_dict(building_defs(), DictUtil.get_string(building, "definition_id")), "name", target)
		else:
			var job := s.job_by_id(target)
			label = "Building: " + DictUtil.get_string(DictUtil.get_dict(building_defs(), DictUtil.get_string(job, "definition_id")), "name", target)
	out["assignment_label"] = label
	return out


## Shared tail of the three construction requests.
func _after_request(r: OpResult, site_id: String, reason: String, event_mark: int) -> void:
	var value: Dictionary = r.value
	var completed := DictUtil.get_bool(value, "completed", false)
	var instance_id := DictUtil.get_string(DictUtil.get_dict(value, "instance"), "instance_id")
	if completed:
		_settle_arrivals()
	_emit_events_since(event_mark)
	resources_changed.emit(state().resources.duplicate())
	if not completed:
		job_changed.emit(DictUtil.get_string(DictUtil.get_dict(value, "job"), "job_id"), "started")
	building_changed.emit(site_id, instance_id)
	settlement_changed.emit(reason)


func _on_days_advanced(out: Dictionary, jobs_before: Array[String]) -> void:
	out["recruits"] = _settle_arrivals()
	resources_changed.emit(state().resources.duplicate())
	var jobs_now := _job_ids()
	for day_summary in DictUtil.get_array(out, "sim"):
		var mine := DictUtil.get_dict(DictUtil.get_dict(day_summary, "settlements"), settlement_id)
		for job in DictUtil.get_array(mine, "jobs_completed"):
			job_changed.emit(DictUtil.get_string(job, "job_id"), "completed")
			building_changed.emit(DictUtil.get_string(job, "site_id"), DictUtil.get_string(job, "instance_id"))
	for job_id in jobs_before:
		if jobs_now.has(job_id):
			job_changed.emit(job_id, "progressed")


## New housing lets waiting recruits move in; newcomers get their names.
func _settle_arrivals() -> int:
	var s := state()
	var moved := SettlementRules.settle_recruits(s, building_defs(), universe().current_day)
	PopulationRules.ensure_names(s, PopulationRules.name_pool(content), universe().world_seed)
	if moved > 0:
		for i in moved:
			var resident: Dictionary = s.residents[s.residents.size() - moved + i]
			s.record_event("resident_joined", universe().current_day, {"resident_id": DictUtil.get_string(resident, "resident_id"), "origin": DictUtil.get_string(resident, "origin")}, universe().time_of_day_minutes, _event_limit())
		population_changed.emit(s.population)
	return moved


func _job_ids() -> Array[String]:
	var out: Array[String] = []
	for j in state().construction_jobs:
		out.append(DictUtil.get_string(j, "job_id"))
	return out


func _event_limit() -> int:
	return DictUtil.get_int(balance(), "event_log_limit", 0)


## The settlement's event counter before an operation; with
## _emit_events_since it turns "what the rules logged" into signals.
func _event_mark() -> int:
	return state().event_counter


func _emit_events_since(mark: int) -> void:
	var s := state()
	var added := s.event_counter - mark
	if added <= 0:
		return
	var first := maxi(0, s.events.size() - added)
	for i in range(first, s.events.size()):
		event_recorded.emit((s.events[i] as Dictionary).duplicate(true))
