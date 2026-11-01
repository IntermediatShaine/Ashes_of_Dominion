extends Control
## Emberfall management screen: character status, settlement state,
## construction, faction standing, threat, and the way out to the world map.
## Pure presentation — every mutation goes through Session / rules.

var _character_box: VBoxContainer
var _settlement_box: VBoxContainer
var _resources_box: HBoxContainer
var _buildings_box: VBoxContainer
var _construct_box: VBoxContainer
var _factions_box: VBoxContainer
var _status: Label


func _ready() -> void:
	if not Session.has_game():
		Router.go("main_menu")
		return
	UiKit.style_screen(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := UiKit.vbox(10)
	margin.add_child(root)

	var header := UiKit.hbox(16)
	root.add_child(header)
	var title := UiKit.title("Emberfall")
	header.add_child(title)
	_status = UiKit.muted("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(_status)

	var columns := UiKit.hbox(14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# left: character + factions
	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(300, 0)
	columns.add_child(left)
	var cp := UiKit.panel()
	_character_box = UiKit.vbox(4)
	cp.add_child(_character_box)
	left.add_child(cp)
	var fp := UiKit.panel()
	_factions_box = UiKit.vbox(4)
	fp.add_child(_factions_box)
	left.add_child(fp)

	# middle: settlement + resources + buildings
	var mid := UiKit.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(mid)
	var sp := UiKit.panel()
	_settlement_box = UiKit.vbox(4)
	sp.add_child(_settlement_box)
	mid.add_child(sp)
	var rp := UiKit.panel()
	rp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_resources_box = UiKit.hbox(18)
	rp.add_child(_resources_box)
	mid.add_child(rp)
	var bp := UiKit.panel()
	bp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bscroll := ScrollContainer.new()
	bscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bp.add_child(bscroll)
	var bcol := UiKit.vbox(8)
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bscroll.add_child(bcol)
	_buildings_box = UiKit.vbox(2)
	bcol.add_child(_buildings_box)
	bcol.add_child(UiKit.separator())
	_construct_box = UiKit.vbox(6)
	bcol.add_child(_construct_box)
	mid.add_child(bp)

	# right: actions
	var right := UiKit.vbox(8)
	right.custom_minimum_size = Vector2(230, 0)
	columns.add_child(right)
	right.add_child(UiKit.button("World Map  [M]", func(): Router.go("world_map"), 230))
	right.add_child(UiKit.button("Save Game", _on_save, 230))
	right.add_child(UiKit.button("Settings", func(): Router.go("settings"), 230))
	right.add_child(UiKit.button("Main Menu", _on_main_menu, 230))
	right.add_child(UiKit.muted("Progress autosaves whenever you return from an expedition or build.", 12))

	Session.state_changed.connect(_refresh)
	_refresh()
	if not Session.pending_expedition_summary.is_empty():
		var summary := Session.pending_expedition_summary
		Session.pending_expedition_summary = {}
		UiKit.message(self, "Expedition %s" % String(summary.get("status", "")), _summary_text(summary))
	for m in Session.last_messages:
		_status.text = m
	Session.last_messages.clear()


func _exit_tree() -> void:
	if Session.state_changed.is_connected(_refresh):
		Session.state_changed.disconnect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map"):
		Router.go("world_map")


func _refresh() -> void:
	if not Session.has_game():
		return
	var c := Session.character()
	var u := Session.universe()
	var s := Session.settlement()
	var defs := Content.table("buildings")
	var cbal := Content.balance("character")

	_clear(_character_box)
	_character_box.add_child(UiKit.label(c.character_name, 20, UiKit.ACCENT))
	var anc := DictUtil.get_string(Content.get_def("ancestries", c.primary_ancestry), "name")
	if c.is_mixed_ancestry():
		anc += " / " + DictUtil.get_string(Content.get_def("ancestries", c.secondary_ancestry), "name")
	_character_box.add_child(UiKit.muted("%s · %s" % [anc, DictUtil.get_string(Content.get_def("classes", c.current_class), "name")]))
	var prog := Content.balance("progression")
	_character_box.add_child(UiKit.label("Level %d   XP %d / %d" % [c.level, c.experience, ProgressionRules.xp_for_next_level(c.level, prog)]))
	_character_box.add_child(UiKit.label("Health %d / %d   Attack %d   Defense %d" % [DictUtil.get_int(u.protagonist_condition, "health"), ProgressionRules.max_health(c, cbal), ProgressionRules.attack(c, cbal), ProgressionRules.defense(c, cbal)]))
	var attr_parts: Array[String] = []
	for a in CharacterState.ATTRIBUTE_NAMES:
		attr_parts.append("%s %d" % [a.substr(0, 3).to_upper(), c.attribute(a)])
	_character_box.add_child(UiKit.muted("  ".join(attr_parts), 13))
	_character_box.add_child(UiKit.label("Morality: %s (%d)" % [MoralityRules.label(c.morality), c.morality]))
	if c.unlocked_classes.size() > 1:
		_character_box.add_child(UiKit.muted("Unlocked paths: " + ", ".join(c.unlocked_classes), 13))

	_clear(_factions_box)
	_factions_box.add_child(UiKit.label("Factions", 18, UiKit.ACCENT))
	for fid in DictUtil.sorted_keys(u.factions):
		var f: FactionState = u.factions[fid]
		var fd := Content.get_def("factions", String(fid))
		_factions_box.add_child(UiKit.label("%s: %s (%d)" % [DictUtil.get_string(fd, "name"), ReputationRules.label(f.player_reputation), f.player_reputation], 14))
	_factions_box.add_child(UiKit.separator())
	var band := ThreatRules.band(u.threat_state, Content.balance("threat"))
	_factions_box.add_child(UiKit.label("Enemy awareness: " + DictUtil.get_string(band, "label"), 14))
	_factions_box.add_child(UiKit.muted(DictUtil.get_string(band, "text"), 12))
	var remaining := ThreatRules.expeditions_remaining_in_grace(u.threat_state)
	if remaining > 0:
		_factions_box.add_child(UiKit.muted("The Marches are quiet for now (~%d more expedition%s)." % [remaining, "" if remaining == 1 else "s"], 12))

	_clear(_settlement_box)
	_settlement_box.add_child(UiKit.label("Day %d · %s" % [u.current_day, DifficultyRules.display_name(u.difficulty, Content.table("difficulty"))], 18, UiKit.ACCENT))
	_settlement_box.add_child(UiKit.label("Population %d / %d   Morale %d   Loyalty %d   Productivity %d   Freedom %d   Discipline %d   Military %d" % [
		s.population, SettlementRules.population_capacity(s, defs), s.morale, s.loyalty, s.productivity, s.freedom, s.discipline, SettlementRules.military_strength(s, defs)], 14, UiKit.TEXT, true))
	if s.pending_recruits > 0:
		_settlement_box.add_child(UiKit.muted("%d would join if there were room to shelter them." % s.pending_recruits, 13))
	var prod := SettlementRules.daily_production(s, defs)
	if not prod.is_empty():
		var pp: Array[String] = []
		for r in DictUtil.sorted_keys(prod):
			pp.append("%s +%d" % [String(r), int(prod[r])])
		_settlement_box.add_child(UiKit.muted("Daily production: " + ", ".join(pp), 13))

	_clear(_resources_box)
	var cap := SettlementRules.storage_capacity(s, defs)
	for rid in Content.ids("resources"):
		var rd := Content.get_def("resources", String(rid))
		var box := UiKit.vbox(0)
		box.custom_minimum_size = Vector2(72, 0)
		box.add_child(UiKit.label(DictUtil.get_string(rd, "name"), 13, Color(DictUtil.get_string(rd, "color", "#ffffff"))))
		box.add_child(UiKit.label("%d" % s.resource_amount(String(rid)), 22))
		_resources_box.add_child(box)
	var cap_l := UiKit.muted("storage cap %d each" % cap, 12, false)
	cap_l.size_flags_vertical = Control.SIZE_SHRINK_END
	_resources_box.add_child(cap_l)

	_clear(_buildings_box)
	_buildings_box.add_child(UiKit.label("Buildings", 18, UiKit.ACCENT))
	if s.buildings.is_empty():
		_buildings_box.add_child(UiKit.muted("Nothing but ash and a few lean-tos."))
	for b in s.buildings:
		var d := DictUtil.get_dict(defs, String(b.get("definition_id", "")))
		_buildings_box.add_child(UiKit.label("• %s  (built day %d)" % [DictUtil.get_string(d, "name"), DictUtil.get_int(b, "built_day")], 14))

	_clear(_construct_box)
	_construct_box.add_child(UiKit.label("Construction", 18, UiKit.ACCENT))
	for bid in Content.ids("buildings"):
		var d := Content.get_def("buildings", String(bid))
		var row := UiKit.hbox(10)
		var info := UiKit.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost_parts: Array[String] = []
		var cost := DictUtil.get_dict(d, "cost")
		for r in DictUtil.sorted_keys(cost):
			cost_parts.append("%d %s" % [DictUtil.get_int(cost, String(r)), String(r)])
		info.add_child(UiKit.label("%s — %s" % [DictUtil.get_string(d, "name"), ", ".join(cost_parts)], 15))
		info.add_child(UiKit.muted(DictUtil.get_string(d, "description"), 12))
		row.add_child(info)
		var reasons := ConstructionRules.blocking_reasons(s, String(bid), defs)
		var btn := UiKit.button("Build", func(): _on_build(String(bid)), 110)
		btn.disabled = not reasons.is_empty()
		btn.tooltip_text = "; ".join(reasons) if not reasons.is_empty() else "Ready to build"
		row.add_child(btn)
		if not reasons.is_empty():
			var why := UiKit.muted("; ".join(reasons), 12)
			why.custom_minimum_size = Vector2(180, 0)
			row.add_child(why)
		_construct_box.add_child(row)


func _on_build(definition_id: String) -> void:
	var r := Session.construct_building(definition_id)
	if not r.ok:
		_status.text = r.error
		return
	var w := Session.save_game()
	_status.text = "Built %s. %s" % [DictUtil.get_string(Content.get_def("buildings", definition_id), "name"), "Saved." if w.ok else "SAVE FAILED: " + w.error]
	_refresh()


func _on_save() -> void:
	var r := Session.save_game()
	_status.text = "Saved to slot %d." % Session.current_slot if r.ok else "Save failed: " + r.error


func _on_main_menu() -> void:
	Session.end_session()
	Router.go("main_menu")


func _summary_text(summary: Dictionary) -> String:
	var lines: Array[String] = []
	var delivered := DictUtil.get_dict(summary, "delivered")
	var lost := DictUtil.get_dict(summary, "lost")
	if delivered.is_empty() and lost.is_empty():
		lines.append("You brought nothing back.")
	for r in DictUtil.sorted_keys(delivered):
		if int(delivered[r]) > 0:
			lines.append("+%d %s" % [int(delivered[r]), String(r)])
	for r in DictUtil.sorted_keys(lost):
		if int(lost[r]) > 0:
			lines.append("%d %s lost (%s)" % [int(lost[r]), String(r), "no room in storage" if String(summary.get("status", "")) != "defeated" else "left where you fell"])
	lines.append("%d day%s passed." % [DictUtil.get_int(summary, "days_passed"), "" if DictUtil.get_int(summary, "days_passed") == 1 else "s"])
	if DictUtil.get_int(summary, "recruits") > 0:
		lines.append("%d newcomer(s) settled in Emberfall." % DictUtil.get_int(summary, "recruits"))
	var discovered := DictUtil.get_array(summary, "discovered")
	if not discovered.is_empty():
		var names: Array[String] = []
		for id in discovered:
			names.append(DictUtil.get_string(Content.get_def("landmarks", String(id)), "name", String(id)))
		lines.append("New places on the map: " + ", ".join(names))
	for day in DictUtil.get_array(summary, "sim"):
		for sid in DictUtil.get_dict(day, "settlements").keys():
			if DictUtil.get_bool(day["settlements"][sid], "starved", false):
				lines.append("Day %d: Emberfall went hungry." % DictUtil.get_int(day, "day"))
	return "\n".join(lines)


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
