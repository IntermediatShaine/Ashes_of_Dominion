class_name VisualResolver
extends Node
## Autoload "Visuals": turns stable visual ids into textures and sprites.
##
## This is the game's "style sheet". Gameplay objects never name an image
## file; they ask for an id such as `building.workshop.level_1`, and
## data/visuals/visual_registry.json decides which texture, region, frame
## layout, offset, scale and tint that id means. Replacing placeholder art
## with final art is an edit to that file — no script changes (see
## docs/ART_SWAP_GUIDE.md).
##
## Collisions, interaction areas and every gameplay number come from layout
## and content data, never from a texture, so a swapped image can be any size.
##
## Lookup rules:
##   1. the exact id;
##   2. otherwise its parent path, repeatedly: a.b.c -> a.b -> a;
##   3. otherwise the registry's `fallback_visual` (a loud checkerboard).
## An entry may `extends` another entry and override only some fields.
##
## Entry fields (all optional except `texture` or `extends`):
##   texture        res:// path of the image
##   region         [x, y, w, h] sub-rectangle of the texture, in pixels
##   hframes        columns of a spritesheet (default 1)
##   vframes        rows of a spritesheet (default 1)
##   frame          which frame to show (default 0)
##   facing_frames  true: frames 0..7 are the eight facings E, SE, S, SW, W, NW, N, NE
##   animations     {name: {frames: [..], fps: n, loop: bool}} — carried through for
##                  whoever animates the sprite; the resolver itself shows one frame
##   anchor         which point of the frame sits on the object's position:
##                  "center" (default), "bottom_center", "top_left"
##   offset         [x, y] extra pixel offset
##   scale          number or [x, y] (default 1)
##   modulate       "#rrggbb" or "#rrggbbaa" tint (default white)
##   z_index        draw order relative to siblings (default 0; -1 = under actors)
##   tile           true: the texture repeats to fill an area (ground)

signal registry_changed()

const DEFAULT_REGISTRY_PATH := "res://data/visuals/visual_registry.json"
const ANCHOR_CENTER := "center"
const ANCHOR_BOTTOM_CENTER := "bottom_center"
const ANCHOR_TOP_LEFT := "top_left"
const ANCHORS := [ANCHOR_CENTER, ANCHOR_BOTTOM_CENTER, ANCHOR_TOP_LEFT]
const VisualSpriteScript := preload("res://scripts/visuals/visual_sprite.gd")

var registry_path: String = DEFAULT_REGISTRY_PATH
## Problems found while loading the registry (missing textures, bad fields…).
var load_errors: Array[String] = []
var fallback_id: String = ""

var _entries: Dictionary = {}
var _resolved: Dictionary = {}
var _textures: Dictionary = {}


func _ready() -> void:
	load_registry(DEFAULT_REGISTRY_PATH)
	for e in load_errors:
		push_error("Visuals: " + e)


# --- loading -----------------------------------------------------------------------

