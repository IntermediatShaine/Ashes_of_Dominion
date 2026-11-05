extends TestCase
## The shared exploration framework below the scene level: the static map
## layout (geometry, walkability), the map registry with the three reserved
## POI ids, travel with return destinations, and persistent per-map state.

const VILLAGE_MAP := "village_emberfall"


func _layout() -> MapDefinition:
	return MapDefinition.from_dict(Content.table("village_layouts")["stl_emberfall"])


func _all_site_rects(m: MapDefinition) -> Array:
	var out: Array = []
	for s in m.sites:
		out.append(m.site_rect(s))
	return out


func test_village_layout_is_valid() -> void:
	var m := _layout()
	assert_eq(m.validate(Content.table("buildings")), [] as Array[String])
	assert_eq(m.map_id, VILLAGE_MAP)
	assert_eq(m.world_size(), Vector2(1408, 960))
	var kinds := {SiteRules.KIND_CORE: 0, SiteRules.KIND_PLOT: 0}
	var reserved: Array[String] = []
	for s in m.sites:
		kinds[String(s["kind"])] += 1
		if String(s["reserved_for"]) != "":
			reserved.append(String(s["reserved_for"]))
	assert_eq(kinds[SiteRules.KIND_PLOT], 4, "four free building sites")
	reserved.sort()
	assert_eq(reserved, ["shelter", "stockpile", "village_hearth", "watchpost", "workshop"] as Array[String])
	assert_eq(String(m.site("site_hearth")["role"]), "hearth")
	for entry in ["spawn", "gate", "hearth"]:
		assert_true(m.has_entry(entry), entry)
	assert_eq(m.default_entry, "spawn")
	assert_eq(m.exits.size(), 1)
	assert_eq(String(m.exits[0]["to"]), "world_map")


func test_village_is_walkable_even_when_everything_is_built() -> void:
	var m := _layout()
	var solids := _all_site_rects(m)   # worst case: every site, plots included, built on
	for id in m.entries.keys():
		assert_true(m.is_position_free(m.entries[id], solids), "entry %s is free" % String(id))
	var blocked := m.blocked_cells(solids)
	var reach := m.reachable_cells(m.cell_of(m.entry_position("spawn")), blocked)
	assert_true(reach.size() > 600, "most of the village is reachable")
	for id in m.entries.keys():
		assert_true(reach.has(m.cell_of(m.entries[id])), "entry %s is reachable from the spawn" % String(id))
	for s in m.sites:
		# some cell just outside the footprint must be reachable, or the site
		# could never be interacted with
		var cell: Vector2i = s["cell"]
		var fp: Vector2i = s["footprint"]
		var touching := false
		for x in range(cell.x - 1, cell.x + fp.x + 1):
			for y in range(cell.y - 1, cell.y + fp.y + 1):
				var inside := x >= cell.x and x < cell.x + fp.x and y >= cell.y and y < cell.y + fp.y
				if not inside and reach.has(Vector2i(x, y)):
					touching = true
		assert_true(touching, "site %s can be walked up to" % String(s["id"]))
	var exit_rect: Rect2 = m.exits[0]["rect"]
	var exit_reachable := false
	for c in reach.keys():
		if exit_rect.has_point(Vector2((c.x + 0.5) * m.cell_size, (c.y + 0.5) * m.cell_size)):
			exit_reachable = true
	assert_true(exit_reachable, "the gate can be reached")


func test_map_geometry() -> void:
	var m := _layout()
	var shelter := m.site("site_shelter")
	assert_eq(m.site_rect(shelter), Rect2(256, 288, 96, 64), "cells * cell size")
	assert_eq(m.site_anchor(shelter), Vector2(304, 352), "middle of the footprint's bottom edge")
	assert_eq(m.border_rects().size(), 4)
	assert_eq(m.playable_rect(), Rect2(32, 32, 1344, 896))
	assert_false(m.is_position_free(Vector2(10, 10)), "inside the closed border")
	assert_false(m.is_position_free(Vector2(1400, 500)))
	assert_true(m.is_position_free(Vector2(300, 320)), "a free spot…")
	assert_false(m.is_position_free(Vector2(300, 320), [m.site_rect(shelter)]), "…until something is built there")
	assert_eq(m.cell_of(Vector2(65, 31)), Vector2i(2, 0))
	assert_eq(m.entry_position("gate"), Vector2(704, 816))
	assert_eq(m.entry_position("no_such_entry"), m.entry_position("spawn"), "unknown entries use the default")
	# a damaged layout is reported, not accepted
	var raw: Dictionary = (Content.table("village_layouts")["stl_emberfall"] as Dictionary).duplicate(true)
	raw["sites"][1]["cell"] = [21, 13]             # on top of the hearth
	raw["sites"][2]["reserved_for"] = "cathedral"  # unknown building
	raw["entries"]["gate"] = [0.2, 0.2]            # in the border
	raw["default_entry"] = "nowhere"
	var errors := "\n".join(MapDefinition.from_dict(raw).validate(Content.table("buildings")))
	for fragment in ["overlaps another site", "unknown building 'cathedral'", "entry 'gate' is inside something solid", "default_entry 'nowhere'", "building 'workshop' needs exactly one reserved site"]:
		assert_true(errors.contains(fragment), "reports: " + fragment)


