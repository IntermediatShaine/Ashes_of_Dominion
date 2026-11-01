extends TestCase
## Capture the actual renderer's dashed commands, rather than a parallel model
## of its visibility policy. Headless runs exercise _draw through the scene tree.

class PreviewCapture:
	extends "res://scripts/interface/world_map_screen.gd"
	var preview_lines: Array = []

	func _draw() -> void:
		preview_lines.clear()
		super._draw()

	func _dashed(a: Vector2, b: Vector2, color: Color, _width: float) -> void:
		if color == UiKit.ACCENT:
			preview_lines.append([a, b])

var _saved_repo: SaveRepository
var _map: PreviewCapture


func before_each() -> void:
	_saved_repo = Session.repository
	Session.repository = SaveRepository.new(temp_dir + "/saves")
	var d := DifficultyRules.from_preset("easy", Content.table("difficulty"))
	assert_ok(Session.new_game({"name": "MistTester", "archetype_id": "village_hunter", "difficulty": d.value, "mist_enabled": true, "seed": 2468}, 1))
	# A deliberately bent route guarantees two hidden intermediate waypoints,
	# independent of changes to the procedural graph's seed or connectivity.
	var g := WorldGraph.new()
	for id in ["emberfall", "hidden_a", "hidden_b", "greywood_edge"]:
		var landmark: bool = id == "emberfall" or id == "greywood_edge"
		var n: Dictionary = Session.world.node(id).duplicate(true) if landmark else {"id": id, "persistent": false, "explorable": false, "name": id}
		n["position"] = {"emberfall": Vector2(0, 0), "hidden_a": Vector2(100, 200), "hidden_b": Vector2(250, 50), "greywood_edge": Vector2(400, 0)}[id]
		n["biome"] = "marches"
		g.add_node(n)
	var ids := ["emberfall", "hidden_a", "hidden_b", "greywood_edge"]
	for i in 3:
		g.add_edge({"id": "edge_%d" % i, "a": ids[i], "b": ids[i + 1], "distance": 100.0, "cost": 100.0, "danger": 1})
	Session.world = g
	Session.expeditions.world = g
	Session.universe().revealed_edge_ids.clear()
	_map = PreviewCapture.new()
	tree.root.add_child(_map)
	_map._select("greywood_edge")


func after_each() -> void:
	_map.free()
	Session.end_session()
	Session.repository = _saved_repo


func _direct_line() -> Array:
	return [[_map._map_pos("emberfall"), _map._map_pos("greywood_edge")]]


func test_uncharted_preview_hides_intermediate_geometry() -> void:
	await tree.process_frame
	await tree.process_frame
	assert_eq(_map.preview_lines, _direct_line(), "only origin and destination reach the dashed renderer")
	assert_false(_map._is_visible_node("hidden_a"))
	Session.world.nodes["hidden_a"]["position"] = Vector2(40, 350)
	_map.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(_map.preview_lines, _direct_line(), "moving a hidden waypoint cannot change the preview")


func test_partly_charted_preview_hides_remaining_geometry() -> void:
	Session.universe().revealed_edge_ids.append("edge_0")
	_map.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_true(_map._is_visible_node("hidden_a"))
	assert_false(_map._is_visible_node("hidden_b"))
	assert_eq(_map.preview_lines, _direct_line())


func test_charted_and_mist_disabled_routes_use_real_edges() -> void:
	Session.universe().revealed_edge_ids.assign(["edge_0", "edge_1", "edge_2"])
	_map.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(_map.preview_lines, [], "charted edges are solid")
	Session.universe().revealed_edge_ids.clear()
	Session.universe().world_settings["mist_enabled"] = false
	_map.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(_map.preview_lines, [], "Mist off uses solid real geometry")
	assert_true(_map._is_visible_node("hidden_b"))


func test_preview_preserves_route_state_and_expedition_selection() -> void:
	var route: Dictionary = _map._routes[0].duplicate(true)
	var estimate := RoutePlanner.estimate(route, Session.universe())
	var state := Session.save.to_dict().duplicate(true)
	var fingerprint := Session.world.fingerprint()
	_map.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(Session.save.to_dict(), state)
	assert_eq(Session.world.fingerprint(), fingerprint)
	assert_eq(_map._routes[0], route)
	assert_eq(RoutePlanner.estimate(_map._routes[0], Session.universe()), estimate)
	assert_ok(Session.expeditions.start("greywood_edge", _map._routes[0]))
	assert_eq(Session.expeditions.active().route_node_ids, route["node_ids"])
	assert_eq(Session.expeditions.active().route_edge_ids, route["edge_ids"])