## Reads a registry file and makes it the active one. Returns true when it
## loaded without errors; details are in `load_errors`.
func load_registry(path: String) -> bool:
	registry_path = path
	if not FileAccess.file_exists(path):
		return _fail_load("missing registry file " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _fail_load("cannot open " + path)
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return _fail_load("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	if not (json.data is Dictionary):
		return _fail_load(path + " root is not an object")
	return set_registry(json.data)


## Makes an already parsed registry document the active one.
func set_registry(data: Dictionary) -> bool:
	load_errors.clear()
	_entries.clear()
	_resolved.clear()
	fallback_id = DictUtil.get_string(data, "fallback_visual")
	var raw := DictUtil.get_dict(data, "visuals")
	if raw.is_empty():
		load_errors.append("registry has no visuals")
	for id in DictUtil.sorted_keys(raw):
		if not (raw[id] is Dictionary):
			load_errors.append("visual %s is not an object" % String(id))
			continue
		var merged := _merged_entry(raw, String(id), [])
		_validate_entry(String(id), merged)
		_entries[String(id)] = merged
	if fallback_id == "" or not _entries.has(fallback_id):
		load_errors.append("fallback_visual '%s' is not a registered visual" % fallback_id)
	registry_changed.emit()
	return load_errors.is_empty()


## Re-reads the registry file (after editing it while the game runs).
func reload() -> bool:
	_textures.clear()
	return load_registry(registry_path)


## Replaces or adds one entry at runtime and tells every VisualSprite to
## refresh. Meant for tools and tests; the registry file is the normal way.
func override_entry(id: String, entry: Dictionary) -> void:
	var merged: Dictionary = entry.duplicate(true)
	if merged.has("extends"):
		var base: Dictionary = (_entries.get(String(merged["extends"]), {}) as Dictionary).duplicate(true)
		base.merge(merged, true)
		base.erase("extends")
		merged = base
	_entries[id] = merged
	_resolved.clear()
	registry_changed.emit()


# --- lookup ------------------------------------------------------------------------

## True when the registry has an entry for exactly this id (no fallback).
func has_visual(id: String) -> bool:
	return _entries.has(id)


func ids() -> Array[String]:
	var out: Array[String] = []
	for id in DictUtil.sorted_keys(_entries):
		out.append(String(id))
	return out


## The entry id that `id` resolves to after the fallback rules.
func resolved_id(id: String) -> String:
	var candidate := id
	while candidate != "":
		if _entries.has(candidate):
			return candidate
		var cut := candidate.rfind(".")
		candidate = candidate.substr(0, cut) if cut > 0 else ""
	return fallback_id


## The registry entry for an id as stored (after `extends`), or {}.
func entry(id: String) -> Dictionary:
	return (_entries.get(id, {}) as Dictionary).duplicate(true)


## Everything needed to draw a visual:
##   {requested_id, resolved_id, exact, is_fallback, texture, path, has_region,
##    region, hframes, vframes, frame, facing_frames, animations, anchor,
##    offset, scale, modulate, z_index, tile, frame_size}
func resolve(id: String) -> Dictionary:
	if _resolved.has(id):
		return _resolved[id]
	var used := resolved_id(id)
	var e: Dictionary = _entries.get(used, {})
	var tex := _load_texture(DictUtil.get_string(e, "texture"))
	var region_raw := DictUtil.get_array(e, "region")
	var has_region := region_raw.size() == 4
	var region := Rect2(float(region_raw[0]), float(region_raw[1]), float(region_raw[2]), float(region_raw[3])) if has_region else Rect2()
	var hframes := maxi(1, DictUtil.get_int(e, "hframes", 1))
	var vframes := maxi(1, DictUtil.get_int(e, "vframes", 1))
	var source_size := region.size if has_region else (tex.get_size() if tex != null else Vector2.ZERO)
	var out := {
		"requested_id": id,
		"resolved_id": used,
		"exact": used == id,
		"is_fallback": used == fallback_id and id != fallback_id,
		"texture": tex,
		"path": DictUtil.get_string(e, "texture"),
		"has_region": has_region,
		"region": region,
		"hframes": hframes,
		"vframes": vframes,
		"frame": clampi(DictUtil.get_int(e, "frame", 0), 0, hframes * vframes - 1),
		"facing_frames": DictUtil.get_bool(e, "facing_frames", false),
		"animations": DictUtil.get_dict(e, "animations").duplicate(true),
		"anchor": DictUtil.get_string(e, "anchor", ANCHOR_CENTER),
		"offset": _vec2(e.get("offset", null), Vector2.ZERO),
		"scale": _scale(e.get("scale", null)),
		"modulate": Color(DictUtil.get_string(e, "modulate", "#ffffff")),
		"z_index": DictUtil.get_int(e, "z_index", 0),
		"tile": DictUtil.get_bool(e, "tile", false),
		"frame_size": Vector2(source_size.x / float(hframes), source_size.y / float(vframes)),
	}
	_resolved[id] = out
	return out


func texture(id: String) -> Texture2D:
	return resolve(id)["texture"]


## A texture usable in UI (TextureRect, Button icon): the single frame or
## region the id names, cut out of its sheet if necessary.
func ui_texture(id: String) -> Texture2D:
	var v := resolve(id)
	var base: Texture2D = v["texture"]
	if base == null:
		return null
	var hframes: int = v["hframes"]
	var vframes: int = v["vframes"]
	if not v["has_region"] and hframes == 1 and vframes == 1:
		return base
	var origin: Vector2 = (v["region"] as Rect2).position if v["has_region"] else Vector2.ZERO
	var frame_size: Vector2 = v["frame_size"]
	var frame: int = v["frame"]
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(origin + Vector2((frame % hframes) * frame_size.x, int(frame / float(hframes)) * frame_size.y), frame_size)
	return atlas


# --- sprites -----------------------------------------------------------------------

## A sprite showing `id` that keeps itself up to date when the registry
## changes. Its position is the object's anchor point on the ground.
func make_sprite(id: String) -> VisualSprite:
	var sprite: VisualSprite = VisualSpriteScript.new()
	sprite.visual_id = id
	return sprite


## Configures any Sprite2D from a visual id. Returns the resolved description.
func apply(sprite: Sprite2D, id: String) -> Dictionary:
	var v := resolve(id)
	var hframes: int = v["hframes"]
	var vframes: int = v["vframes"]
	sprite.texture = v["texture"]
	sprite.region_enabled = v["has_region"]
	sprite.region_rect = v["region"]
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = clampi(int(v["frame"]), 0, hframes * vframes - 1)
	sprite.centered = false
	var size: Vector2 = v["frame_size"]
	var anchor_offset := Vector2.ZERO
	match String(v["anchor"]):
		ANCHOR_BOTTOM_CENTER:
			anchor_offset = Vector2(-size.x * 0.5, -size.y)
		ANCHOR_TOP_LEFT:
			anchor_offset = Vector2.ZERO
		_:
			anchor_offset = -size * 0.5
	var extra: Vector2 = v["offset"]
	sprite.offset = (anchor_offset + extra).round()
	sprite.scale = v["scale"]
	sprite.modulate = v["modulate"]
	sprite.z_index = int(v["z_index"])
	sprite.set_meta("visual_id", id)
	sprite.set_meta("resolved_visual_id", v["resolved_id"])
	return v


# --- internals ---------------------------------------------------------------------

func _fail_load(message: String) -> bool:
	load_errors.clear()
	load_errors.append(message)
	_entries.clear()
	_resolved.clear()
	fallback_id = ""
	registry_changed.emit()
	return false


## Applies `extends` chains: the base entry's fields, overridden by the entry's own.
func _merged_entry(raw: Dictionary, id: String, chain: Array) -> Dictionary:
	var own: Dictionary = (raw[id] as Dictionary).duplicate(true)
	if not own.has("extends"):
		return own
	var base_id := String(own["extends"])
	own.erase("extends")
	if chain.has(id) or base_id == id:
		load_errors.append("visual %s extends itself (cycle)" % id)
		return own
	if not raw.has(base_id) or not (raw[base_id] is Dictionary):
		load_errors.append("visual %s extends unknown visual %s" % [id, base_id])
		return own
	var base := _merged_entry(raw, base_id, chain + [id])
	base.merge(own, true)
	return base


func _validate_entry(id: String, e: Dictionary) -> void:
	var path := DictUtil.get_string(e, "texture")
	if path == "":
		load_errors.append("visual %s has no texture" % id)
	elif _load_texture(path) == null:
		load_errors.append("visual %s: cannot load texture %s" % [id, path])
	if e.has("anchor") and not ANCHORS.has(DictUtil.get_string(e, "anchor")):
		load_errors.append("visual %s has unknown anchor '%s'" % [id, str(e["anchor"])])
	if e.has("region") and DictUtil.get_array(e, "region").size() != 4:
		load_errors.append("visual %s region must be [x, y, w, h]" % id)
	if DictUtil.get_int(e, "hframes", 1) < 1 or DictUtil.get_int(e, "vframes", 1) < 1:
		load_errors.append("visual %s hframes/vframes must be >= 1" % id)
	if DictUtil.get_bool(e, "facing_frames", false) and DictUtil.get_int(e, "hframes", 1) * DictUtil.get_int(e, "vframes", 1) < 8:
		load_errors.append("visual %s uses facing_frames but has fewer than 8 frames" % id)
	if e.has("offset") and not (e["offset"] is Array and (e["offset"] as Array).size() == 2):
		load_errors.append("visual %s offset must be [x, y]" % id)


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		# An image dropped into the project that the editor has not imported yet.
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) == OK:
			tex = ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


static func _vec2(raw: Variant, fallback: Vector2) -> Vector2:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


static func _scale(raw: Variant) -> Vector2:
	if raw is float or raw is int:
		return Vector2(float(raw), float(raw))
	return _vec2(raw, Vector2.ONE)
