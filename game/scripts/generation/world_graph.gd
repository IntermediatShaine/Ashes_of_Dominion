class_name WorldGraph
extends RefCounted
## Strategic map: landmarks (persistent layer) + procedural waypoints joined by
## edges. Derived from (world_seed, generation_version) — never persisted.
##
## node: {id, name, kind, biome, position: Vector2, persistent: bool,
##        explorable: bool, danger: int, description, known_at_start}
## edge: {id, a, b, distance, terrain_cost, cost, danger, kind}
##   kind is "overland" now; "shortcut" is reserved for persistent magical
##   shortcuts so the route model can carry them later without a schema change.

var nodes: Dictionary = {}
var edges: Dictionary = {}
var _adjacency: Dictionary = {}


func add_node(node: Dictionary) -> void:
	nodes[node["id"]] = node
	if not _adjacency.has(node["id"]):
		_adjacency[node["id"]] = []


func add_edge(edge: Dictionary) -> void:
	edges[edge["id"]] = edge
	for n in [edge["a"], edge["b"]]:
		if not _adjacency.has(n):
			_adjacency[n] = []
		(_adjacency[n] as Array).append(edge["id"])
		(_adjacency[n] as Array).sort()


static func edge_id_for(a: String, b: String) -> String:
	return "e_%s__%s" % ([a, b] if a < b else [b, a])


func has_edge(a: String, b: String) -> bool:
	return edges.has(edge_id_for(a, b))


func edge_ids_of(node_id: String) -> Array:
	return _adjacency.get(node_id, [])


func other_end(edge_id: String, node_id: String) -> String:
	var e: Dictionary = edges[edge_id]
	return e["b"] if e["a"] == node_id else e["a"]


func neighbor_ids(node_id: String) -> Array[String]:
	var out: Array[String] = []
	for eid in edge_ids_of(node_id):
		out.append(other_end(eid, node_id))
	out.sort()
	return out


func node(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


func node_ids() -> Array:
	return DictUtil.sorted_keys(nodes)


func edge_ids() -> Array:
	return DictUtil.sorted_keys(edges)


## Content fingerprint used by determinism tests.
func fingerprint() -> String:
	var parts: Array[String] = []
	for id in node_ids():
		var n: Dictionary = nodes[id]
		parts.append("%s@%d,%d:%s" % [id, int((n["position"] as Vector2).x), int((n["position"] as Vector2).y), n["biome"]])
	for id in edge_ids():
		var e: Dictionary = edges[id]
		parts.append("%s=%.1f/%d" % [id, float(e["cost"]), int(e["danger"])])
	return "|".join(parts)
