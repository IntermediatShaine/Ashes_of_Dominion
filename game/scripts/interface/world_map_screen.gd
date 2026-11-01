extends Node2D
## Strategic map: known landmarks, current location, route selection and
## expedition start. Respects the Mist of Discovery: undiscovered landmarks
## and untravelled edges are hidden while the Mist is enabled.

const NODE_RADIUS := 9.0
const PICK_RADIUS := 18.0
const MAP_OFFSET := Vector2(60, 40)

var _selected_id: String = ""
var _routes: Array[Dictionary] = []
var _route_index: int = 0
var _hover_id: String = ""

var _ui: CanvasLayer
var _info_box: VBoxContainer
var _routes_box: VBoxContainer
var _begin_btn: Button
var _status: Label
var _font: Font


func _ready() -> void:
	if not Session.has_game():
		Router.go("main_menu")
		return
	_font = ThemeDB.fallback_font
	_build_ui()
	queue_redraw()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var bg := ColorRect.new()
	bg.color = Color("15131a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	# Background goes behind the map: put it in its own low layer.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	bg_layer.add_child(bg)
	add_child(bg_layer)

	var panel := UiKit.panel(Vector2(340, 0))
	panel.theme = UiKit.theme()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = -12
	_ui.add_child(panel)
	var col := UiKit.vbox(8)
	panel.add_child(col)
	col.add_child(UiKit.title("The Marches", 26))
	var u := Session.universe()
	col.add_child(UiKit.muted("Day %d · Mist of Discovery %s" % [u.current_day, "on" if u.mist_enabled() else "off"], 13))
	col.add_child(UiKit.muted("Click a known place to plan an expedition.", 13))
	col.add_child(UiKit.separator())
	_info_box = UiKit.vbox(4)
	col.add_child(_info_box)
	_routes_box = UiKit.vbox(6)
	col.add_child(_routes_box)
	_begin_btn = UiKit.button("Begin Expedition", _on_begin, 300)
	_begin_btn.disabled = true
	col.add_child(_begin_btn)
	_status = UiKit.label("", 13, UiKit.BAD)
	col.add_child(_status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(UiKit.muted("Legend: ◆ village  ● place  ○ waypoint  — travelled route  ··· unknown", 12))
	col.add_child(UiKit.button("Back to Emberfall  [Esc]", func(): Router.go("settlement"), 300))
	_refresh_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("world_map"):
		Router.go("settlement")
		return
	if event is InputEventMouseMotion:
		var id := _pick(get_local_mouse_position())
		if id != _hover_id:
			_hover_id = id
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _pick(get_local_mouse_position())
		if id != "" and _is_selectable(id):
			_select(id)


func _is_visible_node(id: String) -> bool:
	var u := Session.universe()
	var n := Session.world.node(id)
	if not u.mist_enabled():
		return true
	if n["persistent"]:
		return u.is_landmark_discovered(id)
	# waypoints show once any adjacent edge was travelled
	for eid in Session.world.edge_ids_of(id):
		if u.revealed_edge_ids.has(eid):
			return true
	return false


func _is_selectable(id: String) -> bool:
	return Session.expeditions.available_destinations().has(id)


func _pick(pos: Vector2) -> String:
	var best := ""
	var best_d := PICK_RADIUS
	for id in Session.world.node_ids():
		if not _is_visible_node(String(id)):
			continue
		var d: float = (_map_pos(String(id))).distance_to(pos)
		if d < best_d:
			best_d = d
			best = String(id)
	return best


func _map_pos(id: String) -> Vector2:
	return (Session.world.node(id)["position"] as Vector2) + MAP_OFFSET


func _select(id: String) -> void:
	_selected_id = id
	_routes = Session.expeditions.plan_routes(id)
	_route_index = 0
	_status.text = "" if not _routes.is_empty() else "No known way to reach that place."
	_refresh_panel()
	queue_redraw()


func _refresh_panel() -> void:
	for c in _info_box.get_children():
		c.queue_free()
	for c in _routes_box.get_children():
		c.queue_free()
	_begin_btn.disabled = _routes.is_empty()
	if _selected_id == "":
		_info_box.add_child(UiKit.label("No destination selected.", 15, UiKit.MUTED))
		return
	var n := Session.world.node(_selected_id)
	_info_box.add_child(UiKit.label(String(n["name"]), 20, UiKit.ACCENT))
	_info_box.add_child(UiKit.muted(String(n["description"]), 13))
	var owner := String(Session.universe().territory_state.get(_selected_id, ""))
	if owner != "":
		_info_box.add_child(UiKit.muted("Territory of " + DictUtil.get_string(Content.get_def("factions", owner), "name"), 13))
	_routes_box.add_child(UiKit.label("Routes", 16))
	for i in _routes.size():
		var r := _routes[i]
		var est := RoutePlanner.estimate(r, Session.universe())
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = i == _route_index
		b.text = "%s: %s · %s · %s" % [["A", "B", "C"][mini(i, 2)], est["days_label"], est["danger_label"], est["certainty"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_route_index = i
			_refresh_panel()
			queue_redraw())
		_routes_box.add_child(b)
	if not _routes.is_empty():
		_routes_box.add_child(UiKit.muted("Estimates. Only travelled routes are known exactly.", 12))


func _on_begin() -> void:
	if _routes.is_empty():
		return
	var r := Session.expeditions.start(_selected_id, _routes[_route_index])
	if not r.ok:
		_status.text = r.error
		return
	Telemetry.record_event("expedition_started")
	Router.go("exploration")


func _draw() -> void:
	var u := Session.universe()
	var g := Session.world
	var selected_edges: Array = _routes[_route_index]["edge_ids"] if not _routes.is_empty() else []
	var has_uncharted := false
	# edges
	for eid in g.edge_ids():
		var e: Dictionary = g.edges[eid]
		var a := String(e["a"])
		var b := String(e["b"])
		var revealed := u.revealed_edge_ids.has(eid) or not u.mist_enabled()
		var on_route := selected_edges.has(eid)
		if not revealed:
			if on_route:
				has_uncharted = true
			elif _is_visible_node(a) and _is_visible_node(b):
				_dashed(_map_pos(a), _map_pos(b), Color(0.5, 0.45, 0.4, 0.25), 1.0)
			continue
		var color := Color(0.55, 0.5, 0.45, 0.8)
		var width := 2.0
		if on_route:
			color = UiKit.ACCENT
			width = 4.0
		draw_line(_map_pos(a), _map_pos(b), color, width)
	# A preview is an indication of destination, not a survey of hidden edges.
	# Keep charted edges above, but never draw uncharted waypoint positions.
	if has_uncharted:
		var nodes: Array = _routes[_route_index]["node_ids"]
		_dashed(_map_pos(String(nodes.front())), _map_pos(String(nodes.back())), UiKit.ACCENT, 4.0)
	# nodes
	for id in g.node_ids():
		if not _is_visible_node(String(id)):
			continue
		var n := g.node(String(id))
		var p := _map_pos(String(id))
		var is_home := String(id) == u.home_landmark_id()
		var selectable := _is_selectable(String(id))
		var color := Color(0.75, 0.72, 0.68)
		if is_home:
			color = Color(0.95, 0.8, 0.4)
		elif not n["persistent"]:
			color = Color(0.45, 0.42, 0.4)
		elif not selectable:
			color = Color(0.6, 0.5, 0.5)
		if String(id) == _selected_id:
			draw_circle(p, NODE_RADIUS + 6, Color(UiKit.ACCENT, 0.35))
		elif String(id) == _hover_id and selectable:
			draw_circle(p, NODE_RADIUS + 4, Color(1, 1, 1, 0.15))
		if is_home:
			draw_polygon(PackedVector2Array([p + Vector2(0, -13), p + Vector2(13, 0), p + Vector2(0, 13), p + Vector2(-13, 0)]), PackedColorArray([color]))
		elif n["persistent"]:
			draw_circle(p, NODE_RADIUS, color)
		else:
			draw_arc(p, 5, 0, TAU, 12, color, 2.0)
		if n["persistent"]:
			draw_string(_font, p + Vector2(14, 5), String(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.86, 0.8))
			var owner := String(u.territory_state.get(String(id), ""))
			if owner != "":
				draw_string(_font, p + Vector2(14, 20), DictUtil.get_string(Content.get_def("factions", owner), "name"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.6, 0.5))
	# current location marker
	var home := _map_pos(u.home_landmark_id())
	draw_arc(home, NODE_RADIUS + 10, 0, TAU, 24, Color(0.95, 0.8, 0.4, 0.8), 2.0)
	draw_string(_font, home + Vector2(-40, -26), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.8, 0.4))


func _dashed(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var dir := (b - a)
	var length := dir.length()
	if length <= 0.0:
		return
	dir = dir / length
	var t := 0.0
	while t < length:
		var s := a + dir * t
		var e := a + dir * minf(t + 6.0, length)
		draw_line(s, e, color, width)
		t += 12.0
