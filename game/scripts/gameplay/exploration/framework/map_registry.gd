class_name MapRegistry
extends RefCounted
## Read-only helpers over the map registry (data/maps/maps.json).
##
## Persistent maps (the village, hand-authored POIs) are registry entries.
## Generated expedition areas are not listed: their id is
## "wilderness:<landmark_id>" and they are described here on the fly, so every
## kind of explorable place answers the same questions.

const KIND_VILLAGE := "village"
const KIND_POI := "poi"
const KIND_WILDERNESS := "wilderness"
const STATUS_IMPLEMENTED := "implemented"
const STATUS_RESERVED := "reserved"
const WILDERNESS_SCENE := "exploration"


## The registry entry of a map (plus `map_id`), or {} for an unknown id.
static func describe(maps: Dictionary, map_id: String) -> Dictionary:
	if MapLocation.is_wilderness(map_id):
		var landmark_id := map_id.trim_prefix(MapLocation.WILDERNESS_PREFIX)
		if landmark_id == "":
			return {}
		return {
			"map_id": map_id,
			"kind": KIND_WILDERNESS,
			"status": STATUS_IMPLEMENTED,
			"scene": WILDERNESS_SCENE,
			"landmark_id": landmark_id,
			"default_entry": "spawn",
		}
	if not maps.has(map_id) or not (maps[map_id] is Dictionary):
		return {}
	var out: Dictionary = (maps[map_id] as Dictionary).duplicate(true)
	out["map_id"] = map_id
	return out


static func exists(maps: Dictionary, map_id: String) -> bool:
	return not describe(maps, map_id).is_empty()


## Why a map cannot be entered; "" means it can.
static func enter_blocking_reason(maps: Dictionary, map_id: String) -> String:
	var def := describe(maps, map_id)
	if def.is_empty():
		return "Unknown map '%s'" % map_id
	if DictUtil.get_string(def, "status") != STATUS_IMPLEMENTED:
		return "%s is not built yet (status: %s)" % [DictUtil.get_string(def, "name", map_id), DictUtil.get_string(def, "status", "unknown")]
	if DictUtil.get_string(def, "scene") == "":
		return "%s has no scene" % DictUtil.get_string(def, "name", map_id)
	return ""


## Router scene key that shows a map ("" if it cannot be shown).
static func scene_key(maps: Dictionary, map_id: String) -> String:
	return DictUtil.get_string(describe(maps, map_id), "scene")


## The village map of a settlement, or "".
static func map_for_settlement(maps: Dictionary, settlement_id: String) -> String:
	for id in DictUtil.sorted_keys(maps):
		var def = maps[id]
		if def is Dictionary and DictUtil.get_string(def, "kind") == KIND_VILLAGE and DictUtil.get_string(def, "settlement_id") == settlement_id:
			return String(id)
	return ""


## Entry the map is entered through for a purpose ("default", "expedition_return",
## "resurrection"), falling back to the map's default entry.
static func entry_for(maps: Dictionary, map_id: String, purpose: String = "default") -> String:
	var def := describe(maps, map_id)
	var fallback := DictUtil.get_string(def, "default_entry")
	if purpose == "default":
		return fallback
	return DictUtil.get_string(DictUtil.get_dict(def, "arrival_entries"), purpose, fallback)


## Ids of every registered map of a kind, sorted.
static func ids_of_kind(maps: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in DictUtil.sorted_keys(maps):
		if maps[id] is Dictionary and DictUtil.get_string(maps[id], "kind") == kind:
			out.append(String(id))
	return out
