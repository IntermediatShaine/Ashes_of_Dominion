class_name ConstructionJobRules
extends RefCounted
## Construction, upgrade and repair requests and the jobs they create.
##
## Every request is all-or-nothing: validate -> deduct the cost -> either
## finish at once (0 days of work) or append a job to
## SettlementState.construction_jobs. Jobs advance in the daily settlement tick
## (SettlementRules.tick_day), so they also progress while the protagonist is
## away on an expedition. No randomness anywhere: the same state and the same
## number of days always give the same result.
##
## A build job reserves its building instance id when it is created, so
## finishing it needs no id counter and cannot collide.


static func start_build(s: SettlementState, layout: Dictionary, site_id: String, definition_id: String, building_defs: Dictionary, id_counters: Dictionary, day: int, settlement_balance: Dictionary) -> OpResult:
	var reasons := build_blocking_reasons(s, layout, site_id, definition_id, building_defs)
	if not reasons.is_empty():
		return OpResult.failure("Cannot build %s: %s" % [definition_id, "; ".join(reasons)])
	var definition: Dictionary = building_defs[definition_id]
	var spec := BuildingRules.level_spec(definition, 1)
	var cost := DictUtil.int_map(DictUtil.get_dict(spec, "cost"))
	_spend(s, cost)
	var instance_id := IdFactory.next_sequential(id_counters, "bld")
	var days := DictUtil.get_int(spec, "days", 0)
	var limit := DictUtil.get_int(settlement_balance, "event_log_limit", 0)
	if days <= 0:
		var instance := SettlementState.make_building_instance(instance_id, definition_id, day, site_id)
		s.buildings.append(instance)
		s.record_event("building_constructed", day, {"instance_id": instance_id, "definition_id": definition_id, "site_id": site_id, "level": 1}, 0, limit)
		return OpResult.success({"completed": true, "instance": instance, "job": {}})
	var job := _new_job(s, SettlementState.JOB_BUILD, definition_id, site_id, instance_id, 1, days, day, cost)
	s.record_event("job_started", day, _job_event_data(job), 0, limit)
	return OpResult.success({"completed": false, "instance": {}, "job": job})


## Site + definition checks for a new building; empty means it can be built.
static func build_blocking_reasons(s: SettlementState, layout: Dictionary, site_id: String, definition_id: String, building_defs: Dictionary) -> Array[String]:
	var reasons := SiteRules.placement_blocking_reasons(s, layout, site_id, definition_id, building_defs)
	for reason in ConstructionRules.blocking_reasons(s, definition_id, building_defs):
		if not reasons.has(reason):
			reasons.append(reason)
	return reasons


static func start_upgrade(s: SettlementState, instance_id: String, building_defs: Dictionary, day: int, settlement_balance: Dictionary) -> OpResult:
	var instance := s.building_by_id(instance_id)
	var reasons := BuildingRules.upgrade_blocking_reasons(s, instance, building_defs)
	if not reasons.is_empty():
		return OpResult.failure("Cannot upgrade %s: %s" % [instance_id, "; ".join(reasons)])
	var definition_id := DictUtil.get_string(instance, "definition_id")
	var target_level := BuildingRules.level_of(instance) + 1
	var spec := BuildingRules.level_spec(building_defs[definition_id], target_level)
	var cost := DictUtil.int_map(DictUtil.get_dict(spec, "cost"))
	_spend(s, cost)
	var days := DictUtil.get_int(spec, "days", 0)
	var limit := DictUtil.get_int(settlement_balance, "event_log_limit", 0)
	var site_id := DictUtil.get_string(instance, "site_id")
	if days <= 0:
		_apply_upgrade(s, instance, target_level, day, limit)
		return OpResult.success({"completed": true, "instance": instance, "job": {}})
	var job := _new_job(s, SettlementState.JOB_UPGRADE, definition_id, site_id, instance_id, target_level, days, day, cost)
	s.record_event("job_started", day, _job_event_data(job), 0, limit)
	return OpResult.success({"completed": false, "instance": instance, "job": job})


static func start_repair(s: SettlementState, instance_id: String, building_defs: Dictionary, day: int, settlement_balance: Dictionary) -> OpResult:
	var instance := s.building_by_id(instance_id)
	var reasons := BuildingRules.repair_blocking_reasons(s, instance, building_defs, settlement_balance)
	if not reasons.is_empty():
		return OpResult.failure("Cannot repair %s: %s" % [instance_id, "; ".join(reasons)])
	var cost := DictUtil.int_map(BuildingRules.repair_cost(instance, building_defs, settlement_balance))
	_spend(s, cost)
	var days := BuildingRules.repair_days(instance, building_defs)
	var limit := DictUtil.get_int(settlement_balance, "event_log_limit", 0)
	if days <= 0:
		_apply_repair(s, instance, day, limit)
		return OpResult.success({"completed": true, "instance": instance, "job": {}})
	var job := _new_job(s, SettlementState.JOB_REPAIR, DictUtil.get_string(instance, "definition_id"), DictUtil.get_string(instance, "site_id"), instance_id, BuildingRules.level_of(instance), days, day, cost)
	s.record_event("job_started", day, _job_event_data(job), 0, limit)
	return OpResult.success({"completed": false, "instance": instance, "job": job})


## Work a job gains per day: the village's baseline plus its assigned builders.
static func work_per_day(s: SettlementState, job: Dictionary, settlement_balance: Dictionary) -> int:
	var builders := mini(s.workers_assigned_to(DictUtil.get_string(job, "job_id")).size(), DictUtil.get_int(settlement_balance, "max_builders_per_job", 2))
	return maxi(0, DictUtil.get_int(settlement_balance, "base_job_work_per_day", 1) + builders * DictUtil.get_int(settlement_balance, "builder_work_per_day", 1))


