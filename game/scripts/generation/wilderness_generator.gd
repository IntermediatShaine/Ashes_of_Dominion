class_name WildernessGenerator
extends RefCounted
## Seeded generation of one explorable area with constraint validation and
## deterministic repair.
##
## Layers produced (see docs/architecture.md "World layers"):
##   terrain  — value noise thresholded per biome (obstacle / water / ground)
##   nav      — border walls, cleared spawn/exit pockets, carved repair paths
##   resource — weighted picks from the biome pool, spaced apart
##   encounter— enemy spawns from the biome pool, kept away from the spawn
##   event    — at most one decision NPC
## Validation: exit, every resource, every enemy and the NPC must be reachable
## from the spawn by 4-neighbour walking. Unreachable targets get an L-shaped
## corridor carved toward the nearest reachable cell; repairs are counted.

const MAX_REPAIR_PASSES := 12


## params: {biome: Dictionary, danger: int, resource_abundance: float,
##          decision_id: String ("" for none), harvested: Dictionary(key->day),
##          current_day: int, regrowth_days: int}
static func generate(world_seed: int, generation_version: int, area_id: String, biome_id: String, params: Dictionary, wild_balance: Dictionary) -> WildernessMap:
	var m := WildernessMap.new()
	m.area_id = area_id
	m.biome_id = biome_id
	m.area_seed = StableHash.derive_seed(world_seed, "area:%s:v%d" % [area_id, generation_version])
	m.width = DictUtil.get_int(wild_balance, "width", 44)
	m.height = DictUtil.get_int(wild_balance, "height", 30)
	m.cell_size = DictUtil.get_int(wild_balance, "cell_size", 32)
	m.terrain.resize(m.width * m.height)
	var biome := DictUtil.get_dict(params, "biome")
	var rng := RngStream.new("gen_area", StableHash.derive_seed(m.area_seed, "placement"))

	# --- terrain layer ---
	var obstacle_t := DictUtil.get_float(biome, "obstacle_threshold", 0.65)
	var water_t := DictUtil.get_float(biome, "water_threshold", 0.1)
	var scale := DictUtil.get_float(biome, "noise_scale", 0.15)
	for y in m.height:
		for x in m.width:
			var n := _fractal_noise(m.area_seed, x * scale, y * scale)
			var t := WildernessMap.Terrain.GROUND
			if n > obstacle_t:
				t = WildernessMap.Terrain.OBSTACLE
			elif n < water_t:
				t = WildernessMap.Terrain.WATER
			elif StableHash.to_unit_float(StableHash.hash_cell(m.area_seed, x + 1000, y)) < 0.35:
				t = WildernessMap.Terrain.GROUND_ALT
			m.set_terrain(x, y, t)
	# border walls
	for x in m.width:
		m.set_terrain(x, 0, WildernessMap.Terrain.OBSTACLE)
		m.set_terrain(x, m.height - 1, WildernessMap.Terrain.OBSTACLE)
	for y in m.height:
		m.set_terrain(0, y, WildernessMap.Terrain.OBSTACLE)
		m.set_terrain(m.width - 1, y, WildernessMap.Terrain.OBSTACLE)

	# --- navigation layer: spawn/exit pockets ---
	m.spawn = Vector2i(2, m.height / 2)
	m.exit = Vector2i(m.width - 3, m.height / 2)
	_clear_pocket(m, m.spawn, 1)
	_clear_pocket(m, m.exit, 1)

	# --- resource layer ---
	var walkable := _walkable_cells(m)
	rng.shuffle(walkable)
	var abundance := DictUtil.get_float(params, "resource_abundance", 1.0)
	var resource_count := maxi(1, int(round(DictUtil.get_int(wild_balance, "base_resource_nodes", 6) * abundance)))
	var pool := DictUtil.get_dict(biome, "resource_pool")
	var pool_ids := DictUtil.sorted_keys(pool)
	var pool_weights: Array = []
	for id in pool_ids:
		pool_weights.append(float(pool[id]))
	var taken: Array[Vector2i] = [m.spawn, m.exit]
	var harvested := DictUtil.get_dict(params, "harvested")
	var current_day := DictUtil.get_int(params, "current_day", 1)
	var regrowth := DictUtil.get_int(params, "regrowth_days", 10)
	var amin := DictUtil.get_int(wild_balance, "resource_amount_min", 2)
	var amax := DictUtil.get_int(wild_balance, "resource_amount_max", 4)
	var placed := 0
	for c in walkable:
		if placed >= resource_count:
			break
		if not _far_enough(c, taken, 3) or c.distance_to(m.spawn) < 4:
			continue
		var key := "res_%d_%d" % [c.x, c.y]
		taken.append(c)
		placed += 1
		var rid: String = rng.weighted_pick(pool_ids, pool_weights)
		var amount := rng.randi_range(amin, amax)
		# Harvested nodes stay generated (so layouts stay identical) but are
		# flagged depleted until regrowth; the scene decides whether to show them.
		var depleted := harvested.has(key) and current_day - DictUtil.get_int(harvested, key, 0) < regrowth
		m.resource_nodes.append({"key": key, "cell": c, "resource_id": rid, "amount": amount, "depleted": depleted})

	# --- encounter layer ---
	var danger := clampi(DictUtil.get_int(params, "danger", 1), 1, 3)
	var enemy_count := DictUtil.get_int(wild_balance, "base_enemies", 3) + (danger - 1) * DictUtil.get_int(wild_balance, "enemies_per_danger_level", 2)
	var enemy_pool := DictUtil.get_array(biome, "enemy_pool")
	var e_placed := 0
	for c in walkable:
		if e_placed >= enemy_count or enemy_pool.is_empty():
			break
		if not _far_enough(c, taken, 3) or c.distance_to(m.spawn) < 9:
			continue
		taken.append(c)
		e_placed += 1
		m.enemy_spawns.append({"key": "enemy_%d_%d" % [c.x, c.y], "cell": c, "enemy_id": String(rng.pick(enemy_pool))})

	# --- event layer ---
	var decision_id := DictUtil.get_string(params, "decision_id", "")
	if decision_id != "":
		for c in walkable:
			if _far_enough(c, taken, 3) and c.distance_to(m.spawn) >= 6 and c.distance_to(m.exit) >= 4:
				taken.append(c)
				m.npc_spawn = {"cell": c, "decision_id": decision_id}
				break

	# --- validation + repair ---
	_validate_and_repair(m)
	return m


