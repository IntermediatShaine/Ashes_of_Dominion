extends CharacterBody2D
## One enemy archetype instance driven by a small state machine:
## IDLE/PATROL -> CHASE -> WINDUP -> STRIKE -> COOLDOWN -> ... -> DEAD.
## Stats come from the enemy definition scaled by difficulty (CombatRules);
## patrol wandering uses a private deterministic stream seeded from the
## spawn key so it never touches the universe's persisted streams.

signal defeated(enemy: Node)
signal damaged(amount: int, position: Vector2)

enum State { IDLE, PATROL, CHASE, WINDUP, COOLDOWN, DEAD }

var enemy_id: String = ""
var spawn_key: String = ""
var definition: Dictionary = {}
var stats: Dictionary = {}
var combatant: Combatant
var state: State = State.IDLE
var combat_rng: RngStream
var combat_rules: Dictionary = {}

var _home: Vector2
var _patrol_target: Vector2
var _timer: float = 0.0
var _player: Node2D = null
var _local_rng: RngStream
var _flash: float = 0.0
var _hurtbox: Area2D
var _fade: float = 1.0
var _color: Color = Color.RED
var _size: float = 10.0
var _behaviour: String = "patrol"
## Body artwork from the visual registry ("actor.enemy.<enemy id>"); null = code-drawn.
var _sprite: VisualSprite = null


func setup(p_enemy_id: String, p_spawn_key: String, p_definition: Dictionary, difficulty: Dictionary, p_combat_rng: RngStream, p_combat_rules: Dictionary, seed_value: int) -> void:
	enemy_id = p_enemy_id
	spawn_key = p_spawn_key
	definition = p_definition
	stats = CombatRules.scaled_enemy_stats(p_definition, difficulty)
	combatant = Combatant.create(p_spawn_key, int(stats["max_health"]), int(stats["attack"]), int(stats["defense"]))
	combat_rng = p_combat_rng
	combat_rules = p_combat_rules
	_local_rng = RngStream.new("enemy:" + p_spawn_key, seed_value)
	_color = Color(DictUtil.get_string(p_definition, "color", "#b03a2e"))
	_size = DictUtil.get_float(p_definition, "size", 10.0)
	_behaviour = DictUtil.get_string(p_definition, "behaviour", "patrol")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _size * 0.8
	shape.shape = circle
	shape.position = Vector2(0, 2)
	add_child(shape)
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = _size + 4
	hs.shape = hc
	hs.position = Vector2(0, -4)
	_hurtbox.add_child(hs)
	add_child(_hurtbox)
	_home = global_position
	_patrol_target = _home
	state = State.PATROL if _behaviour == "patrol" else State.IDLE
	_timer = _local_rng.randf_range(0.5, 2.0)
	add_to_group("enemies")
	_sprite = VisualSprite.attach_if_registered(self, "actor.enemy." + enemy_id)


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if state == State.DEAD:
		_fade = maxf(0.0, _fade - delta * 1.5)
		if _fade <= 0.0:
			queue_free()
		queue_redraw()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var dist := INF
	if _player != null and _player.combatant.is_alive:
		dist = global_position.distance_to(_player.global_position)
	var detect: float = stats["detect_radius"]
	var reach: float = stats["attack_range"]
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if dist < detect:
				state = State.CHASE
		State.PATROL:
			_timer -= delta
			if _timer <= 0.0:
				_patrol_target = _home + Vector2(_local_rng.randf_range(-90, 90), _local_rng.randf_range(-90, 90))
				_timer = _local_rng.randf_range(1.5, 3.5)
			var to_target := _patrol_target - global_position
			velocity = to_target.normalized() * float(stats["move_speed"]) * 0.5 if to_target.length() > 6.0 else Vector2.ZERO
			if dist < detect:
				state = State.CHASE
		State.CHASE:
			if dist > detect * 1.6:
				state = State.PATROL if _behaviour == "patrol" else State.IDLE
				velocity = Vector2.ZERO
			elif dist <= reach:
				state = State.WINDUP
				_timer = float(stats["attack_windup"])
				velocity = Vector2.ZERO
			else:
				velocity = (_player.global_position - global_position).normalized() * float(stats["move_speed"])
		State.WINDUP:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				_strike(dist, reach)
				state = State.COOLDOWN
				_timer = float(stats["attack_cooldown"])
		State.COOLDOWN:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
	move_and_slide()
	queue_redraw()


func _strike(dist: float, reach: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if dist <= reach + 10.0:
		_player.take_hit(combatant.attack, combat_rng)


## Called by the player's hitbox sweep.
func take_hit(attacker: Node) -> void:
	if state == State.DEAD:
		return
	var attacker_combatant: Combatant = attacker.combatant
	var dmg := CombatRules.resolve_damage(attacker_combatant.attack, combatant.defense, combat_rules, combat_rng)
	var dealt := combatant.apply_damage(dmg)
	_flash = 0.15
	damaged.emit(dealt, global_position)
	# knockback
	var attacker_pos: Vector2 = attacker.global_position
	var push: Vector2 = (global_position - attacker_pos).normalized() * 60.0
	velocity = push
	if not combatant.is_alive:
		_die()
	elif state == State.IDLE or state == State.PATROL:
		state = State.CHASE


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	_hurtbox.collision_layer = 0
	velocity = Vector2.ZERO
	defeated.emit(self)


func _draw() -> void:
	var alpha := _fade if state == State.DEAD else 1.0
	draw_set_transform(Vector2(0, _size * 0.9), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, _size, Color(0, 0, 0, 0.3 * alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var c := _color
	if _flash > 0.0:
		c = Color.WHITE
	elif state == State.WINDUP:
		c = c.lightened(0.35)
	c.a = alpha
	if _sprite != null:
		# Registry artwork replaces the body; state shows as a tint.
		var tint := Color(1, 1, 1, alpha)
		if _flash > 0.0:
			tint = Color(1.6, 1.6, 1.6, alpha)
		elif state == State.WINDUP:
			tint = Color(1.25, 1.1, 1.1, alpha)
		_sprite.self_modulate = tint
		if state == State.DEAD:
			return
	elif state == State.DEAD:
		draw_set_transform(Vector2(0, _size * 0.6), 0, Vector2(1.2, 0.35))
		draw_circle(Vector2.ZERO, _size, c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	else:
		draw_circle(Vector2(0, -_size * 0.4), _size, c)
		draw_rect(Rect2(-_size * 0.6, -_size * 0.1, _size * 1.2, _size * 0.9), c.darkened(0.3))
		# eyes
		var eye := Color(1, 0.95, 0.6, alpha) if state != State.CHASE and state != State.WINDUP else Color(1, 0.3, 0.2, alpha)
		draw_circle(Vector2(-_size * 0.35, -_size * 0.55), 1.8, eye)
		draw_circle(Vector2(_size * 0.35, -_size * 0.55), 1.8, eye)
	if state == State.WINDUP:
		draw_arc(Vector2(0, -_size * 0.4), _size + 6, 0, TAU, 16, Color(1, 0.3, 0.2, 0.8), 2.0)
	# health bar
	if combatant.health < combatant.max_health:
		var w := _size * 2.2
		draw_rect(Rect2(-w * 0.5, -_size - 12, w, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, -_size - 12, w * float(combatant.health) / float(combatant.max_health), 4), Color(0.85, 0.25, 0.2))
