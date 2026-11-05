class_name PopulationRules
extends RefCounted
## Residents: names and work assignments. Pure functions over SettlementState.
##
## A resident works in at most one place: `assigned_to` is "" (idle), a
## building instance id, or a construction job id. Who works where is stored
## only on the resident; a building's or a job's workers are derived.


## Gives every unnamed resident a name from the pool. Deterministic: the pick
## depends only on the universe seed and the resident's id, and a name already
## in use is skipped. Returns how many residents were named.
static func ensure_names(s: SettlementState, name_pool: Array, world_seed: int) -> int:
	var used := {}
	for r in s.residents:
		if r is Dictionary and DictUtil.get_string(r, "name") != "":
			used[DictUtil.get_string(r, "name")] = true
	var named := 0
	for r in s.residents:
		if not (r is Dictionary) or DictUtil.get_string(r, "name") != "":
			continue
		var resident_id := DictUtil.get_string(r, "resident_id")
		var picked := ""
		if not name_pool.is_empty():
			var start := posmod(StableHash.derive_seed(world_seed, "resident:" + resident_id), name_pool.size())
			for offset in name_pool.size():
				var candidate := String(name_pool[(start + offset) % name_pool.size()])
				if not used.has(candidate):
					picked = candidate
					break
			if picked == "":
				picked = "%s %s" % [String(name_pool[start]), resident_id.get_slice("_", 1).lstrip("0")]
		else:
			picked = "Villager " + resident_id.get_slice("_", 1).lstrip("0")
		r["name"] = picked
		used[picked] = true
		named += 1
	return named


## The resident name list from a content provider (data/residents.json).
static func name_pool(content) -> Array:
	return DictUtil.get_array(DictUtil.get_dict(content.table("residents"), "names"), "pool")


static func idle_residents(s: SettlementState) -> Array[String]:
	return s.workers_assigned_to_none()


## Why a resident cannot be assigned to a target; empty means they can.
static func assign_blocking_reasons(s: SettlementState, resident_id: String, target_id: String, building_defs: Dictionary, settlement_balance: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var resident := s.resident_by_id(resident_id)
	if resident.is_empty():
		reasons.append("Unknown resident " + resident_id)
		return reasons
	if target_id == "":
		reasons.append("No work place given")
		return reasons
	if DictUtil.get_string(resident, "assigned_to") == target_id:
		reasons.append("Already working there")
		return reasons
	var building := s.building_by_id(target_id)
	if not building.is_empty():
		if not BuildingRules.is_functional(building):
			reasons.append("The building is destroyed")
		var slots := BuildingRules.worker_slots(building, building_defs)
		var taken := s.workers_assigned_to(target_id).size()
		if slots <= 0:
			reasons.append("Nobody can work here")
		elif taken >= slots:
			reasons.append("No free work place (%d/%d)" % [taken, slots])
		return reasons
	var job := s.job_by_id(target_id)
	if not job.is_empty():
		var max_builders := DictUtil.get_int(settlement_balance, "max_builders_per_job", 2)
		var builders := s.workers_assigned_to(target_id).size()
		if builders >= max_builders:
			reasons.append("No room for another builder (%d/%d)" % [builders, max_builders])
		return reasons
	reasons.append("Unknown work place " + target_id)
	return reasons


static func assign(s: SettlementState, resident_id: String, target_id: String, building_defs: Dictionary, settlement_balance: Dictionary, day: int) -> OpResult:
	var reasons := assign_blocking_reasons(s, resident_id, target_id, building_defs, settlement_balance)
	if not reasons.is_empty():
		return OpResult.failure("Cannot assign %s: %s" % [resident_id, "; ".join(reasons)])
	var resident := s.resident_by_id(resident_id)
	var previous := DictUtil.get_string(resident, "assigned_to")
	resident["assigned_to"] = target_id
	s.record_event("worker_assigned", day, {"resident_id": resident_id, "target_id": target_id, "previous": previous}, 0, DictUtil.get_int(settlement_balance, "event_log_limit", 0))
	return OpResult.success({"resident_id": resident_id, "target_id": target_id, "previous": previous})


static func unassign(s: SettlementState, resident_id: String, settlement_balance: Dictionary, day: int) -> OpResult:
	var resident := s.resident_by_id(resident_id)
	if resident.is_empty():
		return OpResult.failure("Unknown resident " + resident_id)
	var previous := DictUtil.get_string(resident, "assigned_to")
	if previous == "":
		return OpResult.failure("%s has no work to leave" % resident_id)
	resident["assigned_to"] = ""
	s.record_event("worker_unassigned", day, {"resident_id": resident_id, "previous": previous}, 0, DictUtil.get_int(settlement_balance, "event_log_limit", 0))
	return OpResult.success({"resident_id": resident_id, "target_id": "", "previous": previous})


## Frees everyone working at a target (a finished job, a removed building).
## Returns the resident ids that became idle.
static func release_workers(s: SettlementState, target_id: String) -> Array[String]:
	var released: Array[String] = []
	if target_id == "":
		return released
	for r in s.residents:
		if r is Dictionary and DictUtil.get_string(r, "assigned_to") == target_id:
			r["assigned_to"] = ""
			released.append(DictUtil.get_string(r, "resident_id"))
	return released


## Drops assignments that point at a destroyed building or exceed its work
## places (a building can lose places when it is damaged). Returns the freed ids.
static func release_invalid(s: SettlementState, building_defs: Dictionary) -> Array[String]:
	var released: Array[String] = []
	var seen := {}
	for r in s.residents:
		if not (r is Dictionary):
			continue
		var target := DictUtil.get_string(r, "assigned_to")
		if target == "":
			continue
		var building := s.building_by_id(target)
		if building.is_empty():
			if s.job_by_id(target).is_empty():
				r["assigned_to"] = ""
				released.append(DictUtil.get_string(r, "resident_id"))
			continue
		seen[target] = int(seen.get(target, 0)) + 1
		if int(seen[target]) > BuildingRules.worker_slots(building, building_defs):
			r["assigned_to"] = ""
			released.append(DictUtil.get_string(r, "resident_id"))
	return released
