extends Area2D
## The way home. Interacting ends the expedition as "returned".

signal exit_requested()


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)
	add_to_group("interactables")


func interaction_prompt() -> String:
	return "Return to Emberfall"


func interact(_player: Node) -> void:
	exit_requested.emit()
