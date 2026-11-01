extends TestCase
## Enemy state machine driven by real physics frames against a fake player.
## Covers every transition of enemy_controller.gd:
##   PATROL/IDLE -> CHASE -> WINDUP -> (strike) -> COOLDOWN -> CHASE -> PATROL/IDLE,
##   take_hit aggro, death, and the rule that patrol wandering never draws
##   from the universe's persisted "combat" stream.

const EnemyScript := preload("res://scripts/gameplay/exploration/enemy_controller.gd")

## Minimal stand-in for the protagonist: what enemy_controller.gd actually touches.
class FakePlayer:
	extends Node2D
	var combatant: Combatant = Combatant.create("fake_player", 50, 1, 0)
	var hits: Array[int] = []

	func take_hit(attacker_attack: int, _rng: RngStream) -> int:
		hits.append(attacker_attack)
		return combatant.apply_damage(attacker_attack)


var _nodes: Array[Node] = []
var _difficulty: Dictionary = {}


func before_each() -> void:
	_difficulty = DifficultyRules.from_preset("normal", Content.table("difficulty")).value


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _spawn_player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.position = pos
	p.add_to_group("player")
	tree.root.add_child(p)
	_nodes.append(p)
	return p


func _spawn_enemy(enemy_id: String, pos: Vector2, combat_rng: RngStream, seed_value: int = 4242) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.set_script(EnemyScript)
	e.setup(enemy_id, "test:" + enemy_id, Content.get_def("enemies", enemy_id), _difficulty, combat_rng, Content.balance("combat"), seed_value)
	e.position = pos
	tree.root.add_child(e)
	_nodes.append(e)
	return e


## Waits up to `max_frames` physics frames for `cond` to become true.
func _await_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


func test_patrol_detects_player_and_chases() -> void:
	var rng := RngStream.new("combat", 1)
	var enemy := _spawn_enemy("marauder", Vector2(300, 300), rng)
	await tree.physics_frame
	assert_eq(enemy.state, enemy.State.PATROL, "marauder starts patrolling")
	# player outside detect radius (170): no reaction for a while
	var player := _spawn_player(Vector2(300 + 400, 300))
	await _await_until(func(): return enemy.state != enemy.State.PATROL, 30)
	assert_eq(enemy.state, enemy.State.PATROL, "out of range player is ignored")
	# inside detect radius: chase
	player.position = Vector2(300 + 100, 300)
	var chased: bool = await _await_until(func(): return enemy.state == enemy.State.CHASE, 30)
	assert_true(chased, "enemy switches to CHASE when the player is within detect radius")


func test_idle_behaviour_waits_until_detected() -> void:
	var rng := RngStream.new("combat", 2)
	var enemy := _spawn_enemy("mire_lurker", Vector2(300, 300), rng)
	await tree.physics_frame
	assert_eq(enemy.state, enemy.State.IDLE, "lurker is an idle-behaviour enemy")
	var start := enemy.position
	_spawn_player(Vector2(300 + 300, 300))   # detect radius is 130
	for i in 30:
		await tree.physics_frame
	assert_eq(enemy.state, enemy.State.IDLE)
	assert_true(enemy.position.distance_to(start) < 0.5, "idle enemy does not wander")


func test_chase_windup_strike_cooldown_cycle() -> void:
	var rng := RngStream.new("combat", 3)
	var enemy := _spawn_enemy("marauder", Vector2(300, 300), rng)
	var player := _spawn_player(Vector2(300 + 120, 300))
	await tree.physics_frame
	var hp_before := player.combatant.health
	# 120 px at 85 px/s: a few dozen frames to close to attack_range (30)
	var wound_up: bool = await _await_until(func(): return enemy.state == enemy.State.WINDUP, 240)
	assert_true(wound_up, "enemy reaches WINDUP after closing in")
	assert_true(enemy.position.distance_to(player.position) <= float(enemy.stats["attack_range"]) + 1.0, "in reach when winding up")
	assert_eq(player.hits.size(), 0, "no damage during windup")
	# windup (0.35 s) then strike
	var struck: bool = await _await_until(func(): return player.hits.size() > 0, 60)
	assert_true(struck, "strike lands after windup")
	assert_eq(player.hits[0], enemy.combatant.attack, "strike uses the enemy's scaled attack")
	assert_true(player.combatant.health < hp_before)
	assert_eq(enemy.state, enemy.State.COOLDOWN, "COOLDOWN right after the strike")
	# cooldown (1.1 s) then back to chase, and a second strike follows
	var chasing: bool = await _await_until(func(): return enemy.state != enemy.State.COOLDOWN, 120)
	assert_true(chasing, "cooldown ends")
	assert_true(enemy.state == enemy.State.CHASE or enemy.state == enemy.State.WINDUP)
	var struck_again: bool = await _await_until(func(): return player.hits.size() >= 2, 120)
	assert_true(struck_again, "the cycle repeats")


