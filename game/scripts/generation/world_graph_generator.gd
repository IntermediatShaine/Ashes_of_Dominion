class_name WorldGraphGenerator
extends RefCounted
## Builds the strategic WorldGraph deterministically from
## (world_seed, generation_version, landmark + biome definitions, balance).
##
## Determinism contract: all iteration is over sorted ids, every random draw
## comes from a stream derived from the seed, and no Dictionary iteration
## order is relied upon. Landmark positions come straight from data and are
## never moved — only the waypoints and the edge network vary per seed.

const WAYPOINT_MARGIN := 80.0
const WAYPOINT_MIN_SPACING := 90.0


static func generate(world_seed: int, generation_version: int, landmarks: Dictionary, biomes: Dictionary, world_balance: Dictionary) -> WorldGraph:
	var g := WorldGraph.new()
	var rng := RngStream.new("gen_world", StableHash.derive_seed(world_seed, "gen:world:v%d" % generation_version))

	# 1. persistent landmark layer
	var lm_ids := DictUtil.sorted_keys(landmarks)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for id in lm_ids:
		var d: Dictionary = landmarks[id]
		var p_arr := DictUtil.get_array(d, "position")
		var pos := Vector2(float(p_arr[0]), float(p_arr[1])) if p_arr.size() == 2 else Vector2.ZERO
		min_p = Vector2(minf(min_p.x, pos.x), minf(min_p.y, pos.y))
		max_p = Vector2(maxf(max_p.x, pos.x), maxf(max_p.y, pos.y))
		g.add_node({
			"id": String(id),
			"name": DictUtil.get_string(d, "name", String(id)),
			"kind": DictUtil.get_string(d, "kind", "landmark"),
			"biome": DictUtil.get_string(d, "biome", "marches"),
			"position": pos,
			"persistent": true,
			"explorable": DictUtil.get_bool(d, "explorable", true),
			"danger": clampi(DictUtil.get_int(d, "danger", 1), 1, DictUtil.get_int(world_balance, "danger_levels", 3)),
			"description": DictUtil.get_string(d, "description", ""),
			"known_at_start": DictUtil.get_bool(d, "known_at_start", false),
		})

	# 2. procedural waypoints
	var waypoint_count := DictUtil.get_int(world_balance, "procedural_waypoints", 6)
	var placed: Array[Vector2] = []
	for id in lm_ids:
		placed.append(g.node(String(id))["position"])
	var created := 0
	var attempts := 0
	while created < waypoint_count and attempts < waypoint_count * 40:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(min_p.x - WAYPOINT_MARGIN, max_p.x + WAYPOINT_MARGIN),
			rng.randf_range(min_p.y - WAYPOINT_MARGIN, max_p.y + WAYPOINT_MARGIN)
		).round()
		var ok := true
		for q in placed:
			if q.distance_to(pos) < WAYPOINT_MIN_SPACING:
				ok = false
				break
		if not ok:
			continue
		var nearest := _nearest_landmark(pos, g, lm_ids)
		var wp_id := "wp_%02d" % created
		g.add_node({
			"id": wp_id,
			"name": "Waypoint %d" % (created + 1),
			"kind": "waypoint",
			"biome": g.node(nearest)["biome"],
			"position": pos,
			"persistent": false,
			"explorable": false,
			"danger": int(g.node(nearest)["danger"]),
			"description": "An unremarkable stretch of the Marches.",
			"known_at_start": false,
		})
		placed.append(pos)
		created += 1

	# 3. edges: each node links to its K nearest; then force connectivity
	var k := DictUtil.get_int(world_balance, "neighbor_links", 2)
	var ids := g.node_ids()
	for id in ids:
		var ranked := _ranked_by_distance(String(id), g, ids)
		for i in mini(k, ranked.size()):
			_ensure_edge(g, String(id), ranked[i], rng, biomes, world_balance)
	_connect_components(g, ids, rng, biomes, world_balance)
	return g


static func _nearest_landmark(pos: Vector2, g: WorldGraph, lm_ids: Array) -> String:
	var best := ""
	var best_d := INF
	for id in lm_ids:
		var d: float = (g.node(String(id))["position"] as Vector2).distance_to(pos)
		if d < best_d:
			best_d = d
			best = String(id)
	return best


static func _ranked_by_distance(from: String, g: WorldGraph, ids: Array) -> Array[String]:
	var entries: Array = []
	var p: Vector2 = g.node(from)["position"]
	for id in ids:
		if String(id) == from:
			continue
		entries.append([p.distance_to(g.node(String(id))["position"]), String(id)])
	entries.sort_custom(func(a, b): return a[0] < b[0] if not is_equal_approx(a[0], b[0]) else a[1] < b[1])
	var out: Array[String] = []
	for e in entries:
		out.append(e[1])
	return out


static func _ensure_edge(g: WorldGraph, a: String, b: String, rng: RngStream, biomes: Dictionary, world_balance: Dictionary) -> void:
	if a == b or g.has_edge(a, b):
		return
	var na := g.node(a)
	var nb := g.node(b)
	var dist: float = (na["position"] as Vector2).distance_to(nb["position"])
	var tc := (DictUtil.get_float(DictUtil.get_dict(biomes, na["biome"]), "terrain_cost", 1.0) + DictUtil.get_float(DictUtil.get_dict(biomes, nb["biome"]), "terrain_cost", 1.0)) * 0.5
	var max_danger := DictUtil.get_int(world_balance, "danger_levels", 3)
	var danger := clampi(int(round((int(na["danger"]) + int(nb["danger"])) * 0.5 + rng.randf_range(-0.75, 0.75))), 1, max_danger)
	g.add_edge({
		"id": WorldGraph.edge_id_for(a, b),
		"a": a if a < b else b,
		"b": b if a < b else a,
		"distance": dist,
		"terrain_cost": tc,
		"cost": dist * tc,
		"danger": danger,
		"kind": "overland",
	})


static func _connect_components(g: WorldGraph, ids: Array, rng: RngStream, biomes: Dictionary, world_balance: Dictionary) -> void:
	var parent := {}
	for id in ids:
		parent[id] = id
	var find := func(x: String) -> String:
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	for eid in g.edge_ids():
		var e: Dictionary = g.edges[eid]
		parent[find.call(e["a"])] = find.call(e["b"])
	var guard := 0
	while guard < ids.size():
		guard += 1
		var best_pair := []
		var best_d := INF
		for a in ids:
			for b in ids:
				if String(a) >= String(b) or find.call(a) == find.call(b):
					continue
				var d: float = (g.node(String(a))["position"] as Vector2).distance_to(g.node(String(b))["position"])
				if d < best_d:
					best_d = d
					best_pair = [String(a), String(b)]
		if best_pair.is_empty():
			return
		_ensure_edge(g, best_pair[0], best_pair[1], rng, biomes, world_balance)
		parent[find.call(best_pair[0])] = find.call(best_pair[1])
