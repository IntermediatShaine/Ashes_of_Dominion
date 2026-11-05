class_name SaveMigrator
extends RefCounted
## Upgrades raw save dictionaries from older schema versions to the current one.
##
## Each migration step converts version N -> N+1 and is registered in
## `_steps`. Unknown (0 / missing) or future versions are rejected rather than
## guessed at.


## Returns OpResult whose value is the migrated dictionary.
static func migrate(raw: Dictionary) -> OpResult:
	var version: int = DictUtil.get_int(raw, "schema_version", 0)
	if version <= 0:
		return OpResult.failure("Save has no valid schema_version")
	if version > SaveGame.SCHEMA_VERSION:
		return OpResult.failure("Save schema_version %d is newer than supported %d" % [version, SaveGame.SCHEMA_VERSION])
	var data := raw.duplicate(true)
	var result := OpResult.success(data)
	while version < SaveGame.SCHEMA_VERSION:
		var step := Callable(SaveMigrator, "_migrate_%d_to_%d" % [version, version + 1])
		if not step.is_valid():
			return OpResult.failure("No migration path from schema %d" % version)
		data = step.call(data)
		version += 1
		data["schema_version"] = version
		result.with_warning("Migrated save to schema %d" % version)
	result.value = data
	return result

## Schema 1 -> 2 (walkable village, Stage 1).
##
## Adds the universe clock's time of day and the protagonist's location, and
## turns the settlement's bare numbers into the richer records the village
## needs. Nothing is invented that the old save did not imply:
##   - universe.time_of_day_minutes  the default morning hour
##   - universe.location             the home village, at its spawn point
##   - settlement.buildings[*]       + level 1, condition 100, site_id ""
##   - settlement.residents          one unnamed founder per old `population`
##   - settlement.construction_jobs / events / counters   empty
## Names and building sites depend on content (the name pool, the village
## layout), so they are filled in afterwards by SettlementService.normalize(),
## which Session runs after binding any save. The constants below are frozen
## with this migration on purpose: a migration must not change meaning when
## the content files do.
const _V2_HOME_MAP_ID := "village_emberfall"
const _V2_HOME_ENTRY := "spawn"
const _V2_START_MINUTE := 480


static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	if not (data.get("universe", null) is Dictionary):
		return data
	var u: Dictionary = data["universe"]
	if not u.has("time_of_day_minutes"):
		u["time_of_day_minutes"] = _V2_START_MINUTE
	if not (u.get("location", null) is Dictionary):
		u["location"] = {"map_id": _V2_HOME_MAP_ID, "entry_id": _V2_HOME_ENTRY, "return_stack": []}
	var settlements = u.get("settlements", {})
	if not (settlements is Dictionary):
		return data
	for sid in settlements.keys():
		if not (settlements[sid] is Dictionary):
			continue
		var s: Dictionary = settlements[sid]
		for b in DictUtil.get_array(s, "buildings"):
			if b is Dictionary:
				if not b.has("level"):
					b["level"] = 1
				if not b.has("condition"):
					b["condition"] = 100
				if not b.has("site_id"):
					b["site_id"] = ""
		if not (s.get("residents", null) is Array):
			var residents: Array = []
			for i in maxi(0, DictUtil.get_int(s, "population", 0)):
				residents.append({"resident_id": "res_%06d" % (i + 1), "name": "", "origin": "founder", "joined_day": 1, "assigned_to": ""})
			s["residents"] = residents
			s["resident_counter"] = residents.size()
		s.erase("population")
		if not (s.get("construction_jobs", null) is Array):
			s["construction_jobs"] = []
		if not (s.get("events", null) is Array):
			s["events"] = []
		if not s.has("job_counter"):
			s["job_counter"] = 0
		if not s.has("event_counter"):
			s["event_counter"] = 0
	return data
