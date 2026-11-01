class_name RoutePlanner
extends RefCounted
## Dijkstra over the WorldGraph plus the "what does the player actually know"
## layer. Actual route properties and the player's estimate are kept apart:
## `plan()` returns the truth, `estimate()` returns what the UI may show.
##
## route: {node_ids: Array[String], edge_ids: Array[String], cost, distance,
##         travel_days, danger_max, danger_avg}


static func plan(g: WorldGraph, from: String, to: String, day_cost_units: float, excluded_edges: Array = []) -> Dictionary:
	if not g.nodes.has(from) or not g.nodes.has(to):
		return {}
	var dist := {from: 0.0}
	var prev_edge := {}
	var visited := {}
	var frontier: Array = [[0.0, from]]
	while not frontier.is_empty():
		# deterministic pop of the smallest (cost, id)
		var best_i := 0
		for i in range(1, frontier.size()):
			var a = frontier[i]
			var b = frontier[best_i]
			if a[0] < b[0] or (is_equal_approx(a[0], b[0]) and a[1] < b[1]):
				best_i = i
		var cur = frontier.pop_at(best_i)
		var cur_id: String = cur[1]
		if visited.has(cur_id):
			continue
		visited[cur_id] = true
		if cur_id == to:
			break
		for eid in g.edge_ids_of(cur_id):
			if excluded_edges.has(eid):
				continue
			var e: Dictionary = g.edges[eid]
			var nxt := g.other_end(eid, cur_id)
			var nd: float = dist[cur_id] + float(e["cost"])
			if not dist.has(nxt) or nd < float(dist[nxt]) - 0.0001:
				dist[nxt] = nd
				prev_edge[nxt] = eid
				frontier.append([nd, nxt])
	if not dist.has(to):
		return {}
	var node_ids: Array[String] = [to]
	var edge_ids: Array[String] = []
	var cur := to
	while cur != from:
		var eid: String = prev_edge[cur]
		edge_ids.push_front(eid)
		cur = g.other_end(eid, cur)
		node_ids.push_front(cur)
	var total_dist := 0.0
	var danger_max := 0
	var danger_sum := 0
	for eid in edge_ids:
		var e: Dictionary = g.edges[eid]
		total_dist += float(e["distance"])
		danger_max = maxi(danger_max, int(e["danger"]))
		danger_sum += int(e["danger"])
	return {
		"node_ids": node_ids,
		"edge_ids": edge_ids,
		"cost": float(dist[to]),
		"distance": total_dist,
		"travel_days": maxi(1, int(ceil(float(dist[to]) / maxf(1.0, day_cost_units)))),
		"danger_max": danger_max,
		"danger_avg": float(danger_sum) / maxf(1.0, edge_ids.size()),
	}


## Primary route plus up to `max_alternatives` distinct alternatives, cheapest first.
static func plan_alternatives(g: WorldGraph, from: String, to: String, day_cost_units: float, max_alternatives: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var primary := plan(g, from, to, day_cost_units)
	if primary.is_empty():
		return out
	out.append(primary)
	var candidates: Array[Dictionary] = []
	for eid in primary["edge_ids"]:
		var alt := plan(g, from, to, day_cost_units, [eid])
		if alt.is_empty() or _same_route(alt, primary):
			continue
		var dup := false
		for c in candidates:
			if _same_route(c, alt):
				dup = true
				break
		if not dup:
			candidates.append(alt)
	candidates.sort_custom(func(a, b): return a["cost"] < b["cost"])
	for i in mini(max_alternatives, candidates.size()):
		out.append(candidates[i])
	return out


static func _same_route(a: Dictionary, b: Dictionary) -> bool:
	return a["edge_ids"] == b["edge_ids"]


## Player-facing estimate. The Mist of Discovery is respected here: an edge
## the player has never travelled contributes uncertainty, so the preview is a
## band rather than the real number. With the Mist disabled everything is known.
static func estimate(route: Dictionary, u: UniverseState) -> Dictionary:
	var edge_ids: Array = route.get("edge_ids", [])
	var known := 0
	for eid in edge_ids:
		if not u.mist_enabled() or u.revealed_edge_ids.has(eid):
			known += 1
	var fraction := float(known) / maxf(1.0, edge_ids.size())
	var days: int = route.get("travel_days", 1)
	var danger_avg: float = route.get("danger_avg", 1.0)
	var out := {"charted_fraction": fraction}
	if fraction >= 0.999:
		out["days_label"] = "%d day%s" % [days, "" if days == 1 else "s"]
		out["danger_label"] = ["Quiet", "Dangerous", "Deadly"][clampi(int(route.get("danger_max", 1)) - 1, 0, 2)]
		out["certainty"] = "Charted"
	elif fraction > 0.0:
		out["days_label"] = "%d–%d days" % [days, days + 1]
		out["danger_label"] = "Likely " + ["quiet", "dangerous", "deadly"][clampi(int(round(danger_avg)) - 1, 0, 2)]
		out["certainty"] = "Partly charted"
	else:
		out["days_label"] = "%d–%d days" % [days, days + 2]
		out["danger_label"] = "Unknown" if danger_avg < 2.0 else "Rumoured dangerous"
		out["certainty"] = "Uncharted"
	return out
