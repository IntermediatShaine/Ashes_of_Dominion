class_name MapDefinition
extends RefCounted
## Static description of a hand-authored explorable map (the village, later
## POIs), parsed from one layout entry such as
## data/village/village_layouts.json -> "stl_emberfall".
##
## Pure data + geometry: no nodes, no artwork. Everything a scene needs to
## build the map — ground, borders, entries, exits, props, building sites —
## and everything gameplay needs to reason about it (which cells are blocked,
## whether a spot is free) comes from here, in pixels unless a name says cells.
## Visuals are only ever named by visual id (see data/visuals/visual_registry.json).

var map_id: String = ""
var display_name: String = ""
var cell_size: int = 32
var width: int = 0
var height: int = 0
## Cells along every edge that are closed off (the tree line).
var border_cells: int = 1
var ground_base: String = ""
## [{visual: String, rect: Rect2i (cells)}], drawn in order over the base.
var ground_patches: Array[Dictionary] = []
## entry id -> Vector2 (pixels)
var entries: Dictionary = {}
var default_entry: String = ""
## [{id, rect: Rect2 (pixels), to, return_entry, prompt, visual}]
var exits: Array[Dictionary] = []
## [{id, kind, reserved_for, role, cell: Vector2i, footprint: Vector2i}]
var sites: Array[Dictionary] = []
## [{visual, position: Vector2 (pixels, base anchor), solid: Rect2 | null}]
var props: Array[Dictionary] = []
## {visual, spacing (cells)} or {} — decoration along the closed border.
var border: Dictionary = {}
var _raw: Dictionary = {}


static func from_dict(d: Dictionary) -> MapDefinition:
	var m := MapDefinition.new()
	m._raw = d
	m.map_id = DictUtil.get_string(d, "map_id")
	m.display_name = DictUtil.get_string(d, "name", m.map_id)
	m.cell_size = maxi(1, DictUtil.get_int(d, "cell_size", 32))
	m.width = DictUtil.get_int(d, "width")
	m.height = DictUtil.get_int(d, "height")
	m.border_cells = maxi(0, DictUtil.get_int(d, "border_cells", 1))
	var ground := DictUtil.get_dict(d, "ground")
	m.ground_base = DictUtil.get_string(ground, "base")
	for patch in DictUtil.get_array(ground, "patches"):
		if patch is Dictionary:
			m.ground_patches.append({"visual": DictUtil.get_string(patch, "visual"), "rect": _rect2i(DictUtil.get_array(patch, "rect"))})
	var raw_entries := DictUtil.get_dict(d, "entries")
	for id in DictUtil.sorted_keys(raw_entries):
		m.entries[String(id)] = _vec2(raw_entries[id]) * float(m.cell_size)
	m.default_entry = DictUtil.get_string(d, "default_entry")
	for raw_exit in DictUtil.get_array(d, "exits"):
		if not (raw_exit is Dictionary):
			continue
		var cells := _rect2i(DictUtil.get_array(raw_exit, "rect"))
		m.exits.append({
			"id": DictUtil.get_string(raw_exit, "id"),
			"rect": Rect2(Vector2(cells.position) * float(m.cell_size), Vector2(cells.size) * float(m.cell_size)),
			"to": DictUtil.get_string(raw_exit, "to"),
			"return_entry": DictUtil.get_string(raw_exit, "return_entry"),
			"prompt": DictUtil.get_string(raw_exit, "prompt", "Leave"),
			"visual": DictUtil.get_string(raw_exit, "visual"),
		})
	for raw_site in DictUtil.get_array(d, "sites"):
		if not (raw_site is Dictionary):
			continue
		m.sites.append({
			"id": DictUtil.get_string(raw_site, "id"),
			"kind": DictUtil.get_string(raw_site, "kind"),
			"reserved_for": DictUtil.get_string(raw_site, "reserved_for"),
			"role": DictUtil.get_string(raw_site, "role"),
			"cell": _vec2i(DictUtil.get_array(raw_site, "cell")),
			"footprint": _vec2i(DictUtil.get_array(raw_site, "footprint")),
		})
	for raw_prop in DictUtil.get_array(d, "props"):
		if not (raw_prop is Dictionary):
			continue
		var position := _vec2(raw_prop.get("at", [])) * float(m.cell_size)
		var solid = null
		if raw_prop.has("solid"):
			var size := _vec2(raw_prop["solid"]) * float(m.cell_size)
			# The solid part is the base of the prop: centred on the anchor, sitting on it.
			solid = Rect2(position - Vector2(size.x * 0.5, size.y), size)
		m.props.append({"visual": DictUtil.get_string(raw_prop, "visual"), "position": position, "solid": solid})
	m.border = DictUtil.get_dict(d, "border").duplicate(true)
	return m


