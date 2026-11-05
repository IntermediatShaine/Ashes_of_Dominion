extends CanvasLayer
## Village interface: status bar, interaction prompt, the building inspection
## card, the minimal Village Management panel (Overview / Buildings) and the
## pause menu.
##
## A view. It shows what it is given — a SettlementService.snapshot() plus a
## few lines about the protagonist — and reports what the player asks for
## through signals; the village controller turns those into service calls.
## It holds no settlement values of its own: every panel is rebuilt from the
## latest snapshot whenever the settlement changes.
##
## Appearance comes from res://ui/themes/village_theme.tres and icons from
## the visual registry. Controls here only pick a theme type variation
## (TitleLabel, MutedLabel, ModalPanel, …); there are no per-control colour,
## font or style overrides, so restyling the interface is a theme edit.
## This is deliberately the minimum that works; the full dashboard is a later
## stage's job and can replace this file wholesale.

signal improvement_requested(site_id: String, action: String, definition_id: String)
signal worker_change_requested(target_id: String, delta: int)
signal job_cancel_requested(job_id: String)
signal rest_requested()
signal craft_requested(recipe_id: String)
signal save_requested()
signal leave_requested()
signal settings_requested()
signal main_menu_requested()
signal modal_changed(modal: String)

const VILLAGE_THEME := preload("res://ui/themes/village_theme.tres")
const MODAL_NONE := ""
const MODAL_INSPECT := "inspect"
const MODAL_MANAGEMENT := "management"
const MODAL_PAUSE := "pause"
const MODAL_MESSAGE := "message"
const TAB_OVERVIEW := "overview"
const TAB_BUILDINGS := "buildings"
const HINT := "WASD move · E interact · V village management · M world map · Esc menu"

var _snapshot: Dictionary = {}
var _protagonist_lines: Array[String] = []
var _modal: String = MODAL_NONE
var _tab: String = TAB_OVERVIEW
var _inspect_site_id: String = ""

var _root: Control
var _status_box: HBoxContainer
var _prompt: Label
var _toast: Label
var _toast_left: float = 0.0
var _shade: Panel
var _inspect: PanelContainer
var _inspect_body: VBoxContainer
var _management: PanelContainer
var _management_body: VBoxContainer
var _tab_buttons: Dictionary = {}
var _pause: PanelContainer
var _message: PanelContainer
var _message_body: VBoxContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = VILLAGE_THEME
	add_child(_root)

	var bar := _panel("HudBar")
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	_root.add_child(bar)
	_status_box = _hbox("LooseHBox")
	bar.add_child(_status_box)

	_prompt = _label("", "PromptLabel")
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -72
	_prompt.offset_bottom = -42
	_prompt.offset_left = -360
	_prompt.offset_right = 360
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)

	_toast = _label("", "ToastLabel")
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 62
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_toast)

	var hint_bar := _panel("HudBar")
	hint_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_bar.offset_left = 10
	hint_bar.offset_top = -44
	hint_bar.offset_bottom = -8
	hint_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bar.add_child(_label(HINT, "MutedLabel"))
	_root.add_child(hint_bar)

	_shade = Panel.new()
	_shade.theme_type_variation = "ModalShade"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.visible = false
	_root.add_child(_shade)

	_inspect = _modal_panel(520)
	_inspect_body = _vbox()
	_inspect.add_child(_inspect_body)

	_management = _modal_panel(860)
	var management_col := _vbox()
	_management.add_child(management_col)
	var header := _hbox()
	management_col.add_child(header)
	var title := _label("Village Management", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for tab in [TAB_OVERVIEW, TAB_BUILDINGS]:
		var tab_button := _button(String(tab).capitalize(), _show_tab.bind(String(tab)), "TabButton")
		tab_button.toggle_mode = true
		header.add_child(tab_button)
		_tab_buttons[tab] = tab_button
	header.add_child(_button("Close  [Esc]", close_modal))
	management_col.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 500)
	management_col.add_child(scroll)
	_management_body = _vbox("LooseVBox")
	_management_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_management_body)

	_pause = _modal_panel(360)
	var pause_col := _vbox()
	_pause.add_child(pause_col)
	pause_col.add_child(_label("Emberfall", "TitleLabel"))
	pause_col.add_child(_button("Resume", close_modal))
	pause_col.add_child(_button("Save Game", func(): save_requested.emit()))
	pause_col.add_child(_button("Village Management  [V]", func(): open_management()))
	pause_col.add_child(_button("World Map  [M]", func():
		close_modal()
		leave_requested.emit()))
	pause_col.add_child(_button("Settings", func():
		close_modal()
		settings_requested.emit()))
	pause_col.add_child(_button("Main Menu", func():
		close_modal()
		main_menu_requested.emit()))
	pause_col.add_child(_label("Progress is saved when you order work, rest, or come home from an expedition.", "MutedLabel", true))

	_message = _modal_panel(460)
	_message_body = _vbox()
	_message.add_child(_message_body)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _modal != MODAL_NONE:
			close_modal()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("village_management"):
		if _modal == MODAL_NONE:
			open_management()
		elif _modal == MODAL_MANAGEMENT:
			close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map") and _modal == MODAL_NONE:
		leave_requested.emit()
		get_viewport().set_input_as_handled()