func maps_reserved_for_test() -> Dictionary:
	var maps := Content.table("maps").duplicate(true)
	maps["lumber_camp"]["status"] = MapRegistry.STATUS_RESERVED
	return maps


func test_map_registry_and_reserved_poi_ids() -> void:
	var maps := Content.table("maps")
	assert_eq(MapRegistry.ids_of_kind(maps, MapRegistry.KIND_POI), ["forgotten_shrine", "lumber_camp", "ruined_watchtower"] as Array[String])
	for id in ["lumber_camp", "ruined_watchtower", "forgotten_shrine"]:
		var def := MapRegistry.describe(maps, id)
		assert_eq(def["kind"], MapRegistry.KIND_POI, id)
		assert_eq(def["status"], MapRegistry.STATUS_IMPLEMENTED, id)
		assert_true(String(def["name"]) != "", id)
		assert_eq(MapRegistry.enter_blocking_reason(maps, id), "", id + " is implemented")
	assert_eq(MapRegistry.map_for_settlement(maps, "stl_emberfall"), VILLAGE_MAP)
	assert_eq(MapRegistry.enter_blocking_reason(maps, VILLAGE_MAP), "")
	assert_eq(MapRegistry.scene_key(maps, VILLAGE_MAP), "settlement")
	assert_true(Router.SCENES.has(MapRegistry.scene_key(maps, VILLAGE_MAP)), "the registry names a real scene")
	assert_eq(MapRegistry.entry_for(maps, VILLAGE_MAP), "spawn")
	assert_eq(MapRegistry.entry_for(maps, VILLAGE_MAP, "expedition_return"), "gate")
	assert_eq(MapRegistry.entry_for(maps, VILLAGE_MAP, "resurrection"), "hearth")
	# generated expedition areas answer the same questions without being listed
	var wild := MapRegistry.describe(maps, "wilderness:greywood_edge")
	assert_eq(wild["kind"], MapRegistry.KIND_WILDERNESS)
	assert_eq(wild["scene"], "exploration")
	assert_eq(wild["landmark_id"], "greywood_edge")
	assert_eq(MapRegistry.enter_blocking_reason(maps, "wilderness:greywood_edge"), "")
	assert_true(MapRegistry.describe(maps, "wilderness:").is_empty())
	assert_true(MapRegistry.enter_blocking_reason(maps, "atlantis").contains("Unknown map"))


func test_travel_enter_leave_and_return_destinations() -> void:
	var save := TestFixtures.new_save()
	var travel := MapTravelService.new(save, Content)
	var seen: Array = []
	travel.location_changed.connect(func(map_id: String, entry_id: String): seen.append([map_id, entry_id]))
	assert_eq(travel.current_map_id(), VILLAGE_MAP, "a new game starts in the village")
	assert_eq(travel.current_entry_id(), "spawn")
	assert_eq(travel.home_map_id(), VILLAGE_MAP)

	var before := save.universe.location.duplicate(true)
	var reserved := maps_reserved_for_test()
	assert_true(MapRegistry.enter_blocking_reason(reserved, "lumber_camp").contains("not built yet"), "reserved content is still refused")
	assert_fail(travel.enter("atlantis"), "unknown")
	assert_eq(save.universe.location, before, "a refused journey changes nothing")
	assert_eq(seen, [])

	# out through the gate: the village is remembered, to be re-entered at the gate
	var out := travel.enter("wilderness:greywood_edge", "", true, "gate")
	assert_ok(out)
	assert_eq(out.value, {"map_id": "wilderness:greywood_edge", "entry_id": "spawn", "scene": "exploration"})
	assert_eq(save.universe.location["return_stack"], [{"map_id": VILLAGE_MAP, "entry_id": "gate"}])
	# deeper: a second return destination stacks on top
	assert_ok(travel.enter("wilderness:ashen_crossroads", "north"))
	assert_eq(save.universe.location["return_stack"].size(), 2)
	assert_eq(save.universe.location["return_stack"][1], {"map_id": "wilderness:greywood_edge", "entry_id": "spawn"})
	assert_true(save.universe.validate().is_empty(), "; ".join(save.universe.validate()))
	var back := travel.leave()
	assert_eq(back.value, {"map_id": "wilderness:greywood_edge", "entry_id": "spawn", "scene": "exploration"})
	back = travel.leave()
	assert_eq(back.value, {"map_id": VILLAGE_MAP, "entry_id": "gate", "scene": "settlement"})
	assert_eq(save.universe.location["return_stack"], [])
	back = travel.leave()
	assert_eq(back.value["map_id"], VILLAGE_MAP, "with nothing to return to, leaving leads home")
	assert_eq(back.value["entry_id"], "spawn")
	assert_eq(seen.size(), 5)

	assert_ok(travel.enter("wilderness:greywood_edge"))
	assert_eq(travel.arrive_home("resurrection").value["entry_id"], "hearth")
	assert_eq(save.universe.location, {"map_id": VILLAGE_MAP, "entry_id": "hearth", "return_stack": []}, "an outright arrival keeps no way back")
	travel.set_entry("gate")
	assert_eq(travel.current_entry_id(), "gate")


