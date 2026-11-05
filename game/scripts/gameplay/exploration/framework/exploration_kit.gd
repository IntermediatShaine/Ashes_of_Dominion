class_name ExplorationKit
extends RefCounted
## Pieces every explorable scene is built from — the generated expedition
## areas, the village and (later) POIs — so there is one way to spawn the
## player, one camera, one collision convention and one entity layer:
##
##   physics layers  1 world · 2 player body · 3 enemy body · 5 enemy hurtbox
##                   · 6 interactable   (see docs/architecture.md)
##   entities        a y-sorted Node2D; everything standing on the ground is
##                   its child, positioned at its feet
##   player          PlayerController: eight-direction movement, the follow
##                   camera, the interaction range and (where enabled) combat

const PlayerScript := preload("res://scripts/gameplay/exploration/player_controller.gd")
const LAYER_WORLD := 1


## The y-sorted layer actors and standing objects live in.
static func create_entities_layer(parent: Node) -> Node2D:
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	parent.add_child(entities)
	return entities


## Spawns the protagonist from the session's character and universe state.
## `world_size` bounds the follow camera. With `combat_enabled` false the
## attack input is ignored (peaceful maps such as the village).
static func spawn_player(entities: Node, position: Vector2, world_size: Vector2, combat_enabled: bool = true) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.setup(Session.character(), DictUtil.get_int(Session.universe().protagonist_condition, "health", 1), Content.balance("character"), Content.balance("combat"))
	player.combatant.attack += DictUtil.get_int(Session.universe().protagonist_condition, "equipment_attack")
	player.combat_enabled = combat_enabled
	player.position = position
	entities.add_child(player)
	player.set_camera_limits(world_size)
	return player


## One StaticBody2D on the world layer made of axis-aligned rectangles
## (pixels, in `parent`'s space).
static func build_static_body(parent: Node, rects: Array, body_name: String = "StaticCollision") -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	for r in rects:
		if not (r is Rect2):
			continue
		var rect: Rect2 = r
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		body.add_child(shape)
	return body


## The two debug-overlay lines every map scene shows (F3).
static func debug_lines(player: Node2D, cell_size: int, map_label: String) -> Array[String]:
	return [
		"player cell %s  pos %s" % [str(Vector2i(player.position / float(cell_size))), str(player.position.round())],
		map_label,
	]
