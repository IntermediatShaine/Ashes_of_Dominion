class_name WildernessMap
extends RefCounted
## A generated explorable area (bounded grid). Pure data; the exploration
## scene renders it. Never persisted — regenerated from its seed; the
## player's changes to it live in UniverseState.world_modifications[area_id].

enum Terrain { GROUND = 0, GROUND_ALT = 1, OBSTACLE = 2, WATER = 3, PATH = 4 }

var area_id: String = ""
var biome_id: String = ""
var area_seed: int = 0
var width: int = 0
var height: int = 0
var cell_size: int = 32
var terrain := PackedByteArray()
var spawn := Vector2i.ZERO
var exit := Vector2i.ZERO
## {key, cell: Vector2i, resource_id, amount}
var resource_nodes: Array[Dictionary] = []
## {key, cell: Vector2i, enemy_id}
var enemy_spawns: Array[Dictionary] = []
## {} or {cell: Vector2i, decision_id}
var npc_spawn: Dictionary = {}
var repairs_applied: int = 0


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_terrain(x: int, y: int) -> int:
	return terrain[y * width + x]


func set_terrain(x: int, y: int, t: int) -> void:
	terrain[y * width + x] = t


func is_walkable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t := get_terrain(x, y)
	return t == Terrain.GROUND or t == Terrain.GROUND_ALT or t == Terrain.PATH


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)


func world_size() -> Vector2:
	return Vector2(width * cell_size, height * cell_size)


## BFS reachability from spawn over walkable cells (4-neighbour).
func reachable_from_spawn() -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = [spawn]
	seen[spawn] = true
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not is_walkable(n.x, n.y):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func fingerprint() -> String:
	var h := StableHash.fnv1a("%s|%d|%d|%d,%d|%d,%d" % [area_id, width, height, spawn.x, spawn.y, exit.x, exit.y])
	for i in terrain.size():
		h = (h ^ terrain[i]) * StableHash.FNV_PRIME
	var extras: Array[String] = []
	for r in resource_nodes:
		extras.append("%s:%s:%d" % [r["key"], r["resource_id"], int(r["amount"])])
	for e in enemy_spawns:
		extras.append("%s:%s" % [e["key"], e["enemy_id"]])
	if not npc_spawn.is_empty():
		extras.append("npc:%s@%s" % [npc_spawn["decision_id"], str(npc_spawn["cell"])])
	return IdFactory.hex16(h) + "|" + "|".join(extras)
