class_name SettlementState
extends RefCounted
## Runtime state of one settlement (universe-scoped).
##
## Building *definitions* live in data/buildings.json; `buildings` here holds
## building *instances* ({instance_id, definition_id, built_day}).

var settlement_id: String = ""
var display_name: String = ""
var landmark_id: String = ""
var population: int = 0
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


func resource_amount(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))


func building_count(definition_id: String) -> int:
	var n := 0
	for b in buildings:
		if String(b.get("definition_id", "")) == definition_id:
			n += 1
	return n


func to_dict() -> Dictionary:
	return {
		"settlement_id": settlement_id,
		"display_name": display_name,
		"landmark_id": landmark_id,
		"population": population,
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
	}


static func from_dict(d: Dictionary) -> SettlementState:
	var s := SettlementState.new()
	s.settlement_id = DictUtil.get_string(d, "settlement_id")
	s.display_name = DictUtil.get_string(d, "display_name")
	s.landmark_id = DictUtil.get_string(d, "landmark_id")
	s.population = DictUtil.get_int(d, "population")
	s.base_population_capacity = DictUtil.get_int(d, "base_population_capacity")
	s.base_storage_capacity = DictUtil.get_int(d, "base_storage_capacity")
	s.loyalty = DictUtil.get_int(d, "loyalty", 50)
	s.morale = DictUtil.get_int(d, "morale", 50)
	s.productivity = DictUtil.get_int(d, "productivity", 50)
	s.freedom = DictUtil.get_int(d, "freedom", 50)
	s.discipline = DictUtil.get_int(d, "discipline", 50)
	s.military_strength = DictUtil.get_int(d, "military_strength", 0)
	s.resources = DictUtil.int_map(DictUtil.get_dict(d, "resources"))
	s.buildings = DictUtil.get_array(d, "buildings").duplicate(true)
	s.pending_recruits = DictUtil.get_int(d, "pending_recruits", 0)
	s.policies = DictUtil.get_dict(d, "policies").duplicate(true)
	return s


func validate() -> Array[String]:
	var errors: Array[String] = []
	if settlement_id == "":
		errors.append("settlement_id is required")
	if landmark_id == "":
		errors.append("settlement landmark_id is required")
	if population < 0:
		errors.append("population must be >= 0")
	for k in resources.keys():
		if int(resources[k]) < 0:
			errors.append("negative resource amount: %s=%d" % [k, int(resources[k])])
	for stat in ["loyalty", "morale", "productivity", "freedom", "discipline"]:
		var v: int = get(stat)
		if v < 0 or v > 100:
			errors.append("%s out of range: %d" % [stat, v])
	for b in buildings:
		if not (b is Dictionary) or String(b.get("definition_id", "")) == "" or String(b.get("instance_id", "")) == "":
			errors.append("malformed building instance")
	return errors
