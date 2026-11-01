class_name CharacterFactory
extends RefCounted
## Builds a fresh CharacterState from an archetype definition.


static func create(display_name: String, archetype_id: String, archetype: Dictionary, ancestries: Dictionary) -> OpResult:
	if display_name.strip_edges() == "":
		return OpResult.failure("Character name is required")
	if archetype.is_empty():
		return OpResult.failure("Unknown archetype " + archetype_id)
	var c := CharacterState.new()
	c.character_id = IdFactory.new_global_id("chr")
	c.character_name = display_name.strip_edges()
	c.archetype_id = archetype_id
	c.primary_ancestry = DictUtil.get_string(archetype, "primary_ancestry")
	c.secondary_ancestry = DictUtil.get_string(archetype, "secondary_ancestry")
	c.background = DictUtil.get_string(archetype, "background")
	c.current_class = DictUtil.get_string(archetype, "starting_class", "survivor")
	c.unlocked_classes = [c.current_class]
	c.created_at_unix = int(Time.get_unix_time_from_system())

	var attrs := DictUtil.int_map(DictUtil.get_dict(archetype, "base_attributes"))
	# Ancestry modifiers: primary applies fully, secondary applies half (rounded toward zero).
	_apply_modifiers(attrs, DictUtil.int_map(DictUtil.get_dict(DictUtil.get_dict(ancestries, c.primary_ancestry), "attribute_modifiers")), 1.0)
	if c.secondary_ancestry != "":
		_apply_modifiers(attrs, DictUtil.int_map(DictUtil.get_dict(DictUtil.get_dict(ancestries, c.secondary_ancestry), "attribute_modifiers")), 0.5)
	for name in CharacterState.ATTRIBUTE_NAMES:
		attrs[name] = clampi(int(attrs.get(name, 1)), 1, 100)
	c.base_attributes = attrs
	var errors := c.validate()
	if not errors.is_empty():
		return OpResult.failure("Character invalid: " + "; ".join(errors))
	return OpResult.success(c)


static func _apply_modifiers(attrs: Dictionary, mods: Dictionary, scale: float) -> void:
	for k in DictUtil.sorted_keys(mods):
		attrs[k] = int(attrs.get(k, 0)) + int(float(mods[k]) * scale)
