class_name ExpeditionRecord
extends RefCounted
## One expedition's lifecycle record (universe-scoped).
##
## Status flow:  active -> (completed | aborted | defeated) ; `resolved` flips
## to true exactly once when the outcome has been applied to the world.

const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"   # walked back through the exit
const STATUS_ABORTED := "aborted"       # retreated from the pause menu
const STATUS_DEFEATED := "defeated"     # protagonist fell; returned by resurrection

var expedition_id: String = ""
var origin_id: String = ""
var destination_id: String = ""
var route_node_ids: Array[String] = []
var route_edge_ids: Array[String] = []
var travel_days: int = 1
var status: String = STATUS_ACTIVE
var started_day: int = 0
var ended_day: int = 0
## resource_id -> amount carried (applied to the settlement on resolution)
var haul: Dictionary = {}
var experience_gained: int = 0
var enemies_defeated: int = 0
var events: Array = []
var exit_reason: String = ""
var resolved: bool = false


func add_haul(resource_id: String, amount: int) -> void:
	haul[resource_id] = int(haul.get(resource_id, 0)) + amount


func is_active() -> bool:
	return status == STATUS_ACTIVE


func to_dict() -> Dictionary:
	return {
		"expedition_id": expedition_id,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"route_node_ids": route_node_ids.duplicate(),
		"route_edge_ids": route_edge_ids.duplicate(),
		"travel_days": travel_days,
		"status": status,
		"started_day": started_day,
		"ended_day": ended_day,
		"haul": haul.duplicate(),
		"experience_gained": experience_gained,
		"enemies_defeated": enemies_defeated,
		"events": events.duplicate(true),
		"exit_reason": exit_reason,
		"resolved": resolved,
	}


static func from_dict(d: Dictionary) -> ExpeditionRecord:
	var e := ExpeditionRecord.new()
	e.expedition_id = DictUtil.get_string(d, "expedition_id")
	e.origin_id = DictUtil.get_string(d, "origin_id")
	e.destination_id = DictUtil.get_string(d, "destination_id")
	e.route_node_ids = DictUtil.string_array(DictUtil.get_array(d, "route_node_ids"))
	e.route_edge_ids = DictUtil.string_array(DictUtil.get_array(d, "route_edge_ids"))
	e.travel_days = DictUtil.get_int(d, "travel_days", 1)
	e.status = DictUtil.get_string(d, "status", STATUS_ACTIVE)
	e.started_day = DictUtil.get_int(d, "started_day")
	e.ended_day = DictUtil.get_int(d, "ended_day")
	e.haul = DictUtil.int_map(DictUtil.get_dict(d, "haul"))
	e.experience_gained = DictUtil.get_int(d, "experience_gained")
	e.enemies_defeated = DictUtil.get_int(d, "enemies_defeated")
	e.events = DictUtil.get_array(d, "events").duplicate(true)
	e.exit_reason = DictUtil.get_string(d, "exit_reason")
	e.resolved = DictUtil.get_bool(d, "resolved", false)
	return e


func validate() -> Array[String]:
	var errors: Array[String] = []
	if expedition_id == "":
		errors.append("expedition_id is required")
	if destination_id == "" or origin_id == "":
		errors.append("expedition %s missing origin/destination" % expedition_id)
	if not [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_ABORTED, STATUS_DEFEATED].has(status):
		errors.append("expedition %s has unknown status '%s'" % [expedition_id, status])
	if status == STATUS_ACTIVE and resolved:
		errors.append("expedition %s is active but resolved" % expedition_id)
	for k in haul.keys():
		if int(haul[k]) < 0:
			errors.append("expedition %s negative haul %s" % [expedition_id, k])
	return errors
