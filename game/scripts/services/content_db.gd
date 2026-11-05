extends Node
## Autoload "Content": read-only registry of every content definition.
##
## JSON was chosen for definitions (over typed Resources) because the data is
## hand-edited, diff-friendly, needs no editor integration yet, and the same
## loader serves saves. Referential integrity is checked once at startup and
## problems are pushed as errors (never silently ignored).

const DATA_FILES := {
	"balance": "res://data/balance.json",
	"ancestries": "res://data/ancestries.json",
	"archetypes": "res://data/archetypes.json",
	"classes": "res://data/classes.json",
	"factions": "res://data/factions.json",
	"resources": "res://data/resources.json",
	"buildings": "res://data/buildings.json",
	"enemies": "res://data/enemies.json",
	"biomes": "res://data/biomes.json",
	"landmarks": "res://data/regions/landmarks.json",
	"difficulty": "res://data/difficulty.json",
	"decisions": "res://data/decisions.json",
	"residents": "res://data/residents.json",
	"village_layouts": "res://data/village/village_layouts.json",
	"maps": "res://data/maps/maps.json",
	"pois": "res://data/pois.json",
	"recipes": "res://data/recipes.json",
}

var _tables: Dictionary = {}
var load_errors: Array[String] = []
var loaded: bool = false


func _ready() -> void:
	load_all()


func load_all() -> void:
	_tables.clear()
	load_errors.clear()
	for key in DATA_FILES.keys():
		var r := _load_json(DATA_FILES[key])
		if r.ok:
			var table: Dictionary = r.value
			table.erase("_comment")
			_tables[key] = table
		else:
			_tables[key] = {}
			load_errors.append("%s: %s" % [key, r.error])
	_validate_references()
	loaded = true
	for e in load_errors:
		push_error("Content: " + e)


