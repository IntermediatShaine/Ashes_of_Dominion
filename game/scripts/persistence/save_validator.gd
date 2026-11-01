class_name SaveValidator
extends RefCounted
## Two-stage validation of save data:
##   1. structural: the raw dictionary has the sections a save must have;
##   2. semantic: the reconstructed SaveGame passes every model's validate().
## Any failure is a controlled error; corrupted saves are never silently used.


static func validate_raw(raw: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not (raw is Dictionary):
		errors.append("save root is not an object")
		return errors
	var d: Dictionary = raw
	for section in ["meta", "character", "universe", "multiverse"]:
		if not d.has(section) or not (d[section] is Dictionary):
			errors.append("missing section: " + section)
	if not d.has("schema_version"):
		errors.append("missing schema_version")
	return errors


## Full validation; returns OpResult with the SaveGame as value.
static func build_and_validate(raw: Variant) -> OpResult:
	var structural := validate_raw(raw)
	if not structural.is_empty():
		return OpResult.failure("Structural: " + "; ".join(structural))
	var migrated := SaveMigrator.migrate(raw as Dictionary)
	if not migrated.ok:
		return migrated
	var save := SaveGame.from_dict(migrated.value)
	var semantic := save.validate()
	if not semantic.is_empty():
		return OpResult.failure("Invalid save: " + "; ".join(semantic))
	var result := OpResult.success(save)
	for w in migrated.warnings:
		result.with_warning(w)
	return result