static func _validate_and_repair(m: WildernessMap) -> void:
	var required: Array[Vector2i] = [m.exit]
	for r in m.resource_nodes:
		required.append(r["cell"])
	for e in m.enemy_spawns:
		required.append(e["cell"])
	if not m.npc_spawn.is_empty():
		required.append(m.npc_spawn["cell"])
	for pass_i in MAX_REPAIR_PASSES:
		var reach := m.reachable_from_spawn()
		var missing: Array[Vector2i] = []
		for c in required:
			if not reach.has(c):
				missing.append(c)
		if missing.is_empty():
			return
		for c in missing:
			var target := _nearest_in(c, reach)
			_carve(m, c, target)
			m.repairs_applied += 1
			reach = m.reachable_from_spawn()
	assert(false, "WildernessGenerator: repair did not converge for " + m.area_id)


static func _nearest_in(from: Vector2i, cells: Dictionary) -> Vector2i:
	var best := from
	var best_d := INF
	for k in cells.keys():
		var c: Vector2i = k
		var d := float((c - from).length_squared())
		if d < best_d or (is_equal_approx(d, best_d) and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best_d = d
			best = c
	return best


## L-shaped corridor: horizontal first, then vertical. Never touches the border.
static func _carve(m: WildernessMap, from: Vector2i, to: Vector2i) -> void:
	var c := from
	var step_x := signi(to.x - c.x)
	while c.x != to.x:
		_carve_cell(m, c)
		c.x += step_x
	var step_y := signi(to.y - c.y)
	while c.y != to.y:
		_carve_cell(m, c)
		c.y += step_y
	_carve_cell(m, c)


static func _carve_cell(m: WildernessMap, c: Vector2i) -> void:
	if c.x <= 0 or c.y <= 0 or c.x >= m.width - 1 or c.y >= m.height - 1:
		return
	if not m.is_walkable(c.x, c.y):
		m.set_terrain(c.x, c.y, WildernessMap.Terrain.PATH)


static func _clear_pocket(m: WildernessMap, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := center.x + dx
			var y := center.y + dy
			if x > 0 and y > 0 and x < m.width - 1 and y < m.height - 1:
				m.set_terrain(x, y, WildernessMap.Terrain.GROUND)


static func _walkable_cells(m: WildernessMap) -> Array:
	var out: Array = []
	for y in range(1, m.height - 1):
		for x in range(1, m.width - 1):
			if m.is_walkable(x, y):
				out.append(Vector2i(x, y))
	return out


static func _far_enough(c: Vector2i, taken: Array[Vector2i], min_d: int) -> bool:
	for t in taken:
		if absi(t.x - c.x) < min_d and absi(t.y - c.y) < min_d:
			return false
	return true


## Two-octave value noise in [0,1], built only from StableHash — no engine
## noise objects, so results are identical on every platform and version.
static func _fractal_noise(seed_value: int, fx: float, fy: float) -> float:
	return (_value_noise(seed_value, fx, fy) * 0.7 + _value_noise(seed_value + 1, fx * 2.3 + 11.7, fy * 2.3 + 5.1) * 0.3)


static func _value_noise(seed_value: int, fx: float, fy: float) -> float:
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := StableHash.to_unit_float(StableHash.hash_cell(seed_value, x0, y0))
	var b := StableHash.to_unit_float(StableHash.hash_cell(seed_value, x0 + 1, y0))
	var c := StableHash.to_unit_float(StableHash.hash_cell(seed_value, x0, y0 + 1))
	var d := StableHash.to_unit_float(StableHash.hash_cell(seed_value, x0 + 1, y0 + 1))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
