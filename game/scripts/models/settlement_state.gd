class_name SettlementState
extends RefCounted
## Runtime state of one settlement (universe-scoped) — the single authoritative
## copy of everything that changes in the village.
##
## Static data lives elsewhere and is never copied in here:
##   data/buildings.json               building definitions (cost, levels, effects)
##   data/village/village_layouts.json  where the building sites are
## What changes is stored here and nowhere else:
##   resources            resource_id -> amount
##   buildings            instances {instance_id, definition_id, built_day,
##                        level, condition, site_id}
##   residents            people {resident_id, name, origin, joined_day,
##                        assigned_to}; `population` is derived from this list
##   construction_jobs    {job_id, kind, definition_id, site_id, instance_id,
##                        target_level, work_required, work_done, started_day,
##                        cost}
##   events               persistent event log {event_id, day, minute, type, data}
## In-game time and the threat level are universe-wide and stay in
## UniverseState (current_day, time_of_day_minutes, threat_state); the
## SettlementService exposes them next to the settlement in its snapshots.
## UI and village objects read through SettlementService and never keep their
## own copy of these values.

const JOB_BUILD := "build"
const JOB_UPGRADE := "upgrade"
const JOB_REPAIR := "repair"
const JOB_KINDS := [JOB_BUILD, JOB_UPGRADE, JOB_REPAIR]
const MAX_CONDITION := 100

var settlement_id: String = ""
var display_name: String = ""
var landmark_id: String = ""
## Base capacity before buildings; the effective capacity is derived.
var base_population_capacity: int = 0
var base_storage_capacity: int = 0
var loyalty: int = 50
var morale: int = 50
var productivity: int = 50
var freedom: int = 50
var discipline: int = 50
var military_strength: int = 0
var resources: Dictionary = {}
var buildings: Array = []
## Recruits waiting to arrive (e.g. a rescued survivor) — applied on return.
var pending_recruits: int = 0
var policies: Dictionary = {}
var residents: Array = []
var construction_jobs: Array = []
var events: Array = []
## Sequential id counters owned by the settlement (survive serialization).
var resident_counter: int = 0
var job_counter: int = 0
var event_counter: int = 0

## Number of residents. Derived from the roster so there is exactly one source
## of truth; assigning to it grows or shrinks the roster (kept for the callers
## that predate the resident list).
var population: int:
	get:
		return residents.size()
	set(value):
		_resize_population(value)


func resource_amount(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))


func building_count(definition_id: String) -> int:
	var n := 0
	for b in buildings:
		if String(b.get("definition_id", "")) == definition_id:
			n += 1
	return n


# --- buildings ----------------------------------------------------------------

## A fresh building instance in the persisted shape.
static func make_building_instance(instance_id: String, definition_id: String, day: int, site_id: String = "", level: int = 1) -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"built_day": day,
		"level": level,
		"condition": MAX_CONDITION,
		"site_id": site_id,
	}


## The stored instance dictionary (not a copy) or {} when unknown.
func building_by_id(instance_id: String) -> Dictionary:
	for b in buildings:
		if String(b.get("instance_id", "")) == instance_id:
			return b
	return {}


func building_at_site(site_id: String) -> Dictionary:
	if site_id == "":
		return {}
	for b in buildings:
		if String(b.get("site_id", "")) == site_id:
			return b
	return {}


# --- construction jobs ----------------------------------------------------------

func job_by_id(job_id: String) -> Dictionary:
	for j in construction_jobs:
		if String(j.get("job_id", "")) == job_id:
			return j
	return {}


func job_at_site(site_id: String) -> Dictionary:
	if site_id == "":
		return {}
	for j in construction_jobs:
		if String(j.get("site_id", "")) == site_id:
			return j
	return {}


func job_for_instance(instance_id: String) -> Dictionary:
	if instance_id == "":
		return {}
	for j in construction_jobs:
		if String(j.get("instance_id", "")) == instance_id:
			return j
	return {}


## Build jobs in progress for a definition (they count against max_count).
func pending_build_count(definition_id: String) -> int:
	var n := 0
	for j in construction_jobs:
		if String(j.get("kind", "")) == JOB_BUILD and String(j.get("definition_id", "")) == definition_id:
			n += 1
	return n


func next_job_id() -> String:
	job_counter += 1
	return "job_%06d" % job_counter


# --- residents ------------------------------------------------------------------

## Adds one resident and returns the stored dictionary. `resident_name` may be
## empty: PopulationRules.ensure_names fills it from the content name pool.
func add_resident(origin: String, day: int, resident_name: String = "") -> Dictionary:
	resident_counter += 1
	var r := {
		"resident_id": "res_%06d" % resident_counter,
		"name": resident_name,
		"origin": origin,
		"joined_day": day,
		"assigned_to": "",
	}
	residents.append(r)
	return r


func resident_by_id(resident_id: String) -> Dictionary:
	for r in residents:
		if String(r.get("resident_id", "")) == resident_id:
			return r
	return {}


