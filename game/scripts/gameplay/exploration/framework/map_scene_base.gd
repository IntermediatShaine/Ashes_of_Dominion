class_name MapSceneBase
extends Node2D
## Base scene for hand-authored explorable maps: the village now, POIs later.
##
## A subclass names its layout and adds what is special about it; everything
## common is here and is the same code the expedition areas use for the
## player (ExplorationKit / PlayerController) and interactions
## (InteractableArea protocol):
##
##   entering   the player appears where MapTravelService says — the entry
##              they travelled through, or the spot they stood on when the
##              game was saved
##   leaving    exits from the layout call `_on_exit_used`; the default handles
##              "world_map", "return" (pop the return destination) and a map id
##   moving     PlayerController + follow camera bounded by the map
##   colliding  one static body from the layout's border and solid props;
##              subclasses add their own bodies for things that change
##   state      `map_state()` is the persistent record of this map
##              (MapStateStore); the player's position is recorded on save
##
## Override: _load_map_definition (required), _build_content, _build_hud,
## _dynamic_solid_rects, _combat_enabled, _on_exit_used, _show_prompt, _notify.

const GroundRendererScript := preload("res://scripts/gameplay/exploration/framework/map_ground_renderer.gd")

var map_def: MapDefinition
var player: CharacterBody2D
var entities: Node2D
var ground: Node2D
## exit id -> InteractableArea
var exit_areas: Dictionary = {}
var _leaving: bool = false


func _ready() -> void:
	if not Session.has_game():
		Router.go("main_menu")
		return
	map_def = _load_map_definition()
	if map_def == null:
		push_error("Map scene has no layout")
		Router.go("main_menu")
		return
	ground = Node2D.new()
	ground.name = "Ground"
	ground.set_script(GroundRendererScript)
	add_child(ground)
	ground.setup(map_def)
	ExplorationKit.build_static_body(self, map_def.static_solid_rects(), "MapBounds")
	entities = ExplorationKit.create_entities_layer(self)
	_build_border_decoration()
	_build_props()
	_build_exits()
	_build_content()
	_spawn_player()
	_build_hud()
	Session.saving.connect(_on_session_saving)
	_after_ready()


func _exit_tree() -> void:
	if Session.saving.is_connected(_on_session_saving):
		Session.saving.disconnect(_on_session_saving)


func _process(_delta: float) -> void:
	if player == null or map_def == null:
		return
	Router.debug_extra = ExplorationKit.debug_lines(player, map_def.cell_size, "map %s (%s)  location %s@%s" % [map_def.map_id, map_def.display_name, Session.travel.current_map_id(), Session.travel.current_entry_id()])


# --- for subclasses ----------------------------------------------------------------

## The static layout of this map. Required.
func _load_map_definition() -> MapDefinition:
	return null


## Add the map's own objects (to `entities`) here; the player does not exist yet.
func _build_content() -> void:
	pass


func _build_hud() -> void:
	pass


func _after_ready() -> void:
	pass


## Solid rectangles that depend on state (for example built-on sites); used to
## check that a remembered position is still free.
func _dynamic_solid_rects() -> Array:
	return []


func _combat_enabled() -> bool:
	return false


## Show the interaction prompt ("" clears it).
func _show_prompt(_text: String) -> void:
	pass


## Tell the player something short.
func _notify(_text: String) -> void:
	pass


## Persistent record of this map (see MapStateStore).
func map_state() -> Dictionary:
	return MapStateStore.record(Session.universe(), map_def.map_id)


# --- leaving -----------------------------------------------------------------------

## Use an exit of the layout by id (what interacting with it does).
func use_exit(exit_id: String) -> void:
	var exit_def := map_def.exit_by_id(exit_id)
	if exit_def.is_empty() or _leaving:
		return
	_on_exit_used(exit_def)


