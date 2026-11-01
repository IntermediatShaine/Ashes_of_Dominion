class_name DifficultyRules
extends RefCounted
## Builds and validates difficulty configurations from data/difficulty.json.
## A configuration is a flat Dictionary {preset_id, custom: bool, <param>: value}
## frozen into UniverseState.difficulty at universe creation.


static func from_preset(preset_id: String, difficulty_table: Dictionary) -> OpResult:
	var presets := DictUtil.get_dict(difficulty_table, "presets")
	if not presets.has(preset_id):
		return OpResult.failure("Unknown difficulty preset " + preset_id)
	var cfg := {"preset_id": preset_id, "custom": false}
	var params := DictUtil.get_dict(difficulty_table, "parameters")
	for p in DictUtil.sorted_keys(params):
		cfg[p] = (presets[preset_id] as Dictionary).get(p, 0)
	return OpResult.success(cfg)


## Applies overrides on top of a preset-based config and validates ranges.
static func customize(base: Dictionary, overrides: Dictionary, difficulty_table: Dictionary) -> OpResult:
	var cfg := base.duplicate(true)
	for k in DictUtil.sorted_keys(overrides):
		cfg[k] = overrides[k]
	cfg["custom"] = true
	var errors := validate(cfg, difficulty_table)
	if not errors.is_empty():
		return OpResult.failure("; ".join(errors))
	return OpResult.success(cfg)


static func validate(cfg: Dictionary, difficulty_table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var params := DictUtil.get_dict(difficulty_table, "parameters")
	for p in DictUtil.sorted_keys(params):
		if not cfg.has(p):
			errors.append("missing difficulty parameter " + String(p))
			continue
		var spec: Dictionary = params[p]
		var v = cfg[p]
		if not (v is int or v is float):
			errors.append("difficulty parameter %s is not numeric" % String(p))
			continue
		if float(v) < DictUtil.get_float(spec, "min") or float(v) > DictUtil.get_float(spec, "max"):
			errors.append("difficulty parameter %s=%s outside [%s, %s]" % [String(p), str(v), str(spec["min"]), str(spec["max"])])
	return errors


static func is_functional(param: String, difficulty_table: Dictionary) -> bool:
	return DictUtil.get_bool(DictUtil.get_dict(DictUtil.get_dict(difficulty_table, "parameters"), param), "functional", false)


static func display_name(cfg: Dictionary, difficulty_table: Dictionary) -> String:
	var presets := DictUtil.get_dict(difficulty_table, "presets")
	var pid := DictUtil.get_string(cfg, "preset_id", "")
	var base := DictUtil.get_string(DictUtil.get_dict(presets, pid), "name", pid.capitalize())
	return base + (" (custom)" if DictUtil.get_bool(cfg, "custom", false) else "")
