extends SceneTree
## Development tool: (re)creates res://ui/themes/village_theme.tres.
##
##   godot --headless --path . -s res://tools/build_village_theme.gd
##
## The .tres it writes is the source of truth for how the village interface
## looks: open it in the Godot theme editor (or edit the text) to restyle the
## UI without touching a script. Run this tool only to start over from the
## defaults below or after adding a new type variation here — it overwrites
## the file. Variations (set through `theme_type_variation`, never through
## per-control overrides) are listed in docs/ART_SWAP_GUIDE.md.

const OUT := "res://ui/themes/village_theme.tres"

const BG := Color("1d1a24")
const PANEL := Color("2a2533")
const PANEL_DEEP := Color("211d29")
const BORDER := Color("4a3f55")
const ACCENT := Color("c9742a")
const TEXT := Color("e8e0d0")
const MUTED := Color("9a9088")
const GOOD := Color("7cb86a")
const BAD := Color("c9553a")
const WARM := Color("fff2bf")


func _init() -> void:
	var t := Theme.new()
	t.default_font_size = 16

	# --- labels ---
	t.set_color("font_color", "Label", TEXT)
	_label(t, "TitleLabel", 26, ACCENT)
	_label(t, "HeaderLabel", 19, ACCENT)
	_label(t, "ValueLabel", 20, TEXT)
	_label(t, "SmallLabel", 13, TEXT)
	_label(t, "MutedLabel", 13, MUTED)
	_label(t, "GoodLabel", 14, GOOD)
	_label(t, "BadLabel", 14, BAD)
	_label(t, "PromptLabel", 18, WARM)
	_label(t, "ToastLabel", 15, Color("f2d999"))
	for v in ["PromptLabel", "ToastLabel"]:
		t.set_color("font_shadow_color", v, Color(0, 0, 0, 0.85))
		t.set_constant("shadow_offset_x", v, 1)
		t.set_constant("shadow_offset_y", v, 1)

	# --- buttons ---
	var normal := _flat(Color("3a3144"), BORDER)
	var hover := _flat(Color("4b3f58"), ACCENT)
	var pressed := _flat(Color("2b2434"), ACCENT)
	var disabled := _flat(Color("262230"), Color("3a3542"))
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, hover)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, WARM)
		t.set_color("font_disabled_color", type, MUTED)
	t.set_type_variation("SmallButton", "Button")
	t.set_font_size("font_size", "SmallButton", 13)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var small: StyleBoxFlat = t.get_stylebox(state, "Button").duplicate()
		small.content_margin_left = 8
		small.content_margin_right = 8
		small.content_margin_top = 3
		small.content_margin_bottom = 3
		t.set_stylebox(state, "SmallButton", small)
	# a tab is a toggle button: the pressed look marks the open tab
	t.set_type_variation("TabButton", "Button")
	t.set_font_size("font_size", "TabButton", 16)
	t.set_stylebox("normal", "TabButton", _flat(PANEL_DEEP, BORDER))
	t.set_stylebox("hover", "TabButton", _flat(Color("3a3144"), ACCENT))
	t.set_stylebox("pressed", "TabButton", _flat(Color("4b3f58"), ACCENT, 2))
	t.set_stylebox("focus", "TabButton", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	t.set_color("font_pressed_color", "TabButton", ACCENT)

	# --- panels ---
	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, BORDER))
	t.set_stylebox("panel", "Panel", _flat(PANEL, BORDER))
	t.set_type_variation("HudBar", "PanelContainer")
	t.set_stylebox("panel", "HudBar", _flat(Color(0.09, 0.08, 0.11, 0.86), BORDER))
	t.set_type_variation("ModalPanel", "PanelContainer")
	var modal := _flat(PANEL, ACCENT, 2)
	modal.content_margin_left = 16
	modal.content_margin_right = 16
	modal.content_margin_top = 12
	modal.content_margin_bottom = 12
	modal.shadow_color = Color(0, 0, 0, 0.5)
	modal.shadow_size = 8
	t.set_stylebox("panel", "ModalPanel", modal)
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _flat(PANEL_DEEP, BORDER))
	t.set_type_variation("ModalShade", "Panel")
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0, 0, 0, 0.45)
	t.set_stylebox("panel", "ModalShade", shade)

	# --- layout spacing (so screens need no per-control overrides) ---
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_type_variation("TightVBox", "VBoxContainer")
	t.set_constant("separation", "TightVBox", 2)
	t.set_type_variation("LooseVBox", "VBoxContainer")
	t.set_constant("separation", "LooseVBox", 12)
	t.set_type_variation("TightHBox", "HBoxContainer")
	t.set_constant("separation", "TightHBox", 4)
	t.set_type_variation("LooseHBox", "HBoxContainer")
	t.set_constant("separation", "LooseHBox", 18)

	# --- bars, separators, misc ---
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.08, 0.1, 0.9)
	bar_bg.set_corner_radius_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOOD
	bar_fill.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 12)
	t.set_type_variation("WorkBar", "ProgressBar")
	var work_fill: StyleBoxFlat = bar_fill.duplicate()
	work_fill.bg_color = ACCENT
	t.set_stylebox("fill", "WorkBar", work_fill)
	t.set_stylebox("background", "WorkBar", bar_bg)
	var line := StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 8)
	t.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "TooltipPanel", _flat(BG, ACCENT))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "PopupMenu", _flat(PANEL, BORDER))
	t.set_color("font_color", "PopupMenu", TEXT)

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(t, OUT)
	if err != OK:
		printerr("build_village_theme: cannot save %s (%s)" % [OUT, error_string(err)])
		quit(1)
		return
	print("build_village_theme: wrote " + OUT)
	quit(0)


func _label(t: Theme, variation: String, size: int, color: Color) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, color)


func _flat(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
