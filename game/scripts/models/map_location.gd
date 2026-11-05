class_name MapLocation
extends RefCounted
## Where the protagonist is and where they go back to (universe-scoped).
##
## Stored in UniverseState.location:
##   {map_id, entry_id, return_stack: [{map_id, entry_id}, ...], position: [x, y]}
##
##   map_id        a key of data/maps/maps.json, or "wilderness:<landmark_id>"
##                 for a generated expedition area
##   entry_id      the named entry point the map scene spawns the player at
##   return_stack  return destinations, innermost last: leaving a map pops one
##   position      optional exact resume point inside `map_id` (written when
##                 the game is saved while standing in a persistent map);
##                 cleared whenever the player arrives through an entry
##
## Pure functions over the dictionary: the map scenes and MapTravelService go
## through these, and so does ExpeditionService, so every way of travelling
## keeps the same record.

const WILDERNESS_PREFIX := "wilderness:"


static func make(map_id: String, entry_id: String = "") -> Dictionary:
	return {"map_id": map_id, "entry_id": entry_id, "return_stack": []}


static func wilderness_map_id(landmark_id: String) -> String:
	return WILDERNESS_PREFIX + landmark_id


static func is_wilderness(map_id: String) -> bool:
	return map_id.begins_with(WILDERNESS_PREFIX)


## Typed copy of a raw (JSON) location.
static func normalized(raw: Dictionary) -> Dictionary:
	var out := make(DictUtil.get_string(raw, "map_id"), DictUtil.get_string(raw, "entry_id"))
	for item in DictUtil.get_array(raw, "return_stack"):
		if item is Dictionary:
			out["return_stack"].append({
				"map_id": DictUtil.get_string(item, "map_id"),
				"entry_id": DictUtil.get_string(item, "entry_id"),
			})
		else:
			# Kept so validate() reports the damage instead of hiding it.
			out["return_stack"].append(item)
	var pos := DictUtil.get_array(raw, "position")
	if pos.size() == 2 and (pos[0] is float or pos[0] is int) and (pos[1] is float or pos[1] is int):
		out["position"] = [int(round(pos[0])), int(round(pos[1]))]
	return out


static func validate(location: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if DictUtil.get_string(location, "map_id") == "":
		errors.append("location.map_id is required")
	if not (location.get("return_stack", []) is Array):
		errors.append("location.return_stack must be a list")
		return errors
	for item in DictUtil.get_array(location, "return_stack"):
		if not (item is Dictionary) or DictUtil.get_string(item, "map_id") == "":
			errors.append("location.return_stack has a malformed destination")
	if location.has("position"):
		var pos := DictUtil.get_array(location, "position")
		if pos.size() != 2:
			errors.append("location.position must be [x, y]")
	return errors


## Travel into `map_id`. With `remember_return` the map being left is pushed
## as a return destination; `return_entry_id` names the entry to come back
## through (defaults to the entry the player last used there).
static func enter(location: Dictionary, map_id: String, entry_id: String = "", remember_return: bool = true, return_entry_id: String = "") -> void:
	if remember_return and DictUtil.get_string(location, "map_id") != "":
		var back_entry := return_entry_id if return_entry_id != "" else DictUtil.get_string(location, "entry_id")
		_stack(location).append({"map_id": DictUtil.get_string(location, "map_id"), "entry_id": back_entry})
	location["map_id"] = map_id
	location["entry_id"] = entry_id
	location.erase("position")


## Go back to the innermost return destination, or to the fallback when the
## stack is empty. Returns the destination {map_id, entry_id} now current.
static func leave(location: Dictionary, fallback_map_id: String, fallback_entry_id: String = "") -> Dictionary:
	var stack := _stack(location)
	var destination := {"map_id": fallback_map_id, "entry_id": fallback_entry_id}
	if not stack.is_empty():
		var top = stack.pop_back()
		if top is Dictionary and DictUtil.get_string(top, "map_id") != "":
			destination = {"map_id": DictUtil.get_string(top, "map_id"), "entry_id": DictUtil.get_string(top, "entry_id")}
	location["map_id"] = destination["map_id"]
	location["entry_id"] = destination["entry_id"]
	location.erase("position")
	return destination


## Arrive somewhere outright (resurrection, new game): no way back is kept.
static func arrive(location: Dictionary, map_id: String, entry_id: String = "") -> void:
	location["map_id"] = map_id
	location["entry_id"] = entry_id
	location["return_stack"] = []
	location.erase("position")


## Change only the entry used the next time the current map opens.
static func set_entry(location: Dictionary, entry_id: String) -> void:
	location["entry_id"] = entry_id
	location.erase("position")


static func set_position(location: Dictionary, position: Vector2) -> void:
	location["position"] = [int(round(position.x)), int(round(position.y))]


static func has_position(location: Dictionary) -> bool:
	return DictUtil.get_array(location, "position").size() == 2


static func position(location: Dictionary) -> Vector2:
	var pos := DictUtil.get_array(location, "position")
	if pos.size() != 2:
		return Vector2.ZERO
	return Vector2(float(pos[0]), float(pos[1]))


static func _stack(location: Dictionary) -> Array:
	if not (location.get("return_stack", null) is Array):
		location["return_stack"] = []
	return location["return_stack"]
