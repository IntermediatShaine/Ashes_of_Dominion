class_name Combatant
extends RefCounted
## Runtime combat state for one participant (player or enemy). Scene nodes
## own a Combatant and delegate all number-crunching to it; nothing here
## touches the scene tree, so it is unit-testable.

signal health_changed(current: int, maximum: int)
signal died()

var combatant_id: String = ""
var max_health: int = 1
var health: int = 1
var attack: int = 1
var defense: int = 0
var is_alive: bool = true


static func create(id: String, p_max_health: int, p_attack: int, p_defense: int, p_health: int = -1) -> Combatant:
	var c := Combatant.new()
	c.combatant_id = id
	c.max_health = maxi(1, p_max_health)
	c.health = clampi(p_health if p_health >= 0 else c.max_health, 0, c.max_health)
	c.attack = p_attack
	c.defense = p_defense
	c.is_alive = c.health > 0
	return c


## Applies damage already resolved by CombatRules. Returns the damage applied.
func apply_damage(amount: int) -> int:
	if not is_alive:
		return 0
	var dealt := clampi(amount, 0, health)
	health -= dealt
	health_changed.emit(health, max_health)
	if health <= 0:
		is_alive = false
		died.emit()
	return dealt


func heal_full() -> void:
	health = max_health
	is_alive = true
	health_changed.emit(health, max_health)
