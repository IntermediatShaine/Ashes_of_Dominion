class_name CombatRules
extends RefCounted
## Damage rules. Deliberately simple until balancing data exists:
##
##   base   = attack - floor(defense * defense_scale)
##   damage = max(min_damage, round(base * (1 + v)))   where v ∈ [-variance, +variance]
##
## The variance roll always comes from the universe's "combat" stream so that
## combat never perturbs generation, rewards or events. Passing `rng = null`
## yields the deterministic mean (used by tests and previews).


static func resolve_damage(attack: int, defense: int, rules: Dictionary, rng: RngStream) -> int:
	var min_damage := DictUtil.get_int(rules, "min_damage", 1)
	var scale := DictUtil.get_float(rules, "defense_scale", 0.5)
	var variance := DictUtil.get_float(rules, "damage_variance", 0.2)
	var base := float(attack) - floorf(float(defense) * scale)
	var v := 0.0
	if rng != null and variance > 0.0:
		v = rng.randf_range(-variance, variance)
	return maxi(min_damage, int(round(base * (1.0 + v))))


## Difficulty-scaled enemy stats from a definition. Rounds up so a multiplier
## never produces a zero-health or zero-damage enemy.
static func scaled_enemy_stats(enemy_def: Dictionary, difficulty: Dictionary) -> Dictionary:
	var hp_mult := DictUtil.get_float(difficulty, "enemy_health_multiplier", 1.0)
	var dmg_mult := DictUtil.get_float(difficulty, "enemy_damage_multiplier", 1.0)
	return {
		"max_health": maxi(1, int(ceil(DictUtil.get_int(enemy_def, "max_health", 1) * hp_mult))),
		"attack": maxi(1, int(ceil(DictUtil.get_int(enemy_def, "attack", 1) * dmg_mult))),
		"defense": DictUtil.get_int(enemy_def, "defense", 0),
		"move_speed": DictUtil.get_float(enemy_def, "move_speed", 80.0),
		"detect_radius": DictUtil.get_float(enemy_def, "detect_radius", 150.0),
		"attack_range": DictUtil.get_float(enemy_def, "attack_range", 30.0),
		"attack_windup": DictUtil.get_float(enemy_def, "attack_windup", 0.4),
		"attack_cooldown": DictUtil.get_float(enemy_def, "attack_cooldown", 1.0),
		"experience": DictUtil.get_int(enemy_def, "experience", 1),
	}
