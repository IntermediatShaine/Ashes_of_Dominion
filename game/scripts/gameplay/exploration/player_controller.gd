extends CharacterBody2D
## The protagonist in an explorable area: eight-direction movement, facing,
## a single melee attack, interaction detection, and damage intake.
## All numbers come from the character state + balance tables; all damage
## math goes through CombatRules.

signal health_changed(current: int, maximum: int)
signal died()
signal interact_target_changed(target: Node)
signal attacked()

const DIAG := 0.70710678
const DIRS_8: Array[Vector2] = [
	Vector2(1, 0), Vector2(DIAG, DIAG), Vector2(0, 1), Vector2(-DIAG, DIAG),
	Vector2(-1, 0), Vector2(-DIAG, -DIAG), Vector2(0, -1), Vector2(DIAG, -DIAG),
]

var combatant: Combatant
var move_speed: float = 130.0
var facing: Vector2 = Vector2(0, 1)
var input_enabled: bool = true

var _attack_cooldown: float = 0.45
var _attack_active_time: float = 0.12
var _attack_reach: float = 30.0
var _attack_width: float = 26.0
var _invuln_time: float = 0.35
var _cooldown_left: float = 0.0
var _active_left: float = 0.0
var _invuln_left: float = 0.0
var _hit_this_swing: Array = []
var _hitbox: Area2D
var _hitbox_shape: CollisionShape2D
var _interact_range: Area2D
var _interact_target: Node = null
var _flash: float = 0.0
var _combat_rules: Dictionary = {}
var _camera: Camera2D


func setup(character: CharacterState, current_health: int, char_balance: Dictionary, combat_rules: Dictionary) -> void:
	combatant = Combatant.create("protagonist", ProgressionRules.max_health(character, char_balance), ProgressionRules.attack(character, char_balance), ProgressionRules.defense(character, char_balance), current_health)
	move_speed = ProgressionRules.move_speed(character, char_balance)
	_attack_cooldown = DictUtil.get_float(char_balance, "attack_cooldown", 0.45)
	_attack_active_time = DictUtil.get_float(char_balance, "attack_active_time", 0.12)
	_attack_reach = DictUtil.get_float(char_balance, "attack_reach", 30.0)
	_attack_width = DictUtil.get_float(char_balance, "attack_width", 26.0)
	_invuln_time = DictUtil.get_float(char_balance, "invulnerability_after_hit", 0.35)
	_combat_rules = combat_rules
	combatant.health_changed.connect(func(c, m): health_changed.emit(c, m))
	combatant.died.connect(func(): died.emit())


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4   # world + enemy bodies
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9
	shape.shape = circle
	shape.position = Vector2(0, 4)
	add_child(shape)

	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 16   # enemy hurtboxes (layer 5)
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	_hitbox_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_attack_reach, _attack_width)
	_hitbox_shape.shape = rect
	_hitbox.add_child(_hitbox_shape)
	add_child(_hitbox)

	_interact_range = Area2D.new()
	_interact_range.collision_layer = 0
	_interact_range.collision_mask = 32   # interactables (layer 6)
	var ir := CollisionShape2D.new()
	var ic := CircleShape2D.new()
	ic.radius = 34
	ir.shape = ic
	_interact_range.add_child(ir)
	add_child(_interact_range)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()
	add_to_group("player")


func camera() -> Camera2D:
	return _camera


func set_camera_limits(size: Vector2) -> void:
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_invuln_left = maxf(0.0, _invuln_left - delta)
	_flash = maxf(0.0, _flash - delta)
	if _active_left > 0.0:
		_active_left -= delta
		_sweep_hitbox()
		if _active_left <= 0.0:
			_hitbox.monitoring = false
	if not input_enabled or not combatant.is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.0:
		input = input.normalized()   # equal speed on diagonals
		facing = _snap8(input)
	velocity = input * move_speed
	move_and_slide()
	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("interact") and _interact_target != null and is_instance_valid(_interact_target):
		_interact_target.interact(self)
	_update_interact_target()
	queue_redraw()


func _snap8(v: Vector2) -> Vector2:
	var best: Vector2 = DIRS_8[0]
	var best_dot := -INF
	for d in DIRS_8:
		var dot := d.dot(v)
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


func _try_attack() -> void:
	if _cooldown_left > 0.0 or _active_left > 0.0:
		return
	_cooldown_left = _attack_cooldown
	_active_left = _attack_active_time
	_hit_this_swing.clear()
	_hitbox.position = facing * (_attack_reach * 0.5 + 8.0)
	_hitbox.rotation = facing.angle()
	_hitbox.monitoring = true
	attacked.emit()


func _sweep_hitbox() -> void:
	for area in _hitbox.get_overlapping_areas():
		var target := area.get_parent()
		if target == null or _hit_this_swing.has(target) or not target.has_method("take_hit"):
			continue
		_hit_this_swing.append(target)
		target.take_hit(self)


## Called by enemies. Returns damage dealt (0 if invulnerable or dead).
func take_hit(attacker_attack: int, rng: RngStream) -> int:
	if _invuln_left > 0.0 or not combatant.is_alive:
		return 0
	var dmg := CombatRules.resolve_damage(attacker_attack, combatant.defense, _combat_rules, rng)
	var dealt := combatant.apply_damage(dmg)
	_invuln_left = _invuln_time
	_flash = 0.2
	return dealt


func _update_interact_target() -> void:
	var best: Node = null
	var best_d := INF
	for area in _interact_range.get_overlapping_areas():
		if not area.has_method("interact") or not area.has_method("interaction_prompt"):
			continue
		var d := global_position.distance_to(area.global_position)
		if d < best_d:
			best_d = d
			best = area
	if best != _interact_target:
		_interact_target = best
		interact_target_changed.emit(best)


func _draw() -> void:
	# shadow
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var body := Color(0.35, 0.55, 0.85)
	if _flash > 0.0:
		body = Color(1, 0.4, 0.4)
	elif _invuln_left > 0.0 and int(_invuln_left * 20) % 2 == 0:
		body = body.lightened(0.4)
	if not combatant.is_alive:
		body = Color(0.3, 0.3, 0.35)
	# legs / body / head: simple stacked shapes with a readable silhouette
	draw_rect(Rect2(-6, -2, 12, 14), body.darkened(0.25))
	draw_rect(Rect2(-7, -14, 14, 14), body)
	draw_circle(Vector2(0, -18), 6, Color(0.9, 0.78, 0.65))
	draw_rect(Rect2(-6, -24, 12, 5), Color(0.45, 0.3, 0.2))
	# facing marker
	var tip := facing * 16
	draw_line(Vector2(0, -6), tip + Vector2(0, -6), Color(1, 1, 1, 0.5), 2.0)
	# attack arc
	if _active_left > 0.0:
		var a := facing.angle()
		draw_arc(Vector2(0, -4), _attack_reach + 4, a - 0.7, a + 0.7, 10, Color(1, 0.9, 0.6, 0.9), 3.0)
