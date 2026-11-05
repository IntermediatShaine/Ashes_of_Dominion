extends Node2D
## One building site in the walkable village: what is drawn there, whether it
## blocks the way, and the area the player interacts with.
##
## A view, nothing more. It is told what the site looks like by
## `refresh(inspection)` (an inspect_site() result from SettlementService) and
## reports `interacted(site_id)`; it never reads or writes settlement state.
##
## Geometry comes from the layout: the node stands on the middle of the
## footprint's bottom edge, the collision box is the footprint, the
## interaction area is the footprint grown by INTERACTION_MARGIN. None of it
## depends on the size of the artwork the visual registry resolves.

signal interacted(site_id: String)

const INTERACTION_MARGIN := 14.0

var site_id: String = ""
## The inspection this view currently shows (a copy; display only).
var inspection: Dictionary = {}
var footprint: Rect2

var _sprite: VisualSprite
var _overlay: VisualSprite
var _body: StaticBody2D
var _body_shape: CollisionShape2D
var _area: InteractableArea


## `site_rect` is the footprint in map pixels; `anchor` the node position.
func setup(p_site_id: String, site_rect: Rect2, anchor: Vector2) -> void:
	site_id = p_site_id
	name = "Site_" + p_site_id
	footprint = site_rect
	position = anchor
	var local_centre := site_rect.position + site_rect.size * 0.5 - anchor

	_sprite = Visuals.make_sprite("")
	add_child(_sprite)
	_overlay = Visuals.make_sprite("")
	add_child(_overlay)

	_body = StaticBody2D.new()
	_body.collision_layer = ExplorationKit.LAYER_WORLD
	_body.collision_mask = 0
	_body_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = site_rect.size
	_body_shape.shape = box
	_body_shape.position = local_centre
	_body.add_child(_body_shape)
	add_child(_body)

	_area = InteractableArea.new()
	_area.target_id = p_site_id
	_area.position = local_centre
	_area.set_rect(site_rect.size + Vector2(INTERACTION_MARGIN, INTERACTION_MARGIN) * 2.0)
	_area.interacted.connect(func(_player: Node): interacted.emit(site_id))
	add_child(_area)


func refresh(p_inspection: Dictionary) -> void:
	inspection = p_inspection.duplicate(true)
	_sprite.visual_id = VillageVisuals.site_visual(inspection)
	var overlay_id := VillageVisuals.site_overlay(inspection)
	_overlay.visual_id = overlay_id
	_overlay.visible = overlay_id != ""
	# A badge floats above the roof; scaffolding stands on the ground.
	_overlay.position = Vector2(0, -footprint.size.y - 56.0) if overlay_id == VillageVisuals.WORK_BADGE else Vector2.ZERO
	set_solid(is_solid_state(DictUtil.get_string(inspection, "state")))
	_area.prompt = prompt_for(inspection)


## Whether a site in this state blocks movement: everything except a free plot.
static func is_solid_state(state: String) -> bool:
	return state != SiteRules.STATE_EMPTY


static func prompt_for(view: Dictionary) -> String:
	var site_name := DictUtil.get_string(view, "name")
	if DictUtil.get_string(view, "role") == "hearth":
		return "%s — manage the village" % site_name
	match DictUtil.get_string(view, "state"):
		SiteRules.STATE_EMPTY:
			return "Inspect the empty plot"
		SiteRules.STATE_RUIN:
			return "Inspect the ruined %s" % site_name
		SiteRules.STATE_DESTROYED:
			return "Inspect the destroyed %s" % site_name
		SiteRules.STATE_CONSTRUCTION:
			return "Inspect the %s under construction" % site_name
	return "Inspect the %s" % site_name


func set_solid(solid: bool) -> void:
	_body.collision_layer = ExplorationKit.LAYER_WORLD if solid else 0
	_body_shape.set_deferred("disabled", not solid)


func is_solid() -> bool:
	return _body.collision_layer != 0


func visual_id() -> String:
	return _sprite.visual_id


func overlay_visual_id() -> String:
	return _overlay.visual_id if _overlay.visible else ""


func sprite() -> VisualSprite:
	return _sprite


func interaction_area() -> InteractableArea:
	return _area