## One day of work on every job. Returns the finished jobs (copies).
static func tick_day(s: SettlementState, building_defs: Dictionary, settlement_balance: Dictionary, day: int) -> Array:
	var completed: Array = []
	var remaining: Array = []
	var limit := DictUtil.get_int(settlement_balance, "event_log_limit", 0)
	for job in s.construction_jobs:
		if not (job is Dictionary):
			continue
		job["work_done"] = DictUtil.get_int(job, "work_done") + work_per_day(s, job, settlement_balance)
		if DictUtil.get_int(job, "work_done") >= DictUtil.get_int(job, "work_required", 1):
			completed.append(job)
		else:
			remaining.append(job)
	s.construction_jobs = remaining
	var out: Array = []
	for job in completed:
		_complete(s, job, building_defs, day, limit)
		out.append((job as Dictionary).duplicate(true))
	return out


## Abandons a job and refunds part of its cost (job_cancel_refund_ratio).
static func cancel(s: SettlementState, job_id: String, day: int, settlement_balance: Dictionary) -> OpResult:
	var job := s.job_by_id(job_id)
	if job.is_empty():
		return OpResult.failure("Unknown construction job " + job_id)
	var ratio := clampf(DictUtil.get_float(settlement_balance, "job_cancel_refund_ratio", 1.0), 0.0, 1.0)
	var refund := {}
	var cost := DictUtil.get_dict(job, "cost")
	for r in DictUtil.sorted_keys(cost):
		var back := int(floor(DictUtil.get_int(cost, String(r)) * ratio))
		if back > 0:
			refund[r] = back
			s.resources[r] = s.resource_amount(String(r)) + back
	PopulationRules.release_workers(s, job_id)
	s.construction_jobs.erase(job)
	s.record_event("job_cancelled", day, _job_event_data(job), 0, DictUtil.get_int(settlement_balance, "event_log_limit", 0))
	return OpResult.success({"job": job.duplicate(true), "refund": refund})


static func _complete(s: SettlementState, job: Dictionary, building_defs: Dictionary, day: int, limit: int) -> void:
	var job_id := DictUtil.get_string(job, "job_id")
	PopulationRules.release_workers(s, job_id)
	s.record_event("job_completed", day, _job_event_data(job), 0, limit)
	match DictUtil.get_string(job, "kind"):
		SettlementState.JOB_BUILD:
			var instance := SettlementState.make_building_instance(DictUtil.get_string(job, "instance_id"), DictUtil.get_string(job, "definition_id"), day, DictUtil.get_string(job, "site_id"), DictUtil.get_int(job, "target_level", 1))
			s.buildings.append(instance)
			s.record_event("building_constructed", day, {"instance_id": instance["instance_id"], "definition_id": instance["definition_id"], "site_id": instance["site_id"], "level": instance["level"]}, 0, limit)
		SettlementState.JOB_UPGRADE:
			var upgraded := s.building_by_id(DictUtil.get_string(job, "instance_id"))
			if not upgraded.is_empty():
				_apply_upgrade(s, upgraded, DictUtil.get_int(job, "target_level", BuildingRules.level_of(upgraded)), day, limit)
		SettlementState.JOB_REPAIR:
			var repaired := s.building_by_id(DictUtil.get_string(job, "instance_id"))
			if not repaired.is_empty():
				_apply_repair(s, repaired, day, limit)


static func _apply_upgrade(s: SettlementState, instance: Dictionary, target_level: int, day: int, limit: int) -> void:
	instance["level"] = target_level
	instance["condition"] = SettlementState.MAX_CONDITION
	s.record_event("building_upgraded", day, {"instance_id": DictUtil.get_string(instance, "instance_id"), "definition_id": DictUtil.get_string(instance, "definition_id"), "site_id": DictUtil.get_string(instance, "site_id"), "level": target_level}, 0, limit)


static func _apply_repair(s: SettlementState, instance: Dictionary, day: int, limit: int) -> void:
	instance["condition"] = SettlementState.MAX_CONDITION
	s.record_event("building_repaired", day, {"instance_id": DictUtil.get_string(instance, "instance_id"), "definition_id": DictUtil.get_string(instance, "definition_id"), "site_id": DictUtil.get_string(instance, "site_id")}, 0, limit)


static func _new_job(s: SettlementState, kind: String, definition_id: String, site_id: String, instance_id: String, target_level: int, days: int, day: int, cost: Dictionary) -> Dictionary:
	var job := {
		"job_id": s.next_job_id(),
		"kind": kind,
		"definition_id": definition_id,
		"site_id": site_id,
		"instance_id": instance_id,
		"target_level": target_level,
		"work_required": maxi(1, days),
		"work_done": 0,
		"started_day": day,
		"cost": cost.duplicate(),
	}
	s.construction_jobs.append(job)
	return job


static func _job_event_data(job: Dictionary) -> Dictionary:
	return {
		"job_id": DictUtil.get_string(job, "job_id"),
		"kind": DictUtil.get_string(job, "kind"),
		"definition_id": DictUtil.get_string(job, "definition_id"),
		"site_id": DictUtil.get_string(job, "site_id"),
		"instance_id": DictUtil.get_string(job, "instance_id"),
		"target_level": DictUtil.get_int(job, "target_level", 1),
	}


static func _spend(s: SettlementState, cost: Dictionary) -> void:
	for r in DictUtil.sorted_keys(cost):
		s.resources[r] = s.resource_amount(String(r)) - DictUtil.get_int(cost, String(r))