func test_arrival_position() -> void:
	var save := TestFixtures.new_save()
	var travel := MapTravelService.new(save, Content)
	var m := _layout()
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry), m.entry_position("spawn"))
	travel.set_entry("gate")
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry), m.entry_position("gate"))
	# a remembered spot wins while it is free…
	travel.remember_position(Vector2(500.4, 600.6))
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry), Vector2(500, 601))
	var free := func(p: Vector2) -> bool: return m.is_position_free(p)
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry, free), Vector2(500, 601))
	# …and is ignored once something stands there
	var taken := func(_p: Vector2) -> bool: return false
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry, taken), m.entry_position("gate"))
	# arriving through an entry forgets the spot
	travel.set_entry("hearth")
	assert_false(MapLocation.has_position(save.universe.location))
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry), m.entry_position("hearth"))
	# a scene for a map the player is not recorded in uses its default entry
	assert_eq(travel.arrival_position("some_other_map", m.entries, m.default_entry), m.entry_position("spawn"))
	MapLocation.set_entry(save.universe.location, "an_entry_that_was_removed")
	assert_eq(travel.arrival_position(VILLAGE_MAP, m.entries, m.default_entry), m.entry_position("spawn"))


func test_expeditions_record_where_to_come_back_to() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save())
	var u := b.save.universe
	assert_eq(u.location, {"map_id": VILLAGE_MAP, "entry_id": "spawn", "return_stack": []})
	TestFixtures.start_any_expedition(b)
	var destination := u.active_expedition().destination_id
	assert_eq(u.location["map_id"], "wilderness:" + destination)
	assert_eq(u.location["return_stack"], [{"map_id": VILLAGE_MAP, "entry_id": "gate"}])
	# the record survives a save taken in the field
	var reloaded := TestFixtures.round_trip(b)
	assert_eq(reloaded.universe.location, u.location)
	assert_ok(b.expeditions.finish("returned"))
	assert_eq(u.location, {"map_id": VILLAGE_MAP, "entry_id": "gate", "return_stack": []}, "home through the gate")
	# a defeat ends at the hearth instead
	TestFixtures.start_any_expedition(b)
	assert_ok(b.transitions.on_protagonist_defeated())
	assert_eq(u.location, {"map_id": VILLAGE_MAP, "entry_id": "hearth", "return_stack": []}, "the curse sets you down by the hearth")
	assert_true(u.validate().is_empty(), "; ".join(u.validate()))


func test_persistent_map_state() -> void:
	var b := TestFixtures.bind(TestFixtures.new_save())
	var u := b.save.universe
	assert_false(MapStateStore.has_record(u, "lumber_camp"))
	assert_eq(MapStateStore.get_flag(u, "lumber_camp", "gate_open", false), false, "reading creates nothing")
	assert_false(MapStateStore.has_record(u, "lumber_camp"))
	MapStateStore.set_flag(u, "lumber_camp", "gate_open", true)
	MapStateStore.set_flag(u, "lumber_camp", "logs_taken", 3)
	assert_true(MapStateStore.mark_done(u, "lumber_camp", "chest_1"), "first time")
	assert_false(MapStateStore.mark_done(u, "lumber_camp", "chest_1"), "only once")
	assert_true(MapStateStore.is_done(u, "lumber_camp", "chest_1"))
	assert_false(MapStateStore.is_done(u, "lumber_camp", "chest_2"))
	# it shares the record expedition areas already use, without disturbing it
	TestFixtures.start_any_expedition(b)
	var area := b.expeditions.build_area()
	var node: Dictionary = area.resource_nodes[0]
	b.expeditions.collect_resource(node["key"], node["resource_id"], int(node["amount"]))
	var landmark := u.active_expedition().destination_id
	MapStateStore.set_flag(u, landmark, "camp_found", true)
	assert_true((u.world_modifications[landmark]["harvested"] as Dictionary).has(node["key"]), "harvest history untouched")
	# and it is saved with the universe
	var loaded := TestFixtures.round_trip(b).universe
	assert_eq(MapStateStore.get_flag(loaded, "lumber_camp", "gate_open"), true)
	assert_eq(int(MapStateStore.get_flag(loaded, "lumber_camp", "logs_taken")), 3)
	assert_true(MapStateStore.is_done(loaded, "lumber_camp", "chest_1"))
	assert_eq(MapStateStore.get_flag(loaded, landmark, "camp_found"), true)
	assert_true(b.expeditions.build_area().resource_nodes[0]["depleted"], "the harvested node is still depleted")
	MapStateStore.clear_flag(u, "lumber_camp", "gate_open")
	assert_eq(MapStateStore.get_flag(u, "lumber_camp", "gate_open", "unset"), "unset")