func _on_exit_used(exit_def: Dictionary) -> void:
	var to := String(exit_def["to"])
	var return_entry := String(exit_def["return_entry"])
	match to:
		"world_map":
			# Stepping out to the strategic map: come back in through this exit.
			if return_entry != "":
				Session.travel.set_entry(return_entry)
			_leave_to("world_map")
		"return":
			var back := Session.travel.leave()
			_leave_to(DictUtil.get_string(back.value, "scene"))
		_:
			var r := Session.travel.enter(to, "", true, return_entry)
			if not r.ok:
				_notify(r.error)
				return
			_leave_to(DictUtil.get_string(r.value, "scene"))


func _leave_to(scene_key: String) -> void:
	if scene_key == "" or not Router.SCENES.has(scene_key):
		_notify("There is nowhere to go from here yet.")
		return
	_leaving = true
	if player != null:
		player.input_enabled = false
	Router.go(scene_key)


# --- construction of the common parts -----------------------------------------------

func _spawn_player() -> void:
	var solids := _dynamic_solid_rects()
	# A remembered spot is used only if the body still fits there: the same
	# circle the player collides with, a hair smaller so that standing flush
	# against a wall counts as free.
	var fits := func(p: Vector2) -> bool: return map_def.is_position_free(p + ExplorationKit.PlayerScript.BODY_OFFSET, solids, ExplorationKit.PlayerScript.BODY_RADIUS - 0.5)
	var spot := Session.travel.arrival_position(map_def.map_id, map_def.entries, map_def.default_entry, fits)
	player = ExplorationKit.spawn_player(entities, spot, map_def.world_size(), _combat_enabled())
	player.interact_target_changed.connect(_on_interact_target_changed)


func _on_interact_target_changed(target: Node) -> void:
	_show_prompt(target.interaction_prompt() if target != null and is_instance_valid(target) else "")


func _on_session_saving() -> void:
	if player != null and not _leaving and Session.has_game() and Session.travel.current_map_id() == map_def.map_id:
		Session.travel.remember_position(player.position)


func _build_props() -> void:
	for p in map_def.props:
		var sprite := Visuals.make_sprite(String(p["visual"]))
		sprite.position = p["position"]
		entities.add_child(sprite)


func _build_exits() -> void:
	for e in map_def.exits:
		var rect: Rect2 = e["rect"]
		var area := InteractableArea.new()
		area.name = "Exit_" + String(e["id"])
		area.target_id = String(e["id"])
		area.prompt = String(e["prompt"])
		area.position = rect.position + rect.size * 0.5
		area.set_rect(rect.size)
		area.interacted.connect(_on_exit_area_interacted.bind(String(e["id"])))
		entities.add_child(area)
		exit_areas[String(e["id"])] = area
		if String(e["visual"]) != "":
			var sprite := Visuals.make_sprite(String(e["visual"]))
			sprite.position = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y)
			entities.add_child(sprite)


func _on_exit_area_interacted(_player: Node, exit_id: String) -> void:
	use_exit(exit_id)


## Decoration along the closed border (the tree line), left open at exits.
func _build_border_decoration() -> void:
	var visual := DictUtil.get_string(map_def.border, "visual")
	if visual == "" or map_def.border_cells <= 0:
		return
	var step := maxf(0.5, DictUtil.get_float(map_def.border, "spacing", 1.5)) * float(map_def.cell_size)
	var margin := float(map_def.border_cells * map_def.cell_size)
	var size := map_def.world_size()
	var spots: Array[Vector2] = []
	var x := margin * 0.5
	while x < size.x:
		spots.append(Vector2(x, margin))
		spots.append(Vector2(x, size.y - margin * 0.15))
		x += step
	var y := margin + step
	while y < size.y - margin:
		spots.append(Vector2(margin * 0.5, y))
		spots.append(Vector2(size.x - margin * 0.5, y))
		y += step
	for spot in spots:
		var blocked := false
		for e in map_def.exits:
			if (e["rect"] as Rect2).grow(float(map_def.cell_size)).has_point(spot):
				blocked = true
				break
		if blocked:
			continue
		var sprite := Visuals.make_sprite(visual)
		sprite.position = spot
		entities.add_child(sprite)
