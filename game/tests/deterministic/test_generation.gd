extends TestCase
## Determinism tests: same seed → same output, different seed → different
## output, landmarks never move, generated areas always satisfy constraints.


func _graph(seed_value: int) -> WorldGraph:
	return WorldGraphGenerator.generate(seed_value, 1, Content.table("landmarks"), Content.table("biomes"), DictUtil.get_dict(Content.table("balance"), "world_map"))


func test_world_graph_same_seed_same_graph() -> void:
	assert_eq(_graph(1234).fingerprint(), _graph(1234).fingerprint())
	assert_eq(_graph(-99).fingerprint(), _graph(-99).fingerprint())


func test_world_graph_different_seed_differs_but_landmarks_stable() -> void:
	var a := _graph(1)
	var b := _graph(2)
	assert_ne(a.fingerprint(), b.fingerprint())
	for id in Content.ids("landmarks"):
		assert_true(a.nodes.has(id) and b.nodes.has(id), "landmark missing: " + String(id))
		assert_eq(a.node(String(id))["position"], b.node(String(id))["position"], "landmark moved: " + String(id))
		assert_true(a.node(String(id))["persistent"])


func test_world_graph_is_connected_for_many_seeds() -> void:
	var day_cost := 150.0
	for seed_value in range(0, 40):
		var g := _graph(seed_value * 7919 - 5)
		for id in Content.ids("landmarks"):
			if String(id) == UniverseFactory.HOME_LANDMARK_ID:
				continue
			var route := RoutePlanner.plan(g, UniverseFactory.HOME_LANDMARK_ID, String(id), day_cost)
			assert_false(route.is_empty(), "seed %d: no route to %s" % [seed_value, String(id)])
			if not route.is_empty():
				assert_eq(route["node_ids"][0], UniverseFactory.HOME_LANDMARK_ID)
				assert_eq(route["node_ids"][route["node_ids"].size() - 1], String(id))
				assert_true(int(route["travel_days"]) >= 1)


func test_route_alternatives_are_distinct() -> void:
	var g := _graph(77)
	var routes := RoutePlanner.plan_alternatives(g, "emberfall", "aurel_border_fort", 150.0, 2)
	assert_true(routes.size() >= 1)
	for i in routes.size():
		for j in routes.size():
			if i != j:
				assert_ne(routes[i]["edge_ids"], routes[j]["edge_ids"])
	if routes.size() >= 2:
		assert_true(float(routes[0]["cost"]) <= float(routes[1]["cost"]), "primary route is cheapest")


func test_route_estimate_respects_mist() -> void:
	var save := TestFixtures.new_save(5, "challenging", "village_hunter", true)
	var g := _graph(5)
	var route := RoutePlanner.plan(g, "emberfall", "ashen_crossroads", 150.0)
	var est := RoutePlanner.estimate(route, save.universe)
	assert_eq(est["certainty"], "Uncharted")
	for eid in route["edge_ids"]:
		save.universe.reveal_edge(eid)
	est = RoutePlanner.estimate(route, save.universe)
	assert_eq(est["certainty"], "Charted")
	var no_mist := TestFixtures.new_save(5, "challenging", "village_hunter", false)
	assert_eq(RoutePlanner.estimate(route, no_mist.universe)["certainty"], "Charted", "mist disabled => everything known")


func _area(seed_value: int, area_id: String, biome_id: String, danger: int = 1, decision: String = "") -> WildernessMap:
	var params := {"biome": Content.get_def("biomes", biome_id), "danger": danger, "resource_abundance": 1.0, "decision_id": decision, "harvested": {}, "current_day": 1, "regrowth_days": 10}
	return WildernessGenerator.generate(seed_value, 1, area_id, biome_id, params, Content.balance("wilderness"))


func test_wilderness_same_seed_same_layout() -> void:
	assert_eq(_area(10, "ashen_crossroads", "marches").fingerprint(), _area(10, "ashen_crossroads", "marches").fingerprint())
	assert_ne(_area(10, "ashen_crossroads", "marches").fingerprint(), _area(11, "ashen_crossroads", "marches").fingerprint())
	assert_ne(_area(10, "ashen_crossroads", "marches").fingerprint(), _area(10, "greywood_edge", "marches").fingerprint(), "different area id => different layout")


func test_wilderness_constraints_hold_for_many_seeds() -> void:
	var biomes := Content.ids("biomes")
	for i in 30:
		var biome_id := String(biomes[i % biomes.size()])
		var m := _area(i * 31337 + 1, "area_%d" % i, biome_id, 1 + (i % 3), "stranded_survivor" if i % 2 == 0 else "")
		var reach := m.reachable_from_spawn()
		assert_true(m.is_walkable(m.spawn.x, m.spawn.y), "spawn blocked (seed %d)" % i)
		assert_true(reach.has(m.exit), "exit unreachable (seed %d, biome %s)" % [i, biome_id])
		assert_true(m.resource_nodes.size() >= 1, "no resources (seed %d)" % i)
		assert_true(m.enemy_spawns.size() >= 3, "too few enemies (seed %d)" % i)
		for r in m.resource_nodes:
			assert_true(reach.has(r["cell"]), "resource unreachable (seed %d)" % i)
		for e in m.enemy_spawns:
			assert_true(reach.has(e["cell"]), "enemy unreachable (seed %d)" % i)
			assert_true((e["cell"] as Vector2i).distance_to(m.spawn) >= 9, "enemy too close to spawn")
		if i % 2 == 0:
			assert_false(m.npc_spawn.is_empty(), "decision npc missing (seed %d)" % i)
			assert_true(reach.has(m.npc_spawn["cell"]))


func test_wilderness_danger_scales_enemies() -> void:
	var low := _area(3, "x", "marches", 1)
	var high := _area(3, "x", "marches", 3)
	assert_true(high.enemy_spawns.size() > low.enemy_spawns.size())


func test_harvested_nodes_are_flagged_depleted() -> void:
	var fresh := _area(8, "y", "eldergrove")
	var key: String = fresh.resource_nodes[0]["key"]
	var params := {"biome": Content.get_def("biomes", "eldergrove"), "danger": 1, "resource_abundance": 1.0, "decision_id": "", "harvested": {key: 3}, "current_day": 5, "regrowth_days": 10}
	var again := WildernessGenerator.generate(8, 1, "y", "eldergrove", params, Content.balance("wilderness"))
	assert_true(again.resource_nodes[0]["depleted"])
	params["current_day"] = 20
	var regrown := WildernessGenerator.generate(8, 1, "y", "eldergrove", params, Content.balance("wilderness"))
	assert_false(regrown.resource_nodes[0]["depleted"])
	assert_eq(regrown.resource_nodes[0]["key"], key, "layout unaffected by harvest state")