func world_size() -> Vector2:
	return Vector2(width * cell_size, height * cell_size)


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, world_size())


## The area the player can be in (inside the closed border).
func playable_rect() -> Rect2:
	var margin := float(border_cells * cell_size)
	return Rect2(Vector2(margin, margin), world_size() - Vector2(margin, margin) * 2.0)


func has_entry(entry_id: String) -> bool:
	return entries.has(entry_id)


func entry_position(entry_id: String) -> Vector2:
	if entries.has(entry_id):
		return entries[entry_id]
	if entries.has(default_entry):
		return entries[default_entry]
	return world_size() * 0.5


func site(site_id: String) -> Dictionary:
	for s in sites:
		if String(s["id"]) == site_id:
			return s
	return {}


## Footprint of a site in pixels: its collision and the base of its interaction area.
func site_rect(site_def: Dictionary) -> Rect2:
	var cell: Vector2i = site_def.get("cell", Vector2i.ZERO)
	var footprint: Vector2i = site_def.get("footprint", Vector2i.ONE)
	return Rect2(Vector2(cell) * float(cell_size), Vector2(footprint) * float(cell_size))


## Where a site's visual stands: the middle of the footprint's bottom edge.
func site_anchor(site_def: Dictionary) -> Vector2:
	var r := site_rect(site_def)
	return Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y)


func exit_by_id(exit_id: String) -> Dictionary:
	for e in exits:
		if String(e["id"]) == exit_id:
			return e
	return {}


## The four closed strips along the map's edges, in pixels.
func border_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var margin := float(border_cells * cell_size)
	if margin <= 0.0:
		return out
	var size := world_size()
	out.append(Rect2(0, 0, size.x, margin))
	out.append(Rect2(0, size.y - margin, size.x, margin))
	out.append(Rect2(0, margin, margin, size.y - margin * 2.0))
	out.append(Rect2(size.x - margin, margin, margin, size.y - margin * 2.0))
	return out


## Solid rectangles that never change: the border and solid props.
func static_solid_rects() -> Array[Rect2]:
	var out := border_rects()
	for p in props:
		if p["solid"] is Rect2:
			out.append(p["solid"])
	return out


## True when a body of `radius` pixels fits at `position` given the static
## solids plus `extra_solids` (for example the footprints of built-on sites).
func is_position_free(position: Vector2, extra_solids: Array = [], radius: float = 10.0) -> bool:
	if not playable_rect().grow(-radius).has_point(position):
		return false
	for r in static_solid_rects():
		if r.grow(radius).has_point(position):
			return false
	for r in extra_solids:
		if r is Rect2 and (r as Rect2).grow(radius).has_point(position):
			return false
	return true


## Cells a walker cannot stand in: Dictionary used as a set of Vector2i.
## A cell counts as blocked when a solid covers its centre.
func blocked_cells(extra_solids: Array = []) -> Dictionary:
	var solids: Array = []
	solids.append_array(static_solid_rects())
	solids.append_array(extra_solids)
	var blocked := {}
	for y in height:
		for x in width:
			var centre := Vector2((x + 0.5) * cell_size, (y + 0.5) * cell_size)
			for r in solids:
				if r is Rect2 and (r as Rect2).has_point(centre):
					blocked[Vector2i(x, y)] = true
					break
	return blocked