# --- what the controller calls ------------------------------------------------------

## New data to show. `snapshot` is a SettlementService.snapshot();
## `protagonist_lines` are ready-made lines about the character and factions
## (they are not settlement data, so the controller supplies them).
func refresh(snapshot: Dictionary, protagonist_lines: Array[String] = []) -> void:
	_snapshot = snapshot
	_protagonist_lines = protagonist_lines
	_rebuild_status()
	match _modal:
		MODAL_INSPECT:
			_rebuild_inspect()
		MODAL_MANAGEMENT:
			_rebuild_management()


func set_prompt(text: String) -> void:
	_prompt.text = ("[E] " + text) if text != "" else ""


func toast(text: String, seconds: float = 3.0) -> void:
	_toast.text = text
	_toast_left = seconds


func toast_text() -> String:
	return _toast.text


func is_modal_open() -> bool:
	return _modal != MODAL_NONE


func current_modal() -> String:
	return _modal


func current_tab() -> String:
	return _tab


func inspected_site_id() -> String:
	return _inspect_site_id if _modal == MODAL_INSPECT else ""


func open_inspect(site_id: String) -> void:
	_inspect_site_id = site_id
	_set_modal(MODAL_INSPECT)
	_rebuild_inspect()


func open_management(tab: String = "") -> void:
	if tab != "":
		_tab = tab
	_set_modal(MODAL_MANAGEMENT)
	_rebuild_management()


func open_pause() -> void:
	_set_modal(MODAL_PAUSE)


func show_message(title_text: String, body: String) -> void:
	_clear(_message_body)
	_message_body.add_child(_label(title_text, "HeaderLabel"))
	_message_body.add_child(_label(body, "", true))
	_message_body.add_child(_button("Continue", close_modal))
	_set_modal(MODAL_MESSAGE)


func close_modal() -> void:
	_set_modal(MODAL_NONE)


## Text of every label currently shown in a panel — lets tests read what the
## player would read without depending on the layout.
func panel_text(modal: String) -> String:
	var node: Node = {MODAL_INSPECT: _inspect_body, MODAL_MANAGEMENT: _management_body, MODAL_MESSAGE: _message_body}.get(modal)
	if node == null:
		return ""
	var parts: Array[String] = []
	_collect_text(node, parts)
	return "\n".join(parts)


## The enabled improvement buttons of the open panel: [{site_id, action, definition_id}].
func offered_improvements(modal: String) -> Array:
	var node: Node = {MODAL_INSPECT: _inspect_body, MODAL_MANAGEMENT: _management_body}.get(modal)
	var out: Array = []
	if node != null:
		_collect_improvements(node, out)
	return out


# --- modal plumbing -----------------------------------------------------------------

