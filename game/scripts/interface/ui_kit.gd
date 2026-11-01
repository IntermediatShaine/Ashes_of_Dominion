class_name UiKit
extends RefCounted
## Small helpers for building the placeholder interface in code. One theme,
## a few constructors. Keeps every screen consistent without a .tres theme
## that would need the editor to maintain.

const BG := Color("1d1a24")
const PANEL := Color("2a2533")
const PANEL_BORDER := Color("4a3f55")
const ACCENT := Color("c9742a")
const TEXT := Color("e8e0d0")
const MUTED := Color("9a9088")
const GOOD := Color("7cb86a")
const BAD := Color("c9553a")

static var _theme: Theme = null


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	var btn := _flat(Color("3a3144"), PANEL_BORDER)
	var btn_hover := _flat(Color("4b3f58"), ACCENT)
	var btn_pressed := _flat(Color("2b2434"), ACCENT)
	var btn_disabled := _flat(Color("262230"), Color("3a3542"))
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, PANEL_BORDER))
	t.set_stylebox("panel", "Panel", _flat(PANEL, PANEL_BORDER))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "LineEdit", _flat(Color("17141d"), PANEL_BORDER))
	t.set_stylebox("focus", "LineEdit", _flat(Color("17141d"), ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("hover", "OptionButton", btn_hover)
	t.set_stylebox("pressed", "OptionButton", btn_pressed)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", _flat(PANEL, PANEL_BORDER))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("hover", "PopupMenu", _flat(Color("4b3f58"), ACCENT))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "RichTextLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	_theme = t
	return t


static func _flat(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
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


## Full-rect background + theme for a screen root.
static func style_screen(root: Control) -> void:
	root.theme = theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	root.move_child(bg, 0)


static func title(text: String, size: int = 30) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	return l


## Single-line by default (safe inside HBox rows); pass wrap=true for paragraphs.
static func label(text: String, size: int = 16, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


## Secondary text; wraps by default because it is used for descriptions.
static func muted(text: String, size: int = 14, wrap: bool = true) -> Label:
	return label(text, size, MUTED, wrap)


static func button(text: String, on_pressed: Callable, min_width: float = 220.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 40)
	b.pressed.connect(on_pressed)
	return b


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func vbox(spacing: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", spacing)
	return v


static func hbox(spacing: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", spacing)
	return h


static func separator() -> HSeparator:
	return HSeparator.new()


static func centered_column(root: Control, width: float = 520.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := vbox(10)
	col.custom_minimum_size = Vector2(width, 0)
	center.add_child(col)
	return col


## Simple modal message box.
static func message(root: Node, title_text: String, body: String, on_close: Callable = Callable()) -> AcceptDialog:
	var d := AcceptDialog.new()
	d.title = title_text
	d.dialog_text = body
	d.theme = theme()
	d.exclusive = true
	root.add_child(d)
	d.confirmed.connect(func():
		if on_close.is_valid():
			on_close.call()
		d.queue_free())
	d.canceled.connect(func():
		if on_close.is_valid():
			on_close.call()
		d.queue_free())
	d.popup_centered()
	return d
