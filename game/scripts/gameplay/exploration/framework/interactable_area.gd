class_name InteractableArea
extends Area2D
## Base for anything the player can walk up to and use with [E].
##
## The contract the player controller relies on (and that the older
## expedition objects — resource nodes, the exit zone, decision NPCs — already
## follow by hand): an Area2D on physics layer 6 ("interactable") with
## `interaction_prompt()` and `interact(player)`, in the group
## "interactables". This class packages it so new objects only set a prompt
## and a shape and connect `interacted`.
##
## The shape is gameplay data (from a layout), never derived from artwork.

signal interacted(player: Node)

const LAYER_INTERACTABLE := 32

## Shown by the HUD as "[E] <prompt>".
var prompt: String = ""
## Free-form id of what this area stands for (site id, exit id…).
var target_id: String = ""
var enabled: bool = true:
	set(value):
		enabled = value
		collision_layer = LAYER_INTERACTABLE if value else 0

var _shape: CollisionShape2D


func _init() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactables")


## Rectangular interaction zone of `size` pixels centred on `centre`
## (relative to this node).
func set_rect(size: Vector2, centre: Vector2 = Vector2.ZERO) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	_set_shape(rect, centre)


func set_circle(radius: float, centre: Vector2 = Vector2.ZERO) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	_set_shape(circle, centre)


func interaction_prompt() -> String:
	return prompt


func interact(player: Node) -> void:
	if enabled:
		interacted.emit(player)


func _set_shape(shape: Shape2D, centre: Vector2) -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	_shape.shape = shape
	_shape.position = centre
