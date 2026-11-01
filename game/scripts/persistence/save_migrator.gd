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

# Future migrations are added here, e.g.:
# static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
#     data["universe"]["new_field"] = default
#     return data
