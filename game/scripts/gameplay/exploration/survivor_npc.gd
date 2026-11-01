extends Area2D
## Friendly NPC carrying one narrative decision. Talking to them opens the
## decision dialog in the HUD; resolution goes through DecisionRules.

signal talked(decision_id: String)

var decision_id: String = ""
var resolved: bool = false
var _font: Font


func setup(p_decision_id: String) -> void:
	decision_id = p_decision_id


func _ready() -> void:
	_font = ThemeDB.fallback_font
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	add_child(shape)
	add_to_group("interactables")


func interaction_prompt() -> String:
	return "Talk" if not resolved else "Nothing more to say"


func interact(_player: Node) -> void:
	if resolved:
		return
	talked.emit(decision_id)


func mark_resolved() -> void:
	resolved = true
	collision_layer = 0
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var cloak := Color(0.85, 0.75, 0.3) if not resolved else Color(0.5, 0.45, 0.3)
	draw_rect(Rect2(-7, -12, 14, 20), cloak)
	draw_circle(Vector2(0, -17), 5.5, Color(0.9, 0.78, 0.65))
	if not resolved:
		draw_string(_font, Vector2(-4, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.6))
