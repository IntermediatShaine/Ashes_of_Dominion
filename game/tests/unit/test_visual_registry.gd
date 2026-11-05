extends TestCase
## The visual customization system: every image is reached through a stable
## visual id in data/visuals/visual_registry.json, ids fall back in a defined
## order, and changing an entry changes what is drawn — without any script
## knowing a file name.

const WORKSHOP := "building.workshop.level_1"


func after_each() -> void:
	# Tests may swap the active registry; always put the real one back.
	Visuals.load_registry(VisualResolver.DEFAULT_REGISTRY_PATH)


func _private_resolver(visuals: Dictionary, fallback: String = "missing") -> VisualResolver:
	var r := VisualResolver.new()
	r.set_registry({"fallback_visual": fallback, "visuals": visuals})
	return r


func test_registry_loads_without_errors() -> void:
	assert_eq(Visuals.load_errors, [] as Array[String], "the shipped registry is clean")
	assert_true(Visuals.has_visual(Visuals.fallback_id), "the fallback itself is registered")
	assert_true(Visuals.ids().size() >= 40)
	for id in Visuals.ids():
		var v := Visuals.resolve(id)
		assert_true(v["exact"], id)
		assert_false(v["is_fallback"], id)
		assert_true(v["texture"] != null, id + " has a texture")
		var size: Vector2 = v["frame_size"]
		assert_true(size.x > 0.0 and size.y > 0.0, id + " has a size")
		assert_true(String(v["path"]).begins_with("res://assets/"), id + " lives under assets/")


func test_every_visual_the_village_needs_is_registered() -> void:
	var layout: Dictionary = Content.table("village_layouts")["stl_emberfall"]
	var needed := VillageVisuals.required_ids(Content.table("buildings"), layout, Content.table("resources"))
	assert_true(needed.size() >= 30, "the list is not trivially short")
	for id in needed:
		assert_true(Visuals.has_visual(id), "registry has an entry for " + id)
	for expected in ["building.village_hearth.level_0", "building.shelter.level_3", "building.workshop.level_2", "building.stockpile.level_3", "building.watchpost.level_2", "building.palisade.level_1", "site.plot.empty", "site.construction", "terrain.village.grass", "marker.village_gate", "icon.resource.wood"]:
		assert_true(needed.has(expected), expected + " is on the list")
	assert_true(Visuals.has_visual(Visuals.resolved_id("actor.player")), "the protagonist")


func test_no_script_or_scene_names_an_image_file() -> void:
	# The whole point of the registry: image paths live in one data file.
	var offenders: Array[String] = []
	_scan("res://scripts", [".gd"], offenders)
	_scan("res://scenes", [".tscn"], offenders)
	assert_eq(offenders, [] as Array[String], "image paths outside the visual registry")


func _scan(dir_path: String, extensions: Array, offenders: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir_path + "/" + sub, extensions, offenders)
	for f in d.get_files():
		var wanted := false
		for ext in extensions:
			if f.ends_with(ext):
				wanted = true
		if not wanted:
			continue
		var text := TestCase.read_text(dir_path + "/" + f)
		for needle in [".png", ".jpg", ".webp", ".svg", "res://assets/"]:
			if text.contains(needle):
				offenders.append("%s/%s mentions %s" % [dir_path, f, needle])


func test_fallback_order() -> void:
	var tex := "res://assets/placeholders/common/missing.png"
	var r := _private_resolver({
		"missing": {"texture": tex},
		"building": {"texture": tex},
		"building.shelter": {"texture": tex},
		"building.shelter.level_1": {"texture": tex},
	})
	assert_eq(r.load_errors, [] as Array[String])
	assert_eq(r.resolved_id("building.shelter.level_1"), "building.shelter.level_1")
	assert_eq(r.resolved_id("building.shelter.level_9"), "building.shelter", "a missing level falls back to the building")
	assert_eq(r.resolved_id("building.workshop.level_1"), "building", "an unknown building to the family")
	assert_eq(r.resolved_id("actor.wolf"), "missing", "nothing matches: the fallback visual")
	assert_true(r.resolve("actor.wolf")["is_fallback"])
	assert_false(r.resolve("building.shelter.level_9")["is_fallback"])
	assert_false(r.resolve("building.shelter.level_9")["exact"])
	assert_false(r.has_visual("building.shelter.level_9"), "has_visual never falls back")
	assert_true(r.resolve("missing")["exact"])
	assert_false(r.resolve("missing")["is_fallback"])
	r.free()


func test_extends_overrides_only_what_it_names() -> void:
	var r := _private_resolver({
		"missing": {"texture": "res://assets/placeholders/common/missing.png"},
		"base": {"texture": "res://assets/placeholders/buildings/shelter_level_1.png", "anchor": "bottom_center", "offset": [0, 6], "z_index": 2},
		"variant": {"extends": "base", "offset": [3, -4], "modulate": "#ff8080"},
	})
	assert_eq(r.load_errors, [] as Array[String])
	var v := r.resolve("variant")
	assert_eq(v["path"], "res://assets/placeholders/buildings/shelter_level_1.png", "inherited")
	assert_eq(v["anchor"], "bottom_center", "inherited")
	assert_eq(v["z_index"], 2, "inherited")
	assert_eq(v["offset"], Vector2(3, -4), "overridden")
	assert_eq(v["modulate"], Color("#ff8080"), "added")
	assert_eq(r.resolve("base")["offset"], Vector2(0, 6), "the base is untouched")
	r.free()