## Resident ids working at a building instance or on a construction job.
func workers_assigned_to(target_id: String) -> Array[String]:
	var out: Array[String] = []
	if target_id == "":
		return out
	for r in residents:
		if String(r.get("assigned_to", "")) == target_id:
			out.append(String(r.get("resident_id", "")))
	return out


## Residents with no work assignment.
func workers_assigned_to_none() -> Array[String]:
	var out: Array[String] = []
	for r in residents:
		if String(r.get("assigned_to", "")) == "":
			out.append(String(r.get("resident_id", "")))
	return out


func _resize_population(count: int) -> void:
	count = maxi(0, count)
	while residents.size() < count:
		add_resident("unknown", 0)
	while residents.size() > count:
		# Prefer removing someone without a duty; otherwise the newest arrival.
		var index := residents.size() - 1
		for i in range(residents.size() - 1, -1, -1):
			if String(residents[i].get("assigned_to", "")) == "":
				index = i
				break
		residents.remove_at(index)


# --- events ---------------------------------------------------------------------

## Appends to the persistent event log. `limit` > 0 trims the oldest entries.
func record_event(type: String, day: int, data: Dictionary = {}, minute: int = 0, limit: int = 0) -> Dictionary:
	event_counter += 1
	var e := {
		"event_id": "sev_%06d" % event_counter,
		"day": day,
		"minute": minute,
		"type": type,
		"data": data.duplicate(true),
	}
	events.append(e)
	if limit > 0:
		while events.size() > limit:
			events.remove_at(0)
	return e


# --- serialization --------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"settlement_id": settlement_id,
		"display_name": display_name,
		"landmark_id": landmark_id,
		"base_population_capacity": base_population_capacity,
		"base_storage_capacity": base_storage_capacity,
		"loyalty": loyalty,
		"morale": morale,
		"productivity": productivity,
		"freedom": freedom,
		"discipline": discipline,
		"military_strength": military_strength,
		"resources": resources.duplicate(),
		"buildings": buildings.duplicate(true),
		"pending_recruits": pending_recruits,
		"policies": policies.duplicate(true),
		"residents": residents.duplicate(true),
		"construction_jobs": construction_jobs.duplicate(true),
		"events": events.duplicate(true),
		"resident_counter": resident_counter,
		"job_counter": job_counter,
		"event_counter": event_counter,
	}


static func from_dict(d: Dictionary) -> SettlementState:
	var s := SettlementState.new()
	s.settlement_id = DictUtil.get_string(d, "settlement_id")
	s.display_name = DictUtil.get_string(d, "display_name")
	s.landmark_id = DictUtil.get_string(d, "landmark_id")
	s.base_population_capacity = DictUtil.get_int(d, "base_population_capacity")
	s.base_storage_capacity = DictUtil.get_int(d, "base_storage_capacity")
	s.loyalty = DictUtil.get_int(d, "loyalty", 50)
	s.morale = DictUtil.get_int(d, "morale", 50)
	s.productivity = DictUtil.get_int(d, "productivity", 50)
	s.freedom = DictUtil.get_int(d, "freedom", 50)
	s.discipline = DictUtil.get_int(d, "discipline", 50)
	s.military_strength = DictUtil.get_int(d, "military_strength", 0)
	s.resources = DictUtil.int_map(DictUtil.get_dict(d, "resources"))
	for raw in DictUtil.get_array(d, "buildings"):
		if not (raw is Dictionary):
			# Kept as-is so validate() reports it instead of hiding it.
			s.buildings.append(raw)
			continue
		var b: Dictionary = raw
		s.buildings.append({
			"instance_id": DictUtil.get_string(b, "instance_id"),
			"definition_id": DictUtil.get_string(b, "definition_id"),
			"built_day": DictUtil.get_int(b, "built_day"),
			"level": DictUtil.get_int(b, "level", 1),
			"condition": DictUtil.get_int(b, "condition", MAX_CONDITION),
			"site_id": DictUtil.get_string(b, "site_id"),
		})
	s.pending_recruits = DictUtil.get_int(d, "pending_recruits", 0)
	s.policies = DictUtil.get_dict(d, "policies").duplicate(true)
	for raw in DictUtil.get_array(d, "residents"):
		if not (raw is Dictionary):
			s.residents.append(raw)
			continue
		var r: Dictionary = raw
		s.residents.append({
			"resident_id": DictUtil.get_string(r, "resident_id"),
			"name": DictUtil.get_string(r, "name"),
			"origin": DictUtil.get_string(r, "origin", "unknown"),
			"joined_day": DictUtil.get_int(r, "joined_day"),
			"assigned_to": DictUtil.get_string(r, "assigned_to"),
		})
	for raw in DictUtil.get_array(d, "construction_jobs"):
		if not (raw is Dictionary):
			s.construction_jobs.append(raw)
			continue
		var j: Dictionary = raw
		s.construction_jobs.append({
			"job_id": DictUtil.get_string(j, "job_id"),
			"kind": DictUtil.get_string(j, "kind"),
			"definition_id": DictUtil.get_string(j, "definition_id"),
			"site_id": DictUtil.get_string(j, "site_id"),
			"instance_id": DictUtil.get_string(j, "instance_id"),
			"target_level": DictUtil.get_int(j, "target_level", 1),
			"work_required": DictUtil.get_int(j, "work_required", 1),
			"work_done": DictUtil.get_int(j, "work_done", 0),
			"started_day": DictUtil.get_int(j, "started_day"),
			"cost": DictUtil.int_map(DictUtil.get_dict(j, "cost")),
		})
	for raw in DictUtil.get_array(d, "events"):
		if not (raw is Dictionary):
			s.events.append(raw)
			continue
		var e: Dictionary = raw
		s.events.append({
			"event_id": DictUtil.get_string(e, "event_id"),
			"day": DictUtil.get_int(e, "day"),
			"minute": DictUtil.get_int(e, "minute"),
			"type": DictUtil.get_string(e, "type"),
			"data": DictUtil.get_dict(e, "data").duplicate(true),
		})
	s.resident_counter = DictUtil.get_int(d, "resident_counter", s.residents.size())
	s.job_counter = DictUtil.get_int(d, "job_counter", 0)
	s.event_counter = DictUtil.get_int(d, "event_counter", s.events.size())
	return s


