class_name MapTravelService
extends RefCounted
## Entering and leaving maps, and remembering where to come back to.
##
## Thin, validated front for MapLocation (the stored record) and MapRegistry
## (what exists): scenes ask this service where the player is, where they
## should appear, and which scene to open next. Bound to a save by Session
## (`Session.travel`).
##
##   enter(map_id, entry)   push the current map as a return destination
##   leave()                pop it and go back
##   arrive_home(entry)     outright arrival at the home village
##   arrival_position(...)  where the scene should put the player
##
## The service changes only UniverseState.location; changing scenes stays with
## Router (`Router.go(result.value["scene"])`).

signal location_changed(map_id: String, entry_id: String)

var save: SaveGame
var content


func _init(p_save: SaveGame, p_content) -> void:
	save = p_save
	content = p_content


func maps() -> Dictionary:
	return content.table("maps")


func location() -> Dictionary:
	return save.universe.location


func current_map_id() -> String:
	return DictUtil.get_string(location(), "map_id")


func current_entry_id() -> String:
	return DictUtil.get_string(location(), "entry_id")


func home_map_id() -> String:
	return MapRegistry.map_for_settlement(maps(), save.universe.home_settlement_id)


func describe(map_id: String) -> Dictionary:
	return MapRegistry.describe(maps(), map_id)


## OpResult: ok when the map exists and is built.
func can_enter(map_id: String) -> OpResult:
	var reason := MapRegistry.enter_blocking_reason(maps(), map_id)
	return OpResult.success() if reason == "" else OpResult.failure(reason)


## Travel into a map. value = {map_id, entry_id, scene}.
func enter(map_id: String, entry_id: String = "", remember_return: bool = true, return_entry_id: String = "") -> OpResult:
	var check := can_enter(map_id)
	if not check.ok:
		return check
	var entry := entry_id if entry_id != "" else MapRegistry.entry_for(maps(), map_id)
	MapLocation.enter(location(), map_id, entry, remember_return, return_entry_id)
	location_changed.emit(map_id, entry)
	return OpResult.success({"map_id": map_id, "entry_id": entry, "scene": MapRegistry.scene_key(maps(), map_id)})


## Go back to the last return destination (the home village if there is none).
## value = {map_id, entry_id, scene}.
func leave() -> OpResult:
	var home := home_map_id()
	var destination := MapLocation.leave(location(), home, MapRegistry.entry_for(maps(), home))
	var map_id := DictUtil.get_string(destination, "map_id")
	location_changed.emit(map_id, DictUtil.get_string(destination, "entry_id"))
	return OpResult.success({"map_id": map_id, "entry_id": DictUtil.get_string(destination, "entry_id"), "scene": MapRegistry.scene_key(maps(), map_id)})


## Outright arrival at the home village; `purpose` picks the entry
## ("default", "expedition_return", "resurrection").
func arrive_home(purpose: String = "default") -> OpResult:
	var home := home_map_id()
	if home == "":
		return OpResult.failure("The home settlement has no village map")
	var entry := MapRegistry.entry_for(maps(), home, purpose)
	MapLocation.arrive(location(), home, entry)
	location_changed.emit(home, entry)
	return OpResult.success({"map_id": home, "entry_id": entry, "scene": MapRegistry.scene_key(maps(), home)})


## The entry the current map should be re-entered through next time (for
## example the gate, after stepping out to the world map).
func set_entry(entry_id: String) -> void:
	MapLocation.set_entry(location(), entry_id)
	location_changed.emit(current_map_id(), entry_id)


## Remember the exact spot inside the current map (used when saving).
func remember_position(position: Vector2) -> void:
	MapLocation.set_position(location(), position)


## Where a scene showing `map_id` should place the player: the remembered spot
## if the player is recorded as standing in this map, otherwise the recorded
## entry, otherwise the map's default entry. `entries` maps entry ids to
## positions; `is_free` (optional, Callable(Vector2) -> bool) rejects a
## remembered spot that is no longer walkable.
func arrival_position(map_id: String, entries: Dictionary, default_entry: String, is_free: Callable = Callable()) -> Vector2:
	var here := current_map_id() == map_id
	if here and MapLocation.has_position(location()):
		var spot := MapLocation.position(location())
		if not is_free.is_valid() or is_free.call(spot):
			return spot
	var entry := current_entry_id() if here else ""
	if not entries.has(entry):
		entry = default_entry
	if entries.has(entry) and entries[entry] is Vector2:
		return entries[entry]
	return Vector2.ZERO