func _set_modal(modal: String) -> void:
	_modal = modal
	(_inspect.get_parent() as Control).visible = modal == MODAL_INSPECT
	(_management.get_parent() as Control).visible = modal == MODAL_MANAGEMENT
	(_pause.get_parent() as Control).visible = modal == MODAL_PAUSE
	(_message.get_parent() as Control).visible = modal == MODAL_MESSAGE
	_shade.visible = modal != MODAL_NONE
	# The world stands still while a panel is open (this layer keeps running).
	get_tree().paused = modal != MODAL_NONE
	modal_changed.emit(modal)


func _show_tab(tab: String) -> void:
	_tab = tab
	_rebuild_management()


# --- status bar ---------------------------------------------------------------------

func _rebuild_status() -> void:
	_clear(_status_box)
	if _snapshot.is_empty():
		return
	var time := DictUtil.get_dict(_snapshot, "time")
	_status_box.add_child(_label("%s · Day %d · %s" % [DictUtil.get_string(_snapshot, "name"), DictUtil.get_int(time, "day"), DictUtil.get_string(time, "clock")], "HeaderLabel"))
	var resources := DictUtil.get_dict(_snapshot, "resources")
	for rid in DictUtil.sorted_keys(resources):
		var pair := _hbox("TightHBox")
		pair.tooltip_text = _resource_name(String(rid))
		pair.add_child(_icon(VillageVisuals.resource_icon(String(rid))))
		pair.add_child(_label("%d" % int(resources[rid])))
		_status_box.add_child(pair)
	_status_box.add_child(_label("cap %d" % DictUtil.get_int(_snapshot, "storage_capacity"), "MutedLabel"))
	var population := DictUtil.get_dict(_snapshot, "population")
	var people := _hbox("TightHBox")
	people.tooltip_text = "Population / housing"
	people.add_child(_icon(VillageVisuals.ICON_POPULATION))
	people.add_child(_label("%d / %d" % [DictUtil.get_int(population, "count"), DictUtil.get_int(population, "capacity")]))
	_status_box.add_child(people)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_box.add_child(spacer)
	_status_box.add_child(_label("Awareness: " + DictUtil.get_string(DictUtil.get_dict(_snapshot, "threat"), "label"), "MutedLabel"))


# --- inspection card ----------------------------------------------------------------

func _rebuild_inspect() -> void:
	_clear(_inspect_body)
	var view := _site(_inspect_site_id)
	if view.is_empty():
		_inspect_body.add_child(_label("Nothing here.", "MutedLabel"))
	else:
		_add_site_details(_inspect_body, view, true)
	_inspect_body.add_child(HSeparator.new())
	_inspect_body.add_child(_button("Close  [Esc]", close_modal))


## Identity, condition, level and improvements of one site.
func _add_site_details(box: VBoxContainer, view: Dictionary, with_description: bool) -> void:
	var site_id := DictUtil.get_string(view, "site_id")
	var has_building := DictUtil.get_string(view, "instance_id") != ""
	box.add_child(_label(DictUtil.get_string(view, "name"), "HeaderLabel"))
	var category := DictUtil.get_string(view, "category")
	box.add_child(_label(("%s · " % category.capitalize() if category != "" else "") + _state_text(view), "MutedLabel"))
	if with_description and DictUtil.get_string(view, "description") != "":
		box.add_child(_label(DictUtil.get_string(view, "description"), "SmallLabel", true))
	box.add_child(_label("Level %d of %d" % [DictUtil.get_int(view, "level"), DictUtil.get_int(view, "max_level")] if DictUtil.get_int(view, "max_level") > 0 else "Level —"))
	var condition_row := _hbox()
	condition_row.add_child(_label("Condition: %s (%d%%)" % [DictUtil.get_string(view, "condition_label"), DictUtil.get_int(view, "condition")]))
	var bar := ProgressBar.new()
	bar.max_value = SettlementState.MAX_CONDITION
	bar.value = DictUtil.get_int(view, "condition")
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	condition_row.add_child(bar)
	box.add_child(condition_row)
	if has_building:
		var effects := _effects_text(DictUtil.get_dict(view, "effects"))
		box.add_child(_label("Provides: " + (effects if effects != "" else "nothing yet"), "SmallLabel", true))
		if DictUtil.get_string(view, "definition_id") == "workshop":
			for id in Content.ids("recipes"):
				var recipe_id := String(id)
				var recipe: Dictionary = Content.table("recipes")[recipe_id]
				box.add_child(_label("%s — %s · %d minutes · Workshop L%d" % [recipe["description"], _cost_text(recipe["cost"]), recipe["minutes"], recipe["level"]], "SmallLabel", true))
				box.add_child(_button("Craft " + String(recipe["name"]), func(): craft_requested.emit(recipe_id), "SmallButton"))
		var slots := DictUtil.get_int(view, "worker_slots")
		if slots > 0:
			box.add_child(_worker_row("Workers %d / %d%s" % [DictUtil.get_array(view, "workers").size(), slots, _names_suffix(DictUtil.get_array(view, "workers"))], DictUtil.get_string(view, "instance_id")))
	var job := DictUtil.get_dict(view, "job")
	if not job.is_empty():
		_add_job(box, job)
	var improvements := DictUtil.get_array(view, "improvements")
	box.add_child(_label("Available improvements", "HeaderLabel"))
	if improvements.is_empty():
		box.add_child(_label("Nothing can be improved here right now." if job.is_empty() else "Wait for the work in progress to finish.", "MutedLabel"))
	for improvement in improvements:
		box.add_child(_improvement_row(site_id, improvement, DictUtil.get_string(view, "state") == SiteRules.STATE_RUIN))


