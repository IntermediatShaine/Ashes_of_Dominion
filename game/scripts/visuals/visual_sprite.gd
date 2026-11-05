class_name VisualSprite
extends Sprite2D
## A sprite that shows a visual id from the registry and follows registry
## changes. Use `Visuals.make_sprite(id)` or set `visual_id`.
##
## The node's position is where the thing stands; the registry entry's anchor
## and offset place the image around that point. For a state tint (damaged,
## hit flash) use `self_modulate`: `modulate` belongs to the registry entry.

## The stable id this sprite shows; assigning it re-resolves the artwork.
var visual_id: String = "":
	set(value):
		visual_id = value
		refresh()

## The registry entry actually in use (differs from visual_id after a fallback).
var resolved_visual_id: String = ""


## Adds a registry sprite to `owner_node` if — and only if — the registry has
## an entry for exactly `id`; otherwise returns null and the caller keeps its
## code-drawn placeholder. This is how objects that predate the registry
## become art-swappable: add the entry and the image appears, no code change.
static func attach_if_registered(owner_node: Node, id: String) -> VisualSprite:
	if not Visuals.has_visual(id):
		return null
	var sprite := Visuals.make_sprite(id)
	owner_node.add_child(sprite)
	return sprite


func _enter_tree() -> void:
	if not Visuals.registry_changed.is_connected(refresh):
		Visuals.registry_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Visuals.registry_changed.is_connected(refresh):
		Visuals.registry_changed.disconnect(refresh)


func refresh() -> void:
	if visual_id == "":
		texture = null
		resolved_visual_id = ""
		return
	var v := Visuals.apply(self, visual_id)
	resolved_visual_id = String(v["resolved_id"])


## Shows the frame for one of the eight facings (0 = east, clockwise) when the
## visual is a facing sheet; does nothing otherwise.
func set_facing_index(index: int) -> void:
	if visual_id == "" or not bool(Visuals.resolve(visual_id)["facing_frames"]):
		return
	frame = clampi(index, 0, hframes * vframes - 1)