func validate() -> Array[String]:
	var errors: Array[String] = []
	if settlement_id == "":
		errors.append("settlement_id is required")
	if landmark_id == "":
		errors.append("settlement landmark_id is required")
	for k in resources.keys():
		if int(resources[k]) < 0:
			errors.append("negative resource amount: %s=%d" % [k, int(resources[k])])
	for stat in ["loyalty", "morale", "productivity", "freedom", "discipline"]:
		var v: int = get(stat)
		if v < 0 or v > 100:
			errors.append("%s out of range: %d" % [stat, v])
	if pending_recruits < 0:
		errors.append("pending_recruits must be >= 0")

	var instance_ids := {}
	var used_sites := {}
	for b in buildings:
		if not (b is Dictionary) or String(b.get("definition_id", "")) == "" or String(b.get("instance_id", "")) == "":
			errors.append("malformed building instance")
			continue
		var iid := String(b["instance_id"])
		if instance_ids.has(iid):
			errors.append("duplicate building instance id " + iid)
		instance_ids[iid] = true
		if int(b.get("level", 1)) < 1:
			errors.append("building %s level must be >= 1" % iid)
		var condition := int(b.get("condition", MAX_CONDITION))
		if condition < 0 or condition > MAX_CONDITION:
			errors.append("building %s condition out of range: %d" % [iid, condition])
		var site := String(b.get("site_id", ""))
		if site != "":
			if used_sites.has(site):
				errors.append("two buildings stand on site " + site)
			used_sites[site] = true

	var job_ids := {}
	var job_sites := {}
	for j in construction_jobs:
		if not (j is Dictionary) or String(j.get("job_id", "")) == "":
			errors.append("malformed construction job")
			continue
		var jid := String(j["job_id"])
		if job_ids.has(jid):
			errors.append("duplicate construction job id " + jid)
		job_ids[jid] = true
		var kind := String(j.get("kind", ""))
		if not JOB_KINDS.has(kind):
			errors.append("construction job %s has unknown kind '%s'" % [jid, kind])
		if int(j.get("work_required", 0)) < 1 or int(j.get("work_done", 0)) < 0 or int(j.get("work_done", 0)) >= int(j.get("work_required", 0)):
			errors.append("construction job %s has invalid progress" % jid)
		var jsite := String(j.get("site_id", ""))
		if jsite != "":
			if job_sites.has(jsite):
				errors.append("two construction jobs on site " + jsite)
			job_sites[jsite] = true
		if kind == JOB_BUILD:
			if String(j.get("definition_id", "")) == "" or String(j.get("instance_id", "")) == "":
				errors.append("build job %s needs a definition and a reserved instance id" % jid)
			elif instance_ids.has(String(j["instance_id"])):
				errors.append("build job %s reserves an instance id that already exists" % jid)
			if jsite != "" and used_sites.has(jsite):
				errors.append("build job %s targets the occupied site %s" % [jid, jsite])
		elif JOB_KINDS.has(kind) and not instance_ids.has(String(j.get("instance_id", ""))):
			errors.append("%s job %s references an unknown building" % [kind, jid])

	var resident_ids := {}
	for r in residents:
		if not (r is Dictionary) or String(r.get("resident_id", "")) == "":
			errors.append("malformed resident")
			continue
		var rid := String(r["resident_id"])
		if resident_ids.has(rid):
			errors.append("duplicate resident id " + rid)
		resident_ids[rid] = true
		var target := String(r.get("assigned_to", ""))
		if target != "" and not instance_ids.has(target) and not job_ids.has(target):
			errors.append("resident %s is assigned to unknown target %s" % [rid, target])

	for e in events:
		if not (e is Dictionary) or String(e.get("event_id", "")) == "" or String(e.get("type", "")) == "":
			errors.append("malformed settlement event")
	if resident_counter < residents.size() or job_counter < 0 or event_counter < 0:
		errors.append("settlement id counters are inconsistent")
	return errors