func _add_job(box: VBoxContainer, job: Dictionary) -> void:
	var kind := DictUtil.get_string(job, "kind")
	var what: String = {SettlementState.JOB_BUILD: "Construction", SettlementState.JOB_UPGRADE: "Upgrade to level %d" % DictUtil.get_int(job, "target_level"), SettlementState.JOB_REPAIR: "Repair"}.get(kind, "Work")
	var row := _hbox()
	row.add_child(_label("%s: %d of %d day%s of work done" % [what, DictUtil.get_int(job, "work_done"), DictUtil.get_int(job, "work_required"), "" if DictUtil.get_int(job, "work_required") == 1 else "s"], "SmallLabel"))
	var bar := ProgressBar.new()
	bar.theme_type_variation = "WorkBar"
	bar.max_value = maxi(1, DictUtil.get_int(job, "work_required"))
	bar.value = DictUtil.get_int(job, "work_done")
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	box.add_child(row)
	var job_id := DictUtil.get_string(job, "job_id")
	var builders := DictUtil.get_array(job, "builders")
	var worker_row := _worker_row("Builders %d%s · %d work a day" % [builders.size(), _names_suffix(builders), DictUtil.get_int(job, "work_per_day")], job_id)
	worker_row.add_child(_button("Cancel work", func(): job_cancel_requested.emit(job_id), "SmallButton"))
	box.add_child(worker_row)


