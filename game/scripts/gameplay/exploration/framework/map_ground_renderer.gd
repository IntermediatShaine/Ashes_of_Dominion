extends Node2D
## Draws the ground of a MapDefinition: one tiled base visual plus rectangular
## patches (paths, packed earth), all looked up by visual id. Purely
## presentational; redraws itself when the visual registry changes.

var map_def: MapDefinition


func setup(p_map_def: MapDefinition) -> void:
	map_def = p_map_def
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if not Visuals.registry_changed.is_connected(queue_redraw):
		Visuals.registry_changed.connect(queue_redraw)
	queue_redraw()


func _exit_tree() -> void:
	if Visuals.registry_changed.is_connected(queue_redraw):
		Visuals.registry_changed.disconnect(queue_redraw)


func _draw() -> void:
	if map_def == null:
		return
	_fill(map_def.ground_base, map_def.world_rect())
	var cs := float(map_def.cell_size)
	for patch in map_def.ground_patches:
		var cells: Rect2i = patch["rect"]
		_fill(String(patch["visual"]), Rect2(Vector2(cells.position) * cs, Vector2(cells.size) * cs))


func _fill(visual_id: String, rect: Rect2) -> void:
	var v := Visuals.resolve(visual_id)
	var tex: Texture2D = v["texture"]
	if tex == null:
		draw_rect(rect, Color(0.3, 0.3, 0.3))
		return
	var tint: Color = v["modulate"]
	draw_texture_rect(tex, rect, true, tint)
