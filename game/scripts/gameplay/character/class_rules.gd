class_name ClassRules
extends RefCounted
## Evaluates class prerequisites. Supported prerequisite keys:
##   min_level, min_morality, max_morality, required_skills (array),
##   required_flags (array of persistent_character_flags keys that must be true)
## Adding a prerequisite kind means adding one branch here; adding a class
## means adding one JSON entry.


static func meets_prerequisites(c: CharacterState, class_def: Dictionary) -> bool:
	return unmet_prerequisites(c, class_def).is_empty()


static func unmet_prerequisites(c: CharacterState, class_def: Dictionary) -> Array[String]:
	var unmet: Array[String] = []
	var p := DictUtil.get_dict(class_def, "prerequisites")
	if p.has("min_level") and c.level < DictUtil.get_int(p, "min_level"):
		unmet.append("level %d" % DictUtil.get_int(p, "min_level"))
	if p.has("min_morality") and c.morality < DictUtil.get_int(p, "min_morality"):
		unmet.append("morality >= %d" % DictUtil.get_int(p, "min_morality"))
	if p.has("max_morality") and c.morality > DictUtil.get_int(p, "max_morality"):
		unmet.append("morality <= %d" % DictUtil.get_int(p, "max_morality"))
	for s in DictUtil.get_array(p, "required_skills"):
		if not c.learned_skills.has(String(s)):
			unmet.append("skill " + String(s))
	for f in DictUtil.get_array(p, "required_flags"):
		if not DictUtil.get_bool(c.persistent_character_flags, String(f), false):
			unmet.append("flag " + String(f))
	return unmet


## Unlocks every class whose prerequisites are met; returns newly unlocked ids.
static func refresh_unlocks(c: CharacterState, classes: Dictionary) -> Array[String]:
	var newly: Array[String] = []
	for id in DictUtil.sorted_keys(classes):
		if c.unlocked_classes.has(id):
			continue
		if meets_prerequisites(c, classes[id]):
			c.unlocked_classes.append(id)
			newly.append(id)
	return newly
