extends CanvasLayer
## Exploration HUD: health, expedition info, pack contents, interaction
## prompt, floating damage numbers, pause menu, decision dialog, death card.

signal retreat_requested()
signal main_menu_requested()
signal decision_chosen(decision_id: String, option_id: String)

var _health_bar: ProgressBar
var _health_label: Label
var _expedition_label: Label
var _haul_label: Label
var _prompt: Label
var _toast: Label
var _toast_left: float = 0.0
var _pause: PanelContainer
var _decision: PanelContainer
var _decision_body: VBoxContainer
var _death: PanelContainer
var _font: Font


func _ready() -> void:
	layer = 10
	_font = ThemeDB.fallback_font
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)

	# top-left: health + expedition
	var tl := UiKit.vbox(4)
	tl.position = Vector2(14, 12)
	root.add_child(tl)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(220, 18)
	_health_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.25, 0.2)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.1, 0.08, 0.1, 0.8)
	_health_bar.add_theme_stylebox_override("fill", fill)
	_health_bar.add_theme_stylebox_override("background", bgs)
	tl.add_child(_health_bar)
	_health_label = UiKit.label("", 13)
	tl.add_child(_health_label)
	_expedition_label = UiKit.muted("", 13)
	tl.add_child(_expedition_label)

	# top-right: pack
	var tr := UiKit.panel()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -220
	tr.offset_right = -12
	tr.offset_top = 12
	root.add_child(tr)
	_haul_label = UiKit.label("Pack: empty", 14)
	tr.add_child(_haul_label)

	# bottom-center prompt
	_prompt = UiKit.label("", 18, Color(1, 0.95, 0.75))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -70
	_prompt.offset_bottom = -40
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)

	_toast = UiKit.label("", 15, Color(0.95, 0.85, 0.6))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 16
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)

	var hint := UiKit.muted("WASD move · LMB/Space attack · E interact · Esc pause", 12, false)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 14
	hint.offset_top = -28
	hint.offset_right = 600
	hint.offset_bottom = -8
	root.add_child(hint)

	_pause = _build_pause(root)
	_decision = _build_decision(root)
	_death = _build_death(root)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "Health %d / %d" % [current, maximum]


func set_expedition(text: String) -> void:
	_expedition_label.text = text


func set_haul(haul: Dictionary) -> void:
	if haul.is_empty():
		_haul_label.text = "Pack: empty"
		return
	var parts: Array[String] = []
	for r in DictUtil.sorted_keys(haul):
		if int(haul[r]) > 0:
			parts.append("%s %d" % [String(r), int(haul[r])])
	_haul_label.text = "Pack: " + ", ".join(parts)


func set_prompt(text: String) -> void:
	_prompt.text = ("[E] " + text) if text != "" else ""


func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast_left = seconds


func is_modal_open() -> bool:
	return _pause.visible or _decision.visible or _death.visible


# --- pause ----------------------------------------------------------------

func _build_pause(root: Control) -> PanelContainer:
	var p := UiKit.panel(Vector2(360, 0))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -180
	p.offset_right = 180
	p.offset_top = -120
	p.offset_bottom = 120
	p.visible = false
	root.add_child(p)
	var col := UiKit.vbox(8)
	p.add_child(col)
	col.add_child(UiKit.title("Paused", 24))
	col.add_child(UiKit.button("Resume", func(): toggle_pause(false), 330))
	col.add_child(UiKit.button("Retreat to Emberfall (keep pack)", func():
		toggle_pause(false)
		retreat_requested.emit(), 330))
	col.add_child(UiKit.button("Abandon to main menu (loses this trip)", func():
		toggle_pause(false)
		main_menu_requested.emit(), 330))
	col.add_child(UiKit.muted("Saving happens at Emberfall; this expedition is not saved until you get back.", 12))
	return p


func toggle_pause(on: bool) -> void:
	_pause.visible = on
	get_tree().paused = on


# --- decision ---------------------------------------------------------------

func _build_decision(root: Control) -> PanelContainer:
	var p := UiKit.panel(Vector2(520, 0))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -260
	p.offset_right = 260
	p.offset_top = -170
	p.offset_bottom = 170
	p.visible = false
	root.add_child(p)
	_decision_body = UiKit.vbox(8)
	p.add_child(_decision_body)
	return p


func show_decision(decision_id: String, decision: Dictionary, expedition: ExpeditionRecord) -> void:
	for c in _decision_body.get_children():
		c.queue_free()
	_decision_body.add_child(UiKit.title(DictUtil.get_string(decision, "title", decision_id), 22))
	_decision_body.add_child(UiKit.label(DictUtil.get_string(decision, "prompt"), 15, UiKit.TEXT, true))
	var options := DictUtil.get_dict(decision, "options")
	for oid in DictUtil.sorted_keys(options):
		var opt: Dictionary = options[oid]
		var block := DecisionRules.option_blocking_reason(opt, expedition)
		var b := UiKit.button(DictUtil.get_string(opt, "label", String(oid)) + ("" if block == "" else "  — " + block), func():
			decision_chosen.emit(decision_id, String(oid)), 490)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = block != ""
		_decision_body.add_child(b)
	_decision.visible = true
	get_tree().paused = true


func show_decision_result(text: String) -> void:
	for c in _decision_body.get_children():
		c.queue_free()
	_decision_body.add_child(UiKit.label(text, 16, UiKit.TEXT, true))
	_decision_body.add_child(UiKit.button("Continue", func():
		_decision.visible = false
		get_tree().paused = false, 200))


func close_decision() -> void:
	_decision.visible = false
	get_tree().paused = false


# --- death ------------------------------------------------------------------

func _build_death(root: Control) -> PanelContainer:
	var p := UiKit.panel(Vector2(480, 0))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -240
	p.offset_right = 240
	p.offset_top = -80
	p.offset_bottom = 80
	p.visible = false
	root.add_child(p)
	var col := UiKit.vbox(6)
	p.add_child(col)
	col.add_child(UiKit.title("You fall.", 26))
	col.add_child(UiKit.label("Cold. Dark. Then the smell of ash — Emberfall's ash. The curse has you by the collar again, and it is dragging you home.", 15, UiKit.TEXT, true))
	return p


func show_death() -> void:
	_death.visible = true


## World-space floating number rendered as a short-lived Label.
func spawn_damage_number(world_pos: Vector2, amount: int, camera: Camera2D, color: Color = Color(1, 0.9, 0.5)) -> void:
	var l := Label.new()
	l.text = str(amount)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	var screen := camera.get_viewport().get_canvas_transform() * world_pos
	l.position = screen + Vector2(-6, -40)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -28), 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)