func test_broken_registry_is_reported_not_fatal() -> void:
	var r := _private_resolver({
		"missing": {"texture": "res://assets/placeholders/common/missing.png"},
		"no_file": {"texture": "res://assets/placeholders/does_not_exist.png"},
		"no_texture": {"anchor": "center"},
		"bad_anchor": {"texture": "res://assets/placeholders/common/missing.png", "anchor": "sideways"},
		"bad_region": {"texture": "res://assets/placeholders/common/missing.png", "region": [0, 0, 8]},
		"orphan": {"extends": "nobody"},
		"loop_a": {"extends": "loop_b"},
		"loop_b": {"extends": "loop_a"},
		"few_frames": {"texture": "res://assets/placeholders/common/missing.png", "hframes": 4, "facing_frames": true},
	})
	var text := "\n".join(r.load_errors)
	for fragment in ["no_file: cannot load texture", "no_texture has no texture", "bad_anchor has unknown anchor", "bad_region region must be", "orphan extends unknown visual", "extends itself (cycle)", "few_frames uses facing_frames"]:
		assert_true(text.contains(fragment), "reports: " + fragment)
	# a visual whose texture is missing still resolves (to nothing) instead of crashing
	assert_true(r.resolve("no_file")["texture"] == null)
	r.free()
	var no_fallback := _private_resolver({"a": {"texture": "res://assets/placeholders/common/missing.png"}}, "nope")
	assert_true("\n".join(no_fallback.load_errors).contains("fallback_visual 'nope'"))
	no_fallback.free()
	var from_file := VisualResolver.new()
	assert_false(from_file.load_registry("res://data/visuals/no_such_registry.json"))
	assert_eq(from_file.load_errors.size(), 1)
	from_file.free()


func test_sprite_geometry_comes_from_the_entry() -> void:
	var v := Visuals.resolve(WORKSHOP)
	var size: Vector2 = v["frame_size"]
	var extra: Vector2 = v["offset"]
	var sprite := Visuals.make_sprite(WORKSHOP)
	assert_eq(sprite.texture, v["texture"])
	assert_false(sprite.centered)
	assert_eq(sprite.offset, Vector2(-size.x * 0.5, -size.y) + extra, "bottom_center: the image stands on the node position")
	assert_eq(sprite.get_meta("visual_id"), WORKSHOP)
	sprite.free()
	# a facing sheet: eight frames, one shown at a time
	var hero := Visuals.make_sprite("actor.player")
	assert_eq(hero.hframes, 8)
	hero.set_facing_index(6)
	assert_eq(hero.frame, 6)
	var sheet: Vector2 = Visuals.resolve("actor.player")["texture"].get_size()
	assert_eq(Visuals.resolve("actor.player")["frame_size"], Vector2(sheet.x / 8.0, sheet.y))
	var icon := Visuals.ui_texture("actor.player")
	assert_true(icon is AtlasTexture, "UI gets a single frame cut from the sheet")
	assert_eq((icon as AtlasTexture).region.size, Vector2(sheet.x / 8.0, sheet.y))
	assert_eq(Visuals.ui_texture("icon.resource.wood"), Visuals.texture("icon.resource.wood"), "a plain image is used as it is")
	hero.free()


func test_changing_an_entry_changes_a_live_sprite() -> void:
	var sprite := Visuals.make_sprite(WORKSHOP)
	tree.root.add_child(sprite)
	var before: Texture2D = sprite.texture
	var other: Texture2D = Visuals.texture("building.watchpost.level_2")
	assert_ne(before, other)
	# 1) one entry replaced at runtime
	Visuals.override_entry(WORKSHOP, {"texture": Visuals.resolve("building.watchpost.level_2")["path"], "anchor": "center"})
	assert_eq(sprite.texture, other, "the sprite followed the registry")
	assert_eq(sprite.offset, -other.get_size() * 0.5, "and its placement follows the new entry")
	# 2) a whole registry file swapped in
	var doc: Dictionary = JSON.parse_string(TestCase.read_text(VisualResolver.DEFAULT_REGISTRY_PATH))
	doc["visuals"][WORKSHOP]["texture"] = doc["visuals"]["building.shelter.level_3"]["texture"]
	var path := temp_dir + "/registry.json"
	TestCase.write_text(path, JSON.stringify(doc))
	assert_true(Visuals.load_registry(path))
	assert_eq(sprite.texture, Visuals.texture("building.shelter.level_3"))
	# 3) and back
	assert_true(Visuals.load_registry(VisualResolver.DEFAULT_REGISTRY_PATH))
	assert_eq(sprite.texture, before)
	sprite.queue_free()
	await tree.process_frame


func test_expedition_objects_pick_up_registry_art_when_it_exists() -> void:
	# Objects that predate the registry keep their code-drawn look until an
	# entry with their id is added; then they use it — no code change.
	var holder := Node2D.new()
	tree.root.add_child(holder)
	assert_true(VisualSprite.attach_if_registered(holder, "actor.enemy.marauder") == null, "no entry: code-drawn")
	Visuals.override_entry("actor.enemy.marauder", {"texture": "res://assets/placeholders/common/missing.png"})
	var sprite := VisualSprite.attach_if_registered(holder, "actor.enemy.marauder")
	assert_true(sprite != null)
	assert_eq(sprite.get_parent(), holder)
	assert_eq(sprite.texture, Visuals.texture("placeholder.missing"))
	holder.queue_free()
	await tree.process_frame
