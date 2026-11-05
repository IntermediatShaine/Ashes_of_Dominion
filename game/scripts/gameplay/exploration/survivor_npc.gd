extends Area2D
## NPC carrying one narrative decision (a stranded survivor, a Crown patrol…).
## Talking to them opens the decision dialog in the HUD; resolution goes
## through DecisionRules. Colour and prompt come from the decision definition.

signal talked(decision_id: String)

var decision_id: String = ""
var resolved: bool = false
var _font: Font
var _color: Color = Color(0.85, 0.75, 0.3)
var _prompt: String = "Talk"
## Artwork from the visual registry ("actor.npc.<decision id>"); null = code-drawn.
var _sprite: VisualSprite = null


func setup(p_decision_id: String, definition: Dictionary = {}) -> void:
	decision_id = p_decision_id
	if definition.has("npc_color"):
		_color = Color(DictUtil.get_string(definition, "npc_color", "#d9bf4d"))
	_prompt = DictUtil.get_string(definition, "npc_prompt", "Talk")


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
	_sprite = VisualSprite.attach_if_registered(self, "actor.npc." + decision_id)


func interaction_prompt() -> String:
	return _prompt if not resolved else "Nothing more to say"


func interact(_player: Node) -> void:
	if resolved:
		return
	talked.emit(decision_id)


func mark_resolved() -> void:
	resolved = true
	collision_layer = 0
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		_sprite.self_modulate = Color(0.55, 0.55, 0.55) if resolved else Color.WHITE
		if not resolved:
			draw_string(_font, Vector2(-4, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.6))
		return
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var cloak := _color if not resolved else _color.darkened(0.45)
	draw_rect(Rect2(-7, -12, 14, 20), cloak)
	draw_circle(Vector2(0, -17), 5.5, Color(0.9, 0.78, 0.65))
	if not resolved:
		draw_string(_font, Vector2(-4, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.6))
