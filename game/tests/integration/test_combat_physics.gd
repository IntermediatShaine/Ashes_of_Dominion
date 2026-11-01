extends TestCase
## The protagonist's melee attack through the real physics path: the hitbox
## Area2D is enabled for `attack_active_time`, overlaps are swept each physics
## frame, and each enemy is hit at most once per swing. Also covers attack
## cooldown and the player's post-hit invulnerability window.

const PlayerScript := preload("res://scripts/gameplay/exploration/player_controller.gd")
const EnemyScript := preload("res://scripts/gameplay/exploration/enemy_controller.gd")

var _saved_repo: SaveRepository
var _nodes: Array[Node] = []


func before_each() -> void:
	_saved_repo = Session.repository
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	var d := DifficultyRules.from_preset("normal", Content.table("difficulty"))
	assert_ok(Session.new_game({"name": "Swinger", "archetype_id": "village_hunter", "difficulty": d.value, "mist_enabled": false, "seed": 1357}, 1))


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Session.end_session()
	Session.repository = _saved_repo


func _spawn_player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.setup(Session.character(), -1, Content.balance("character"), Content.balance("combat"))
	p.position = pos
	p.input_enabled = false   # no Input polling; swings are triggered directly
	tree.root.add_child(p)
	_nodes.append(p)
	return p


func _spawn_enemy(enemy_id: String, pos: Vector2) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.set_script(EnemyScript)
	e.setup(enemy_id, "test:" + enemy_id + ":" + str(pos), Content.get_def("enemies", enemy_id), Session.universe().difficulty, Session.rng.stream("combat"), Content.balance("combat"), 77)
	e.position = pos
	tree.root.add_child(e)
	e.set_physics_process(false)   # stand still: this test is about the player's hitbox
	_nodes.append(e)
	return e


func test_swing_hits_enemy_in_front_once_and_not_behind() -> void:
	var player := _spawn_player(Vector2(400, 400))
	await tree.physics_frame
	player.facing = Vector2(0, 1)   # facing down
	var front := _spawn_enemy("marauder", Vector2(400, 400 + 30))
	var behind := _spawn_enemy("marauder", Vector2(400, 400 - 60))
	var hits := {"front": 0, "behind": 0}   # lambdas capture locals by value
	front.damaged.connect(func(_a, _p): hits["front"] += 1)
	behind.damaged.connect(func(_a, _p): hits["behind"] += 1)
	await tree.physics_frame
	player._try_attack()
	assert_true(player._hitbox.monitoring, "hitbox armed for the swing")
	for i in 4:
		await tree.physics_frame
	assert_eq(hits["front"], 1, "enemy in front is hit exactly once during the active window")
	assert_true(front.combatant.health < front.combatant.max_health)
	assert_eq(hits["behind"], 0, "enemy behind the player is untouched")
	assert_eq(behind.combatant.health, behind.combatant.max_health)
	# wait past the active window: sweep stops and no further hit is dealt
	for i in 12:
		await tree.physics_frame
	assert_false(player._hitbox.monitoring, "hitbox disarmed after attack_active_time")
	assert_eq(hits["front"], 1)


func test_attack_cooldown_blocks_a_second_swing() -> void:
	var player := _spawn_player(Vector2(400, 400))
	await tree.physics_frame
	player.facing = Vector2(1, 0)
	# a sturdy target: a hound can die to the first swing, which would hide the second hit
	var target := _spawn_enemy("rust_sentinel", Vector2(400 + 28, 400))
	var n := {"hits": 0, "swings": 0}
	target.damaged.connect(func(_a, _p): n["hits"] += 1)
	player.attacked.connect(func(): n["swings"] += 1)
	await tree.physics_frame
	player._try_attack()
	player._try_attack()   # still inside the active window / cooldown
	for i in 4:
		await tree.physics_frame
	player._try_attack()   # cooldown (0.45 s) not over yet
	assert_eq(n["swings"], 1, "only one swing started")
	assert_eq(n["hits"], 1)
	assert_true(target.combatant.is_alive, "target survives the first swing")
	# let the cooldown expire, then swing again
	for i in 32:
		await tree.physics_frame
	player._try_attack()
	for i in 4:
		await tree.physics_frame
	assert_eq(n["swings"], 2, "second swing after the cooldown")
	assert_eq(n["hits"], 2, "second swing lands")


func test_player_invulnerability_after_a_hit() -> void:
	var player := _spawn_player(Vector2(400, 400))
	var enemy := _spawn_enemy("marauder", Vector2(400 + 20, 400))
	await tree.physics_frame
	enemy._player = player
	var hp: int = player.combatant.health
	enemy._strike(0.0, 100.0)
	var after_first: int = player.combatant.health
	assert_true(after_first < hp, "first strike lands")
	enemy._strike(0.0, 100.0)
	assert_eq(player.combatant.health, after_first, "second strike inside the i-frame window is ignored")
	# invulnerability_after_hit is 0.35 s: wait it out
	for i in 24:
		await tree.physics_frame
	enemy._strike(0.0, 100.0)
	assert_true(player.combatant.health < after_first, "strikes land again once the window closed")


func test_dead_player_takes_no_damage_and_cannot_swing() -> void:
	var player := _spawn_player(Vector2(400, 400))
	var enemy := _spawn_enemy("marauder", Vector2(400 + 20, 400))
	await tree.physics_frame
	enemy._player = player
	var n := {"died": 0}
	player.died.connect(func(): n["died"] += 1)
	player.combatant.apply_damage(9999)
	assert_eq(n["died"], 1)
	assert_eq(player.take_hit(5, null), 0, "no damage to the dead")
	assert_eq(player.combatant.health, 0)
	# A dead controller stops moving even if input is enabled: the alive check
	# in _physics_process runs before any Input polling.
	player.input_enabled = true
	Input.action_press("move_right")
	var x := player.position.x
	for i in 5:
		await tree.physics_frame
	Input.action_release("move_right")
	assert_eq(player.velocity, Vector2.ZERO)
	assert_true(absf(player.position.x - x) < 0.01, "dead player does not move")