## Cells reachable from `from_cell` over unblocked cells (4-neighbour flood).
func reachable_cells(from_cell: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {}
	if blocked.has(from_cell) or not _in_bounds(from_cell):
		return seen
	var queue: Array[Vector2i] = [from_cell]
	seen[from_cell] = true
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or blocked.has(n) or not _in_bounds(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func cell_of(position: Vector2) -> Vector2i:
	return Vector2i(int(floor(position.x / cell_size)), int(floor(position.y / cell_size)))


## Problems in the layout itself; empty when it is usable.
## `building_defs` (optional) lets reserved sites be checked against content.
func validate(building_defs: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var label := map_id if map_id != "" else "<map without id>"
	if map_id == "":
		errors.append("map layout has no map_id")
	if width <= border_cells * 2 or height <= border_cells * 2:
		errors.append("%s: size %dx%d leaves no room inside the border" % [label, width, height])
		return errors
	if ground_base == "":
		errors.append("%s: ground.base visual id is missing" % label)
	if entries.is_empty():
		errors.append("%s: no entries" % label)
	if not entries.has(default_entry):
		errors.append("%s: default_entry '%s' is not an entry" % [label, default_entry])
	var cells := Rect2i(0, 0, width, height)
	for patch in ground_patches:
		var pr: Rect2i = patch["rect"]
		if String(patch["visual"]) == "" or pr.size.x <= 0 or pr.size.y <= 0 or not cells.encloses(pr):
			errors.append("%s: ground patch %s is malformed or out of bounds" % [label, str(pr)])
	var seen_sites := {}
	var site_rects: Array = []
	for s in sites:
		var sid := String(s["id"])
		if sid == "" or seen_sites.has(sid):
			errors.append("%s: site id '%s' is missing or duplicated" % [label, sid])
		seen_sites[sid] = true
		var kind := String(s["kind"])
		if kind != SiteRules.KIND_CORE and kind != SiteRules.KIND_PLOT:
			errors.append("%s: site %s has unknown kind '%s'" % [label, sid, kind])
		if kind == SiteRules.KIND_CORE:
			if String(s["reserved_for"]) == "":
				errors.append("%s: core site %s has no reserved_for" % [label, sid])
			elif not building_defs.is_empty() and not building_defs.has(String(s["reserved_for"])):
				errors.append("%s: site %s is reserved for unknown building '%s'" % [label, sid, String(s["reserved_for"])])
		var footprint: Vector2i = s["footprint"]
		var r := site_rect(s)
		if footprint.x <= 0 or footprint.y <= 0 or not playable_rect().encloses(r):
			errors.append("%s: site %s footprint is empty or outside the playable area" % [label, sid])
		for other in site_rects:
			if (other as Rect2).intersects(r):
				errors.append("%s: site %s overlaps another site" % [label, sid])
		site_rects.append(r)
	for id in entries.keys():
		if not is_position_free(entries[id], site_rects):
			errors.append("%s: entry '%s' is inside something solid" % [label, String(id)])
	var seen_exits := {}
	for e in exits:
		var eid := String(e["id"])
		if eid == "" or seen_exits.has(eid):
			errors.append("%s: exit id '%s' is missing or duplicated" % [label, eid])
		seen_exits[eid] = true
		if String(e["to"]) == "":
			errors.append("%s: exit %s leads nowhere" % [label, eid])
		if not world_rect().encloses(e["rect"]) or (e["rect"] as Rect2).size.x <= 0.0:
			errors.append("%s: exit %s is out of bounds" % [label, eid])
		if String(e["return_entry"]) != "" and not entries.has(String(e["return_entry"])):
			errors.append("%s: exit %s returns to unknown entry '%s'" % [label, eid, String(e["return_entry"])])
	for p in props:
		if String(p["visual"]) == "" or not world_rect().has_point(p["position"]):
			errors.append("%s: a prop has no visual or is out of bounds" % label)
	if not building_defs.is_empty():
		for id in DictUtil.sorted_keys(building_defs):
			if DictUtil.get_string(building_defs[id], "placement") != "reserved":
				continue
			var found := 0
			for s in sites:
				if String(s["kind"]) == SiteRules.KIND_CORE and String(s["reserved_for"]) == String(id):
					found += 1
			if found != 1:
				errors.append("%s: building '%s' needs exactly one reserved site, found %d" % [label, String(id), found])
	return errors


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


static func _vec2(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


static func _vec2i(raw: Array) -> Vector2i:
	if raw.size() == 2:
		return Vector2i(int(round(float(raw[0]))), int(round(float(raw[1]))))
	return Vector2i.ZERO


static func _rect2i(raw: Array) -> Rect2i:
	if raw.size() == 4:
		return Rect2i(int(round(float(raw[0]))), int(round(float(raw[1]))), int(round(float(raw[2]))), int(round(float(raw[3]))))
	return Rect2i()
