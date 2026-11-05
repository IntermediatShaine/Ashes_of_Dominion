extends Area2D
## A harvestable resource. Interactable (layer 6). Harvesting reports to the
## ExpeditionService through the controller; the node itself only presents.

signal harvested(node_key: String, resource_id: String, amount: int)

var node_key: String = ""
var resource_id: String = ""
var amount: int = 0
var display_name: String = ""
var color: Color = Color.WHITE
var depleted: bool = false
var _font: Font
## Artwork from the visual registry ("resource.node.<resource id>"); null = code-drawn.
var _sprite: VisualSprite = null


func setup(p_key: String, p_resource_id: String, p_amount: int, resource_def: Dictionary, p_depleted: bool) -> void:
	node_key = p_key
	resource_id = p_resource_id
	amount = p_amount
	display_name = DictUtil.get_string(resource_def, "node_name", p_resource_id)
	color = Color(DictUtil.get_string(resource_def, "color", "#ffffff"))
	depleted = p_depleted


func _ready() -> void:
	_font = ThemeDB.fallback_font
	collision_layer = 0 if depleted else 32
	collision_mask = 0
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	add_child(shape)
	add_to_group("interactables")
	_sprite = VisualSprite.attach_if_registered(self, "resource.node." + resource_id)


func interaction_prompt() -> String:
	return "Gather %s (+%d %s)" % [display_name, amount, resource_id]


func interact(_player: Node) -> void:
	if depleted:
		return
	depleted = true
	collision_layer = 0
	harvested.emit(node_key, resource_id, amount)
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		_sprite.self_modulate = Color(1, 1, 1, 0.3) if depleted else Color.WHITE
		if not depleted:
			draw_string(_font, Vector2(-8, -18), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
		return
	var c := color if not depleted else Color(color, 0.25)
	draw_set_transform(Vector2(0, 8), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_polygon(PackedVector2Array([Vector2(0, -14), Vector2(10, -2), Vector2(0, 8), Vector2(-10, -2)]), PackedColorArray([c]))
	draw_polygon(PackedVector2Array([Vector2(0, -14), Vector2(10, -2), Vector2(0, -2)]), PackedColorArray([c.lightened(0.25)]))
	if not depleted:
		draw_string(_font, Vector2(-8, -18), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