func _worker_row(text: String, target_id: String) -> HBoxContainer:
	var row := _hbox()
	var label := _label(text, "SmallLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_button("−", func(): worker_change_requested.emit(target_id, -1), "SmallButton"))
	row.add_child(_button("+", func(): worker_change_requested.emit(target_id, 1), "SmallButton"))
	return row


## `rebuild` words a first build on a ruin as "Rebuild".
func _improvement_row(site_id: String, improvement: Dictionary, rebuild: bool = false) -> Control:
	var card := _panel("CardPanel")
	var row := _hbox()
	card.add_child(row)
	var info := _vbox("TightVBox")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var action := DictUtil.get_string(improvement, "action")
	var definition_id := DictUtil.get_string(improvement, "definition_id")
	var title := ""
	match action:
		SettlementService.ACTION_BUILD:
			title = "%s %s" % ["Rebuild" if rebuild else "Build", DictUtil.get_string(improvement, "name")]
		SettlementService.ACTION_UPGRADE:
			title = "Upgrade to level %d" % DictUtil.get_int(improvement, "target_level")
		SettlementService.ACTION_REPAIR:
			title = "Repair"
	var days := DictUtil.get_int(improvement, "days")
	info.add_child(_label("%s — %s · %s" % [title, _cost_text(DictUtil.get_dict(improvement, "cost")), "done at once" if days <= 0 else "%d day%s of work" % [days, "" if days == 1 else "s"]]))
	var effects := _effects_text(DictUtil.get_dict(improvement, "effects"))
	if effects != "":
		info.add_child(_label("Provides: " + effects, "MutedLabel", true))
	var blocked := DictUtil.get_array(improvement, "blocked_by")
	if not blocked.is_empty():
		info.add_child(_label("; ".join(blocked), "BadLabel", true))
	var button := _button(title.get_slice(" ", 0), func(): improvement_requested.emit(site_id, action, definition_id), "SmallButton")
	button.disabled = not blocked.is_empty()
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.set_meta("improvement", {"site_id": site_id, "action": action, "definition_id": definition_id})
	row.add_child(button)
	return card


# --- management panel ---------------------------------------------------------------

func _rebuild_management() -> void:
	for tab in _tab_buttons.keys():
		(_tab_buttons[tab] as Button).set_pressed_no_signal(tab == _tab)
	_clear(_management_body)
	if _snapshot.is_empty():
		return
	if _tab == TAB_BUILDINGS:
		_build_buildings_tab()
	else:
		_build_overview_tab()


func _build_overview_tab() -> void:
	var body := _management_body
	var time := DictUtil.get_dict(_snapshot, "time")
	var population := DictUtil.get_dict(_snapshot, "population")
	var stats := DictUtil.get_dict(_snapshot, "stats")
	var threat := DictUtil.get_dict(_snapshot, "threat")

	# the hearth itself: it is a building like the others
	for site in DictUtil.get_array(_snapshot, "sites"):
		if DictUtil.get_string(site, "role") == "hearth":
			var hearth_card := _card(body)
			_add_site_details(hearth_card, site, true)

	var time_card := _card(body)
	var time_row := _hbox()
	time_card.add_child(time_row)
	var time_label := _label("Day %d · %s" % [DictUtil.get_int(time, "day"), DictUtil.get_string(time, "clock")], "ValueLabel")
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(time_label)
	time_row.add_child(_button("Rest until dawn", func(): rest_requested.emit()))
	time_card.add_child(_label("Resting passes the time to the next dawn: people eat, production comes in and construction work continues.", "MutedLabel", true))

	var stock_card := _card(body)
	stock_card.add_child(_label("Stockpile", "HeaderLabel"))
	var stock_row := _hbox("LooseHBox")
	stock_card.add_child(stock_row)
	var resources := DictUtil.get_dict(_snapshot, "resources")
	for rid in DictUtil.sorted_keys(resources):
		var pair := _hbox("TightHBox")
		pair.add_child(_icon(VillageVisuals.resource_icon(String(rid))))
		pair.add_child(_label("%s %d" % [_resource_name(String(rid)), int(resources[rid])]))
		stock_row.add_child(pair)
	stock_card.add_child(_label("Storage holds %d of each resource." % DictUtil.get_int(_snapshot, "storage_capacity"), "MutedLabel"))
	var production := DictUtil.get_dict(_snapshot, "production")
	if not production.is_empty():
		var parts: Array[String] = []
		for rid in DictUtil.sorted_keys(production):
			parts.append("%s +%d" % [_resource_name(String(rid)), int(production[rid])])
		stock_card.add_child(_label("Daily production: " + ", ".join(parts), "SmallLabel"))

	var people_card := _card(body)
	people_card.add_child(_label("People", "HeaderLabel"))
	people_card.add_child(_label("Population %d of %d housed · %d idle" % [DictUtil.get_int(population, "count"), DictUtil.get_int(population, "capacity"), DictUtil.get_int(population, "idle")]))
	if DictUtil.get_int(population, "pending_recruits") > 0:
		people_card.add_child(_label("%d would join if there were room to shelter them." % DictUtil.get_int(population, "pending_recruits"), "MutedLabel"))
	people_card.add_child(_label("Morale %d · Loyalty %d · Productivity %d · Freedom %d · Discipline %d · Military %d" % [DictUtil.get_int(stats, "morale"), DictUtil.get_int(stats, "loyalty"), DictUtil.get_int(stats, "productivity"), DictUtil.get_int(stats, "freedom"), DictUtil.get_int(stats, "discipline"), DictUtil.get_int(stats, "military_strength")], "SmallLabel", true))
	var roster: Array[String] = []
	for resident in DictUtil.get_array(population, "residents"):
		roster.append("%s (%s)" % [DictUtil.get_string(resident, "name", "?"), DictUtil.get_string(resident, "assignment_label", "Idle")])
	people_card.add_child(_label("Residents: " + ", ".join(roster), "MutedLabel", true))

	var threat_card := _card(body)
	threat_card.add_child(_label("Threat", "HeaderLabel"))
	threat_card.add_child(_label("Enemy awareness: " + DictUtil.get_string(threat, "label")))
	threat_card.add_child(_label(DictUtil.get_string(threat, "text"), "MutedLabel", true))
	if DictUtil.get_int(threat, "grace_remaining") > 0:
		threat_card.add_child(_label("The Marches are quiet for now (about %d more expedition%s)." % [DictUtil.get_int(threat, "grace_remaining"), "" if DictUtil.get_int(threat, "grace_remaining") == 1 else "s"], "MutedLabel", true))

	var jobs := DictUtil.get_array(_snapshot, "jobs")
	if not jobs.is_empty():
		var jobs_card := _card(body)
		jobs_card.add_child(_label("Work in progress", "HeaderLabel"))
		for job in jobs:
			jobs_card.add_child(_label(DictUtil.get_string(job, "name"), "SmallLabel"))
			_add_job(jobs_card, job)

	if not _protagonist_lines.is_empty():
		var hero_card := _card(body)
		hero_card.add_child(_label("You", "HeaderLabel"))
		for line in _protagonist_lines:
			hero_card.add_child(_label(line, "SmallLabel", true))

	var events := DictUtil.get_array(_snapshot, "events")
	if not events.is_empty():
		var events_card := _card(body)
		events_card.add_child(_label("Recent events", "HeaderLabel"))
		for i in range(events.size() - 1, maxi(-1, events.size() - 9), -1):
			events_card.add_child(_label(_event_text(events[i]), "MutedLabel", true))


func _build_buildings_tab() -> void:
	var body := _management_body
	for site in DictUtil.get_array(_snapshot, "sites"):
		_add_site_details(_card(body), site, false)
	var unplaced := DictUtil.get_array(_snapshot, "unplaced_buildings")
	if not unplaced.is_empty():
		body.add_child(_label("Without a site in the village", "HeaderLabel"))
		for view in unplaced:
			_add_site_details(_card(body), view, false)


# --- wording ------------------------------------------------------------------------

func _state_text(view: Dictionary) -> String:
	match DictUtil.get_string(view, "state"):
		SiteRules.STATE_RUIN:
			return "In ruins — not rebuilt yet"
		SiteRules.STATE_EMPTY:
			return "Free building plot"
		SiteRules.STATE_CONSTRUCTION:
			return "Under construction"
		SiteRules.STATE_DESTROYED:
			return "Destroyed — needs repair"
	return "Standing since day %d" % DictUtil.get_int(view, "built_day")


func _effects_text(effects: Dictionary) -> String:
	var parts: Array[String] = []
	if DictUtil.get_int(effects, "population_capacity") != 0:
		parts.append("housing +%d" % DictUtil.get_int(effects, "population_capacity"))
	if DictUtil.get_int(effects, "storage_capacity") != 0:
		parts.append("storage +%d" % DictUtil.get_int(effects, "storage_capacity"))
	if DictUtil.get_int(effects, "military_strength") != 0:
		parts.append("defence +%d" % DictUtil.get_int(effects, "military_strength"))
	if DictUtil.get_int(effects, "military_strength_per_worker") != 0:
		parts.append("defence +%d per worker" % DictUtil.get_int(effects, "military_strength_per_worker"))
	var production := DictUtil.get_dict(effects, "production")
	for rid in DictUtil.sorted_keys(production):
		parts.append("%s +%d a day" % [_resource_name(String(rid)).to_lower(), DictUtil.get_int(production, String(rid))])
	if DictUtil.get_int(effects, "worker_slots") != 0:
		parts.append("%d work place%s" % [DictUtil.get_int(effects, "worker_slots"), "" if DictUtil.get_int(effects, "worker_slots") == 1 else "s"])
	var per_worker := DictUtil.get_dict(effects, "production_per_worker")
	for rid in DictUtil.sorted_keys(per_worker):
		parts.append("%s +%d a day per worker" % [_resource_name(String(rid)).to_lower(), DictUtil.get_int(per_worker, String(rid))])
	return ", ".join(parts)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for rid in DictUtil.sorted_keys(cost):
		if DictUtil.get_int(cost, String(rid)) > 0:
			parts.append("%d %s" % [DictUtil.get_int(cost, String(rid)), _resource_name(String(rid)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "free"


func _names_suffix(people: Array) -> String:
	var names: Array[String] = []
	for person in people:
		names.append(DictUtil.get_string(person, "name", "?"))
	return (" (" + ", ".join(names) + ")") if not names.is_empty() else ""


func _event_text(event: Dictionary) -> String:
	var data := DictUtil.get_dict(event, "data")
	var building := DictUtil.get_string(Content.table("buildings").get(DictUtil.get_string(data, "definition_id"), {}), "name", "building")
	var text := ""
	match DictUtil.get_string(event, "type"):
		"building_constructed":
			text = "%s built" % building
		"building_upgraded":
			text = "%s raised to level %d" % [building, DictUtil.get_int(data, "level")]
		"building_repaired":
			text = "%s repaired" % building
		"building_damaged":
			text = "A building was damaged (%s)" % DictUtil.get_string(data, "cause", "unknown cause")
		"job_started":
			text = "Work began on the %s" % building
		"job_completed":
			text = "Work on the %s finished" % building
		"job_cancelled":
			text = "Work on the %s was abandoned" % building
		"resident_joined":
			text = "A newcomer settled in"
		"worker_assigned":
			text = "Someone took up new work"
		"worker_unassigned":
			text = "Someone laid down their work"
		_:
			text = DictUtil.get_string(event, "type").capitalize()
	return "Day %d: %s" % [DictUtil.get_int(event, "day"), text]


func _resource_name(resource_id: String) -> String:
	return DictUtil.get_string(Content.table("resources").get(resource_id, {}), "name", resource_id.capitalize())


func _site(site_id: String) -> Dictionary:
	for site in DictUtil.get_array(_snapshot, "sites"):
		if DictUtil.get_string(site, "site_id") == site_id:
			return site
	return {}


# --- small builders (theme variations only, never overrides) ------------------------

func _label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
	return l


func _button(text: String, on_pressed: Callable, variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(on_pressed)
	return b


func _panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


func _vbox(variation: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	if variation != "":
		v.theme_type_variation = variation
	return v


func _hbox(variation: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	if variation != "":
		h.theme_type_variation = variation
	return h


## A card inside `parent`; returns the column to fill.
func _card(parent: Control) -> VBoxContainer:
	var card := _panel("CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var col := _vbox()
	card.add_child(col)
	return col


func _icon(visual_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Visuals.ui_texture(visual_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.set_meta("visual_id", visual_id)
	return icon


## A centred panel that is as tall as its content. The panel sits in a
## full-screen CenterContainer; showing or hiding a modal toggles that wrapper.
func _modal_panel(min_width: float) -> PanelContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.visible = false
	_root.add_child(centre)
	var p := _panel("ModalPanel")
	p.custom_minimum_size = Vector2(min_width, 0)
	centre.add_child(p)
	return p


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _collect_text(node: Node, out: Array[String]) -> void:
	for c in node.get_children():
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append("[%s]" % (c as Button).text)
		_collect_text(c, out)


func _collect_improvements(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button and c.has_meta("improvement") and not (c as Button).disabled:
			out.append(c.get_meta("improvement"))
		_collect_improvements(c, out)
