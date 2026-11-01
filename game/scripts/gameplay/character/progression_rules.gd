class_name ProgressionRules
extends RefCounted
## Experience, levels and derived combat statistics. Pure functions over
## CharacterState + the balance tables so they are testable without scenes.
##
## Formulas (documented here, numbers in data/balance.json):
##   max_health = base_health + endurance * health_per_endurance
##   attack     = base_attack + strength * attack_per_strength
##   defense    = base_defense + floor(endurance * defense_per_endurance)
##   speed      = base_move_speed + dexterity * speed_per_dexterity
##   xp to go from level L to L+1 = round(base * growth^(L-1))


static func max_health(c: CharacterState, bal: Dictionary) -> int:
	return DictUtil.get_int(bal, "base_health", 20) + c.attribute("endurance") * DictUtil.get_int(bal, "health_per_endurance", 4)


static func attack(c: CharacterState, bal: Dictionary) -> int:
	return DictUtil.get_int(bal, "base_attack", 2) + c.attribute("strength") * DictUtil.get_int(bal, "attack_per_strength", 1)


static func defense(c: CharacterState, bal: Dictionary) -> int:
	return DictUtil.get_int(bal, "base_defense", 0) + int(floor(c.attribute("endurance") * DictUtil.get_float(bal, "defense_per_endurance", 0.5)))


static func move_speed(c: CharacterState, bal: Dictionary) -> float:
	return DictUtil.get_float(bal, "base_move_speed", 130.0) + c.attribute("dexterity") * DictUtil.get_float(bal, "speed_per_dexterity", 4.0)


static func xp_for_next_level(level: int, prog: Dictionary) -> int:
	var base := DictUtil.get_float(prog, "xp_per_level_base", 20.0)
	var growth := DictUtil.get_float(prog, "xp_per_level_growth", 1.45)
	return int(round(base * pow(growth, level - 1)))


## Adds experience and applies level-ups. Returns the number of levels gained.
## `growth` is the archetype's per-level attribute growth map.
static func add_experience(c: CharacterState, amount: int, prog: Dictionary, growth: Dictionary) -> int:
	if amount <= 0:
		return 0
	c.experience += amount
	var max_level := DictUtil.get_int(prog, "max_level", 20)
	var gained := 0
	while c.level < max_level and c.experience >= xp_for_next_level(c.level, prog):
		c.experience -= xp_for_next_level(c.level, prog)
		c.level += 1
		gained += 1
		for k in DictUtil.sorted_keys(growth):
			c.base_attributes[k] = clampi(c.attribute(k) + int(growth[k]), 1, 100)
	return gained
