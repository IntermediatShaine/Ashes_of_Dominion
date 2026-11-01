class_name CharacterState
extends RefCounted
## Persistent protagonist state. This is the ONLY scope that follows the
## character between universes.
##
## Ownership rules (see docs/game_state.md):
##   - Everything here is universe-independent: identity, ancestry, progression,
##     morality, permanent unlocks, persistent lore.
##   - Current health, temporary conditions and universe-bound equipment are NOT
##     here; they live in UniverseState.protagonist_condition.
##   - Faction reputation is NOT here; it is universe state (factions belong
##     to a universe). Morality is here because it is a property of the person.

const ATTRIBUTE_NAMES: Array[String] = ["strength", "dexterity", "endurance", "intelligence", "willpower"]

var character_id: String = ""
var character_name: String = ""
var archetype_id: String = ""
var primary_ancestry: String = ""
## Empty string when the character is not of mixed ancestry.
var secondary_ancestry: String = ""
var background: String = ""
var current_class: String = "survivor"
var unlocked_classes: Array[String] = ["survivor"]
var level: int = 1
var experience: int = 0
var base_attributes: Dictionary = {}
var learned_skills: Array[String] = []
var permanent_unlocks: Array[String] = []
var persistent_lore: Array[String] = []
## -100 (ruthless) .. +100 (virtuous). Independent from faction reputation.
var morality: int = 0
## Append-only log of morality-affecting events: {id, kind, delta, universe_id}.
var morality_log: Array = []
var persistent_character_flags: Dictionary = {}
var created_at_unix: int = 0


func is_mixed_ancestry() -> bool:
	return secondary_ancestry != ""


func attribute(name: String) -> int:
	return int(base_attributes.get(name, 0))


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"archetype_id": archetype_id,
		"primary_ancestry": primary_ancestry,
		"secondary_ancestry": secondary_ancestry,
		"background": background,
		"current_class": current_class,
		"unlocked_classes": unlocked_classes.duplicate(),
		"level": level,
		"experience": experience,
		"base_attributes": base_attributes.duplicate(),
		"learned_skills": learned_skills.duplicate(),
		"permanent_unlocks": permanent_unlocks.duplicate(),
		"persistent_lore": persistent_lore.duplicate(),
		"morality": morality,
		"morality_log": morality_log.duplicate(true),
		"persistent_character_flags": persistent_character_flags.duplicate(true),
		"created_at_unix": created_at_unix,
	}


static func from_dict(d: Dictionary) -> CharacterState:
	var c := CharacterState.new()
	c.character_id = DictUtil.get_string(d, "character_id")
	c.character_name = DictUtil.get_string(d, "character_name")
	c.archetype_id = DictUtil.get_string(d, "archetype_id")
	c.primary_ancestry = DictUtil.get_string(d, "primary_ancestry")
	c.secondary_ancestry = DictUtil.get_string(d, "secondary_ancestry")
	c.background = DictUtil.get_string(d, "background")
	c.current_class = DictUtil.get_string(d, "current_class", "survivor")
	c.unlocked_classes = DictUtil.string_array(DictUtil.get_array(d, "unlocked_classes"))
	c.level = DictUtil.get_int(d, "level", 1)
	c.experience = DictUtil.get_int(d, "experience", 0)
	c.base_attributes = DictUtil.int_map(DictUtil.get_dict(d, "base_attributes"))
	c.learned_skills = DictUtil.string_array(DictUtil.get_array(d, "learned_skills"))
	c.permanent_unlocks = DictUtil.string_array(DictUtil.get_array(d, "permanent_unlocks"))
	c.persistent_lore = DictUtil.string_array(DictUtil.get_array(d, "persistent_lore"))
	c.morality = DictUtil.get_int(d, "morality", 0)
	c.morality_log = DictUtil.get_array(d, "morality_log").duplicate(true)
	c.persistent_character_flags = DictUtil.get_dict(d, "persistent_character_flags").duplicate(true)
	c.created_at_unix = DictUtil.get_int(d, "created_at_unix", 0)
	return c


## Returns a list of validation errors; empty means valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if character_id == "":
		errors.append("character_id is required")
	if character_name.strip_edges() == "":
		errors.append("character_name is required")
	if primary_ancestry == "":
		errors.append("primary_ancestry is required")
	if secondary_ancestry != "" and secondary_ancestry == primary_ancestry:
		errors.append("secondary_ancestry must differ from primary_ancestry")
	if level < 1 or level > 999:
		errors.append("level out of range: %d" % level)
	if experience < 0:
		errors.append("experience must be >= 0")
	if morality < -100 or morality > 100:
		errors.append("morality out of range: %d" % morality)
	if current_class == "" or not unlocked_classes.has(current_class):
		errors.append("current_class '%s' is not among unlocked_classes" % current_class)
	for attr in ATTRIBUTE_NAMES:
		if not base_attributes.has(attr):
			errors.append("missing attribute: " + attr)
		elif int(base_attributes[attr]) < 1 or int(base_attributes[attr]) > 100:
			errors.append("attribute out of range: %s=%s" % [attr, str(base_attributes[attr])])
	return errors
