extends Control
## New game: character archetype + name, difficulty preset or custom values,
## world settings (seed, Mist), save slot. Builds the options dictionary
## Session.new_game expects.

var _name_edit: LineEdit
var _archetype: OptionButton
var _archetype_desc: Label
var _difficulty: OptionButton
var _custom_toggle: CheckBox
var _custom_box: VBoxContainer
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _mist: CheckBox
var _seed_edit: LineEdit
var _slot: OptionButton
var _error: Label
var _archetype_ids: Array = []
var _preset_ids: Array = []


func _ready() -> void:
	UiKit.style_screen(self)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := UiKit.vbox(10)
	col.custom_minimum_size = Vector2(620, 0)
	center.add_child(col)

	col.add_child(UiKit.title("New Game"))

	# --- character ---
	var char_panel := UiKit.panel()
	var cv := UiKit.vbox(6)
	char_panel.add_child(cv)
	cv.add_child(UiKit.label("Survivor", 20, UiKit.ACCENT))
	var name_row := UiKit.hbox()
	name_row.add_child(UiKit.label("Name"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Ren"
	_name_edit.max_length = 24
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	cv.add_child(name_row)
	var arch_row := UiKit.hbox()
	arch_row.add_child(UiKit.label("Background"))
	_archetype = OptionButton.new()
	_archetype.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archetype_ids = Content.ids("archetypes")
	for id in _archetype_ids:
		_archetype.add_item(DictUtil.get_string(Content.get_def("archetypes", String(id)), "name", String(id)))
	_archetype.item_selected.connect(func(_i): _refresh_archetype())
	arch_row.add_child(_archetype)
	cv.add_child(arch_row)
	_archetype_desc = UiKit.muted("")
	cv.add_child(_archetype_desc)
	col.add_child(char_panel)

	# --- difficulty ---
	var diff_panel := UiKit.panel()
	var dv := UiKit.vbox(6)
	diff_panel.add_child(dv)
	dv.add_child(UiKit.label("Difficulty", 20, UiKit.ACCENT))
	var diff_row := UiKit.hbox()
	_difficulty = OptionButton.new()
	_difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var table := Content.table("difficulty")
	_preset_ids = DictUtil.get_array(table, "preset_order")
	var default_preset := DictUtil.get_string(table, "default_preset", "challenging")
	for i in _preset_ids.size():
		_difficulty.add_item(DictUtil.get_string(Content.difficulty_presets()[_preset_ids[i]], "name", String(_preset_ids[i])))
		if String(_preset_ids[i]) == default_preset:
			_difficulty.select(i)
	_difficulty.item_selected.connect(func(_i): _reset_sliders_to_preset())
	diff_row.add_child(_difficulty)
	_custom_toggle = CheckBox.new()
	_custom_toggle.text = "Customize"
	_custom_toggle.toggled.connect(func(on): _custom_box.visible = on)
	diff_row.add_child(_custom_toggle)
	dv.add_child(diff_row)
	_custom_box = UiKit.vbox(4)
	_custom_box.visible = false
	for p in DictUtil.sorted_keys(Content.difficulty_parameters()):
		var spec: Dictionary = Content.difficulty_parameters()[p]
		var row := UiKit.hbox()
		var functional := DictUtil.get_bool(spec, "functional", false)
		var lbl := UiKit.label(DictUtil.get_string(spec, "label", String(p)) + ("" if functional else "  (not yet functional)"), 14, UiKit.TEXT if functional else UiKit.MUTED, true)
		lbl.custom_minimum_size = Vector2(300, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = DictUtil.get_float(spec, "min")
		slider.max_value = DictUtil.get_float(spec, "max")
		slider.step = DictUtil.get_float(spec, "step", 0.05)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.editable = functional
		var val_lbl := UiKit.label("", 14)
		val_lbl.custom_minimum_size = Vector2(60, 0)
		slider.value_changed.connect(func(v): val_lbl.text = _fmt_value(v, spec))
		row.add_child(slider)
		row.add_child(val_lbl)
		_custom_box.add_child(row)
		_sliders[p] = slider
		_slider_labels[p] = val_lbl
	dv.add_child(_custom_box)
	col.add_child(diff_panel)

	# --- world ---
	var world_panel := UiKit.panel()
	var wv := UiKit.vbox(6)
	world_panel.add_child(wv)
	wv.add_child(UiKit.label("World", 20, UiKit.ACCENT))
	_mist = CheckBox.new()
	_mist.text = "Mist of Discovery (hide unexplored routes and places)"
	_mist.button_pressed = true
	wv.add_child(_mist)
	var seed_row := UiKit.hbox()
	seed_row.add_child(UiKit.label("World seed"))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "leave empty for random"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_edit)
	wv.add_child(seed_row)
	wv.add_child(UiKit.muted("The same seed always produces the same world layout. Any text works as a seed.", 13))
	col.add_child(world_panel)

	# --- slot + actions ---
	var slot_row := UiKit.hbox()
	slot_row.add_child(UiKit.label("Save slot"))
	_slot = OptionButton.new()
	var slots := Session.repository.list_slots()
	var first_empty := -1
	for s in range(1, SaveRepository.MAX_SLOTS + 1):
		var meta = slots[s]
		if meta is Dictionary:
			_slot.add_item("Slot %d — overwrite %s (day %d)" % [s, DictUtil.get_string(meta, "character_name"), DictUtil.get_int(meta, "day")])
		else:
			_slot.add_item("Slot %d — empty" % s)
			if first_empty < 0:
				first_empty = s - 1
	_slot.select(maxi(first_empty, 0))
	_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_row.add_child(_slot)
	col.add_child(slot_row)

	_error = UiKit.label("", 14, UiKit.BAD)
	col.add_child(_error)
	var actions := UiKit.hbox(12)
	actions.add_child(UiKit.button("Back", func(): Router.go("main_menu"), 160))
	actions.add_child(UiKit.button("Begin", _on_begin, 260))
	col.add_child(actions)

	_refresh_archetype()
	_reset_sliders_to_preset()


func _refresh_archetype() -> void:
	var id := String(_archetype_ids[_archetype.selected])
	var d := Content.get_def("archetypes", id)
	var anc := DictUtil.get_string(Content.get_def("ancestries", DictUtil.get_string(d, "primary_ancestry")), "name")
	var sec := DictUtil.get_string(d, "secondary_ancestry")
	if sec != "":
		anc += " / " + DictUtil.get_string(Content.get_def("ancestries", sec), "name") + "  (mixed ancestry — most factions will distrust you)"
	var attrs := DictUtil.get_dict(d, "base_attributes")
	var parts: Array[String] = []
	for a in CharacterState.ATTRIBUTE_NAMES:
		parts.append("%s %d" % [a.substr(0, 3).to_upper(), DictUtil.get_int(attrs, a)])
	_archetype_desc.text = "%s\n%s\n%s" % [anc, DictUtil.get_string(d, "background"), "  ".join(parts)]


func _reset_sliders_to_preset() -> void:
	var preset: Dictionary = Content.difficulty_presets()[_preset_ids[_difficulty.selected]]
	for p in _sliders.keys():
		(_sliders[p] as HSlider).value = float(preset.get(p, 0))
		(_slider_labels[p] as Label).text = _fmt_value(float(preset.get(p, 0)), Content.difficulty_parameters()[p])


func _fmt_value(v: float, spec: Dictionary) -> String:
	return str(int(v)) if DictUtil.get_float(spec, "step", 0.05) >= 1.0 else "%.2f" % v


func _build_difficulty() -> OpResult:
	var table := Content.table("difficulty")
	var base := DifficultyRules.from_preset(String(_preset_ids[_difficulty.selected]), table)
	if not base.ok or not _custom_toggle.button_pressed:
		return base
	var overrides := {}
	for p in _sliders.keys():
		var spec: Dictionary = Content.difficulty_parameters()[p]
		var v: float = (_sliders[p] as HSlider).value
		overrides[p] = int(v) if DictUtil.get_float(spec, "step", 0.05) >= 1.0 else v
	return DifficultyRules.customize(base.value, overrides, table)


func _on_begin() -> void:
	_error.text = ""
	var diff := _build_difficulty()
	if not diff.ok:
		_error.text = diff.error
		return
	var seed_text := _seed_edit.text.strip_edges()
	var seed_value: int
	if seed_text == "":
		seed_value = StableHash.hash_string("%d|%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()])
	else:
		seed_value = StableHash.seed_from_text(seed_text)
	var options := {
		"name": _name_edit.text,
		"archetype_id": String(_archetype_ids[_archetype.selected]),
		"difficulty": diff.value,
		"mist_enabled": _mist.button_pressed,
		"seed": seed_value,
	}
	var r := Session.new_game(options, _slot.selected + 1)
	if not r.ok:
		_error.text = r.error
		return
	Router.go("settlement")
