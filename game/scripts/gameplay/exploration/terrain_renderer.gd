extends Node2D
## Draws a WildernessMap with placeholder pixel-style tiles and builds the
## static collision for non-walkable cells. Purely presentational: the map
## data stays authoritative and lives in WildernessMap.
##
## 2.5D cues: obstacles get a darker "base" strip and a drop shadow so they
## read as standing objects rather than flat squares; water gets a lighter
## rim. Real pixel-art tiles can replace _draw() without touching gameplay.

var map: WildernessMap
var palette: Dictionary = {}
var _body: StaticBody2D


func setup(p_map: WildernessMap, biome: Dictionary) -> void:
	map = p_map
	palette = DictUtil.get_dict(biome, "palette")
	_build_collision()
	queue_redraw()


func _color(key: String, fallback: Color) -> Color:
	return Color(DictUtil.get_string(palette, key, "")) if palette.has(key) else fallback


func _build_collision() -> void:
	if _body:
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var cs := float(map.cell_size)
	# Merge horizontal runs of blocked cells into single rectangles.
	for y in map.height:
		var x := 0
		while x < map.width:
			if map.is_walkable(x, y):
				x += 1
				continue
			var start := x
			while x < map.width and not map.is_walkable(x, y):
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((x - start) * cs, cs)
			shape.shape = rect
			shape.position = Vector2((start + (x - start) * 0.5) * cs, (y + 0.5) * cs)
			_body.add_child(shape)


func _draw() -> void:
	if map == null:
		return
	var cs := float(map.cell_size)
	var ground := _color("ground", Color(0.35, 0.4, 0.22))
	var ground_alt := _color("ground_alt", ground.darkened(0.08))
	var obstacle := _color("obstacle", Color(0.2, 0.18, 0.16))
	var water := _color("water", Color(0.18, 0.3, 0.38))
	var path := _color("path", Color(0.5, 0.45, 0.33))
	# pass 1: floor
	for y in map.height:
		for x in map.width:
			var t := map.get_terrain(x, y)
			var r := Rect2(x * cs, y * cs, cs, cs)
			match t:
				WildernessMap.Terrain.GROUND:
					draw_rect(r, ground)
				WildernessMap.Terrain.GROUND_ALT:
					draw_rect(r, ground_alt)
					draw_rect(Rect2(r.position + Vector2(cs * 0.3, cs * 0.55), Vector2(3, 3)), ground_alt.lightened(0.12))
				WildernessMap.Terrain.PATH:
					draw_rect(r, path)
				WildernessMap.Terrain.WATER:
					draw_rect(r, water)
					draw_rect(Rect2(r.position + Vector2(4, 6), Vector2(cs * 0.4, 2)), water.lightened(0.2))
				_:
					draw_rect(r, ground)
	# pass 2: standing obstacles with shadow + base
	for y in map.height:
		for x in map.width:
			if map.get_terrain(x, y) != WildernessMap.Terrain.OBSTACLE:
				continue
			var r := Rect2(x * cs, y * cs, cs, cs)
			draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.28))
			draw_rect(Rect2(r.position + Vector2(2, -6), Vector2(cs - 4, cs + 2)), obstacle)
			draw_rect(Rect2(r.position + Vector2(2, cs - 8), Vector2(cs - 4, 4)), obstacle.darkened(0.35))
			draw_rect(Rect2(r.position + Vector2(6, -2), Vector2(cs * 0.3, 3)), obstacle.lightened(0.18))
	# spawn / exit markers
	draw_circle(map.cell_center(map.spawn), 6, Color(1, 1, 1, 0.25))
	var ex := map.cell_center(map.exit)
	draw_rect(Rect2(ex - Vector2(cs * 0.5, cs * 0.5), Vector2(cs, cs)), Color(0.95, 0.8, 0.4, 0.25))
	draw_arc(ex, cs * 0.45, 0, TAU, 20, Color(0.95, 0.8, 0.4, 0.9), 2.0)
