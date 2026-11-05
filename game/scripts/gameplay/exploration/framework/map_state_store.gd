class_name MapStateStore
extends RefCounted
## Persistent per-map state, shared by the village, POIs and expedition areas.
##
## Everything lives in UniverseState.world_modifications[map_id] — the record
## the expedition areas already use for harvested resource nodes — so there is
## one place for "what the player changed on this map" and it is saved with the
## universe. This class only adds named access:
##
##   flags    key -> value   anything a map wants to remember (door opened…)
##   once     key -> day     things that happen at most once (chest looted…)
##
## Keys already used by other systems ("harvested") are left alone. For an
## expedition area the map id is the landmark id (the existing convention);
## for registered maps it is the id in data/maps/maps.json.

const FLAGS := "flags"
const ONCE := "once"


## The stored record of a map (created on demand; not a copy).
static func record(u: UniverseState, map_id: String) -> Dictionary:
	if not (u.world_modifications.get(map_id, null) is Dictionary):
		u.world_modifications[map_id] = {}
	return u.world_modifications[map_id]


static func has_record(u: UniverseState, map_id: String) -> bool:
	return u.world_modifications.get(map_id, null) is Dictionary


static func get_flag(u: UniverseState, map_id: String, key: String, default_value: Variant = null) -> Variant:
	if not has_record(u, map_id):
		return default_value
	return DictUtil.get_dict(u.world_modifications[map_id], FLAGS).get(key, default_value)


static func set_flag(u: UniverseState, map_id: String, key: String, value: Variant) -> void:
	var rec := record(u, map_id)
	if not (rec.get(FLAGS, null) is Dictionary):
		rec[FLAGS] = {}
	rec[FLAGS][key] = value


static func clear_flag(u: UniverseState, map_id: String, key: String) -> void:
	if has_record(u, map_id) and u.world_modifications[map_id].get(FLAGS, null) is Dictionary:
		u.world_modifications[map_id][FLAGS].erase(key)


static func is_done(u: UniverseState, map_id: String, key: String) -> bool:
	if not has_record(u, map_id):
		return false
	return DictUtil.get_dict(u.world_modifications[map_id], ONCE).has(key)


## Records a once-only event. Returns true the first time, false afterwards.
static func mark_done(u: UniverseState, map_id: String, key: String) -> bool:
	if is_done(u, map_id, key):
		return false
	var rec := record(u, map_id)
	if not (rec.get(ONCE, null) is Dictionary):
		rec[ONCE] = {}
	rec[ONCE][key] = u.current_day
	return true