func _load_json(path: String) -> OpResult:
	if not FileAccess.file_exists(path):
		return OpResult.failure("missing file " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return OpResult.failure("cannot open " + path)
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return OpResult.failure("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	if not (json.data is Dictionary):
		return OpResult.failure(path + " root is not an object")
	return OpResult.success(json.data)


func table(name: String) -> Dictionary:
	assert(_tables.has(name), "Unknown content table: " + name)
	return _tables[name]


func has_def(table_name: String, id: String) -> bool:
	return _tables.has(table_name) and (_tables[table_name] as Dictionary).has(id)


## Returns the definition or an empty Dictionary (with an error pushed).
func get_def(table_name: String, id: String) -> Dictionary:
	if not has_def(table_name, id):
		push_error("Content: missing definition %s/%s" % [table_name, id])
		return {}
	return _tables[table_name][id]


## Sorted ids of a table, for deterministic iteration.
func ids(table_name: String) -> Array:
	return DictUtil.sorted_keys(table(table_name))


func balance(section: String) -> Dictionary:
	return DictUtil.get_dict(table("balance"), section)


func difficulty_presets() -> Dictionary:
	return DictUtil.get_dict(table("difficulty"), "presets")


func difficulty_parameters() -> Dictionary:
	return DictUtil.get_dict(table("difficulty"), "parameters")


func _validate_references() -> void:
	var ancestries := table("ancestries")
	for id in table("archetypes").keys():
		var a: Dictionary = table("archetypes")[id]
		if not ancestries.has(DictUtil.get_string(a, "primary_ancestry")):
			load_errors.append("archetype %s references unknown primary_ancestry" % id)
		var sec := DictUtil.get_string(a, "secondary_ancestry")
		if sec != "" and not ancestries.has(sec):
			load_errors.append("archetype %s references unknown secondary_ancestry" % id)
		if not table("classes").has(DictUtil.get_string(a, "starting_class", "survivor")):
			load_errors.append("archetype %s references unknown starting_class" % id)
	for id in table("landmarks").keys():
		var l: Dictionary = table("landmarks")[id]
		if not table("biomes").has(DictUtil.get_string(l, "biome")):
			load_errors.append("landmark %s references unknown biome" % id)
	for id in table("biomes").keys():
		var b: Dictionary = table("biomes")[id]
		for e in DictUtil.get_array(b, "enemy_pool"):
			if not table("enemies").has(String(e)):
				load_errors.append("biome %s references unknown enemy %s" % [id, String(e)])
		for r in DictUtil.get_dict(b, "resource_pool").keys():
			if not table("resources").has(String(r)):
				load_errors.append("biome %s references unknown resource %s" % [id, String(r)])
	for id in table("buildings").keys():
		var bd: Dictionary = table("buildings")[id]
		for r in DictUtil.get_dict(bd, "cost").keys():
			if not table("resources").has(String(r)):
				load_errors.append("building %s cost references unknown resource %s" % [id, String(r)])
		for req in DictUtil.get_array(bd, "requires"):
			if not table("buildings").has(String(req)):
				load_errors.append("building %s requires unknown building %s" % [id, String(req)])
	for id in table("factions").keys():
		var f: Dictionary = table("factions")[id]
		for t in DictUtil.get_array(f, "territory"):
			if not table("landmarks").has(String(t)):
				load_errors.append("faction %s claims unknown landmark %s" % [id, String(t)])
		for other in DictUtil.get_dict(f, "relations").keys():
			if not table("factions").has(String(other)):
				load_errors.append("faction %s has relation with unknown faction %s" % [id, String(other)])
	for id in table("enemies").keys():
		for r in DictUtil.get_dict(table("enemies")[id], "drops").keys():
			if not table("resources").has(String(r)):
				load_errors.append("enemy %s drops unknown resource %s" % [id, String(r)])
	for id in table("decisions").keys():
		var dd: Dictionary = table("decisions")[id]
		for b in DictUtil.get_array(dd, "appears_in_biomes"):
			if not table("biomes").has(String(b)):
				load_errors.append("decision %s appears in unknown biome %s" % [id, String(b)])
		for l in DictUtil.get_array(dd, "appears_at_landmarks"):
			if not table("landmarks").has(String(l)):
				load_errors.append("decision %s appears at unknown landmark %s" % [id, String(l)])
		for v in DictUtil.get_array(dd, "prompts_by_reputation"):
			if not table("factions").has(DictUtil.get_string(v, "faction")):
				load_errors.append("decision %s prompt variant references unknown faction" % id)
		var opts := DictUtil.get_dict(dd, "options")
		for oid in opts.keys():
			var opt: Dictionary = opts[oid]
			var gate := DictUtil.get_dict(opt, "requires_reputation")
			if not gate.is_empty() and not table("factions").has(DictUtil.get_string(gate, "faction")):
				load_errors.append("decision %s option %s gates on unknown faction" % [id, oid])
			var eff := DictUtil.get_dict(opt, "effects")
			for f in DictUtil.get_dict(eff, "reputation").keys():
				if not table("factions").has(String(f)):
					load_errors.append("decision %s option %s affects unknown faction %s" % [id, oid, String(f)])
			for r in DictUtil.get_dict(eff, "haul").keys():
				if not table("resources").has(String(r)):
					load_errors.append("decision %s option %s hauls unknown resource %s" % [id, oid, String(r)])
			for r in DictUtil.get_dict(opt, "requires_haul").keys():
				if not table("resources").has(String(r)):
					load_errors.append("decision %s option %s requires unknown resource %s" % [id, oid, String(r)])
	var presets := difficulty_presets()
	for pid in presets.keys():
		for param in difficulty_parameters().keys():
			if not (presets[pid] as Dictionary).has(param):
				load_errors.append("difficulty preset %s missing parameter %s" % [pid, param])
	_validate_building_levels()
	_validate_maps_and_layouts()
	_validate_stage2()


func _validate_stage2() -> void:
	for id in table("recipes"):
		var recipe: Dictionary = table("recipes")[id]
		var error := ResourceTransaction.validate_amounts(DictUtil.get_dict(recipe, "cost"), table("resources"))
		if error != "":
			load_errors.append("recipe %s: %s" % [id, error])
		if not table("buildings").has(DictUtil.get_string(recipe, "requires")) or DictUtil.get_int(recipe, "level") < 1 or DictUtil.get_int(recipe, "minutes") < 0:
			load_errors.append("recipe %s has invalid requirements or duration" % id)
		var production_error := ResourceTransaction.validate_amounts(DictUtil.get_dict(recipe, "production"), table("resources"))
		if production_error != "":
			load_errors.append("recipe %s: %s" % [id, production_error])
	for id in table("pois"):
		var poi: Dictionary = table("pois")[id]
		var definition := MapDefinition.from_dict(DictUtil.get_dict(poi, "layout"))
		# POIs have no village building sites; validate geometry and entries only.
		for error in definition.validate():
			load_errors.append("POI %s: %s" % [id, error])
		if definition.map_id != id or not table("maps").has(id):
			load_errors.append("POI %s has a mismatched map id" % id)
		var keys := {}
		var enemy_keys := {}
		for spawn in DictUtil.get_array(poi, "enemies"):
			enemy_keys[DictUtil.get_string(spawn, "id")] = true
			if not table("enemies").has(DictUtil.get_string(spawn, "enemy_id")):
				load_errors.append("POI %s references an unknown enemy" % id)
		for object in DictUtil.get_array(poi, "objects") + DictUtil.get_array(poi, "enemies"):
			var key := DictUtil.get_string(object, "id")
			if key == "" or keys.has(key):
				load_errors.append("POI %s has a duplicate/empty object id" % id)
			keys[key] = true
			var at := DictUtil.get_array(object, "at")
			if at.size() != 2 or not definition.is_position_free(Vector2(float(at[0]), float(at[1])) * definition.cell_size, [], 12):
				load_errors.append("POI %s object %s is outside walkable ground" % [id, key])
			for guard in DictUtil.get_array(object, "requires_defeated"):
				if not enemy_keys.has(guard):
					load_errors.append("POI %s object %s requires an unknown enemy" % [id, key])
			var effects: Array = [object]
			effects.append_array(DictUtil.get_dict(object, "choices").values())
			for effect in effects:
				var error := ResourceTransaction.validate_amounts(DictUtil.get_dict(effect, "reward"), table("resources"))
				if error != "":
					load_errors.append("POI %s object %s: %s" % [id, key, error])


## Upgrade levels, placement and worker production of building definitions.
func _validate_building_levels() -> void:
	var buildings := table("buildings")
	var resources := table("resources")
	for id in buildings.keys():
		var bd: Dictionary = buildings[id]
		var placement := DictUtil.get_string(bd, "placement")
		if placement != "" and placement != "reserved":
			load_errors.append("building %s has unknown placement '%s'" % [id, placement])
		for level in range(1, BuildingRules.max_level(bd) + 1):
			var spec := BuildingRules.level_spec(bd, level)
			var cost_error := ResourceTransaction.validate_amounts(DictUtil.get_dict(spec, "cost"), resources)
			if cost_error != "":
				load_errors.append("building %s level %d: %s" % [id, level, cost_error])
			for r in DictUtil.get_dict(spec, "cost").keys():
				if not resources.has(String(r)):
					load_errors.append("building %s level %d cost references unknown resource %s" % [id, level, String(r)])
			for req in DictUtil.get_array(spec, "requires"):
				if not buildings.has(String(req)):
					load_errors.append("building %s level %d requires unknown building %s" % [id, level, String(req)])
			var effects := DictUtil.get_dict(spec, "effects")
			for key in ["production", "production_per_worker"]:
				for r in DictUtil.get_dict(effects, key).keys():
					if not resources.has(String(r)):
						load_errors.append("building %s level %d %s references unknown resource %s" % [id, level, key, String(r)])


## The map registry and the village layouts it points at.
func _validate_maps_and_layouts() -> void:
	var maps := table("maps")
	var layouts := table("village_layouts")
	var map_ids_in_layouts := {}
	for sid in layouts.keys():
		if not (layouts[sid] is Dictionary):
			load_errors.append("village layout %s is not an object" % sid)
			continue
		var definition := MapDefinition.from_dict(layouts[sid])
		for e in definition.validate(table("buildings")):
			load_errors.append("village layout " + e)
		map_ids_in_layouts[definition.map_id] = String(sid)
		var registered := DictUtil.get_dict(maps, definition.map_id)
		if registered.is_empty():
			load_errors.append("village layout %s uses map id '%s' that is not in the map registry" % [sid, definition.map_id])
		elif DictUtil.get_string(registered, "settlement_id") != String(sid):
			load_errors.append("map %s does not point back at settlement %s" % [definition.map_id, sid])
		else:
			var arrival := DictUtil.get_dict(registered, "arrival_entries")
			for purpose in arrival.keys():
				if not definition.has_entry(String(arrival[purpose])):
					load_errors.append("map %s arrival entry '%s' is not an entry of its layout" % [definition.map_id, String(arrival[purpose])])
			if not definition.has_entry(DictUtil.get_string(registered, "default_entry")):
				load_errors.append("map %s default_entry is not an entry of its layout" % definition.map_id)
	for id in maps.keys():
		var md: Dictionary = maps[id]
		var kind := DictUtil.get_string(md, "kind")
		if kind != MapRegistry.KIND_VILLAGE and kind != MapRegistry.KIND_POI:
			load_errors.append("map %s has unknown kind '%s'" % [id, kind])
		var status := DictUtil.get_string(md, "status")
		if status != MapRegistry.STATUS_IMPLEMENTED and status != MapRegistry.STATUS_RESERVED:
			load_errors.append("map %s has unknown status '%s'" % [id, status])
		if status == MapRegistry.STATUS_IMPLEMENTED and DictUtil.get_string(md, "scene") == "":
			load_errors.append("map %s is implemented but names no scene" % id)
		if kind == MapRegistry.KIND_VILLAGE and not map_ids_in_layouts.has(String(id)):
			load_errors.append("village map %s has no layout" % id)
		if String(id).begins_with(MapLocation.WILDERNESS_PREFIX):
			load_errors.append("map id %s uses the reserved wilderness prefix" % id)