func test_strike_misses_when_player_stepped_away() -> void:
	var rng := RngStream.new("combat", 4)
	var enemy := _spawn_enemy("marauder", Vector2(300, 300), rng)
	var player := _spawn_player(Vector2(300 + 60, 300))
	await tree.physics_frame
	var wound_up: bool = await _await_until(func(): return enemy.state == enemy.State.WINDUP, 120)
	assert_true(wound_up)
	# dodge during the windup: beyond reach + 10 px tolerance
	player.position = enemy.position + Vector2(float(enemy.stats["attack_range"]) + 40.0, 0)
	var resolved: bool = await _await_until(func(): return enemy.state == enemy.State.COOLDOWN, 60)
	assert_true(resolved, "windup still resolves")
	assert_eq(player.hits.size(), 0, "a dodged strike deals nothing")


func test_chase_breaks_off_when_player_escapes() -> void:
	var rng := RngStream.new("combat", 5)
	var enemy := _spawn_enemy("marauder", Vector2(300, 300), rng)
	var player := _spawn_player(Vector2(300 + 100, 300))
	var chased: bool = await _await_until(func(): return enemy.state == enemy.State.CHASE, 30)
	assert_true(chased)
	player.position = Vector2(300 + 700, 300)   # > detect * 1.6
	var gave_up: bool = await _await_until(func(): return enemy.state == enemy.State.PATROL, 30)
	assert_true(gave_up, "patrol enemy returns to PATROL when the player is far away")
	assert_eq(enemy.velocity, Vector2.ZERO)


func test_take_hit_aggros_damages_and_kills_once() -> void:
	var rng := RngStream.new("combat", 6)
	var enemy := _spawn_enemy("ashen_hound", Vector2(300, 300), rng)
	var attacker := _spawn_player(Vector2(300 - 20, 300))
	attacker.combatant.attack = 3
	await tree.physics_frame
	# keep physics off so the chase does not move it while we assert positions
	enemy.set_physics_process(false)
	# lambdas capture locals by value, so counters live in a Dictionary
	var seen := {"defeated": 0, "damaged": 0}
	enemy.defeated.connect(func(_e): seen["defeated"] += 1)
	enemy.damaged.connect(func(amount, _pos): seen["damaged"] += amount)
	var hp: int = enemy.combatant.health
	enemy.take_hit(attacker)
	assert_true(enemy.combatant.health < hp, "damage applied")
	assert_eq(enemy.state, enemy.State.CHASE, "a hit from patrol provokes a chase")
	assert_true(enemy.velocity.x > 0.0, "knockback pushes away from the attacker")
	var guard := 0
	while enemy.combatant.is_alive and guard < 50:
		enemy.take_hit(attacker)
		guard += 1
	assert_false(enemy.combatant.is_alive)
	assert_eq(enemy.state, enemy.State.DEAD)
	assert_eq(seen["defeated"], 1, "defeated emitted exactly once")
	assert_eq(seen["damaged"], enemy.combatant.max_health, "damage reported sums to max health")
	assert_eq(enemy.collision_layer, 0, "corpse no longer collides")
	enemy.take_hit(attacker)
	assert_eq(seen["defeated"], 1, "hits on a corpse are ignored")
	assert_eq(seen["damaged"], enemy.combatant.max_health)


func test_patrol_is_deterministic_and_leaves_combat_stream_untouched() -> void:
	var rng := RngStream.new("combat", 7)
	var draws_before := rng.draw_count
	var a := _spawn_enemy("marauder", Vector2(200, 200), rng, 99)
	var b := _spawn_enemy("marauder", Vector2(200, 200), rng, 99)
	a.collision_layer = 0
	a.collision_mask = 0
	b.collision_layer = 0
	b.collision_mask = 0
	# the first wander target is picked after 0.5–2.0 s, so give it 4 s
	for i in 240:
		await tree.physics_frame
	assert_eq(a.state, a.State.PATROL)
	assert_true(a.position.distance_to(Vector2(200, 200)) > 1.0, "patrol actually wandered")
	assert_true(a.position.distance_to(b.position) < 0.01, "same spawn seed -> same wandering")
	assert_eq(rng.draw_count, draws_before, "patrol never draws from the persisted combat stream")
