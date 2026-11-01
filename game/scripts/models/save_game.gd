class_name SaveGame
extends RefCounted
## The complete persisted game: metadata + the three state scopes.

## Bump when the on-disk layout changes; add a migration in SaveMigrator.
const SCHEMA_VERSION: int = 1
const GAME_VERSION: String = "0.1.0"

var schema_version: int = SCHEMA_VERSION
var meta: Dictionary = {}
var character: CharacterState
var universe: UniverseState
var multiverse: MultiverseState


func refresh_meta(slot: int) -> void:
	meta = {
		"slot": slot,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"character_name": character.character_name if character else "",
		"level": character.level if character else 0,
		"day": universe.current_day if universe else 0,
		"universe_id": universe.universe_id if universe else "",
		"game_version": GAME_VERSION,
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"save_count": int(meta.get("save_count", 0)) + 1,
	}


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"meta": meta.duplicate(true),
		"character": character.to_dict(),
		"universe": universe.to_dict(),
		"multiverse": multiverse.to_dict(),
	}


## Structural reconstruction only; call `validate()` afterwards.
static func from_dict(d: Dictionary) -> SaveGame:
	var s := SaveGame.new()
	s.schema_version = DictUtil.get_int(d, "schema_version", 0)
	s.meta = DictUtil.get_dict(d, "meta").duplicate(true)
	s.character = CharacterState.from_dict(DictUtil.get_dict(d, "character"))
	s.universe = UniverseState.from_dict(DictUtil.get_dict(d, "universe"))
	s.multiverse = MultiverseState.from_dict(DictUtil.get_dict(d, "multiverse"))
	return s


func validate() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != SCHEMA_VERSION:
		errors.append("schema_version %d is not the current %d" % [schema_version, SCHEMA_VERSION])
	if character == null or universe == null or multiverse == null:
		errors.append("save is missing a state scope")
		return errors
	errors.append_array(character.validate())
	errors.append_array(universe.validate())
	errors.append_array(multiverse.validate())
	return errors
