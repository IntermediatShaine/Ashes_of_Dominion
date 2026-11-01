extends Control
## Application settings. Only options that do something are shown.


func _ready() -> void:
	UiKit.style_screen(self)
	var col := UiKit.centered_column(self, 460)
	col.add_child(UiKit.title("Settings"))
	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = String(Router.settings.get("window_mode", "windowed")) == "fullscreen"
	fullscreen.toggled.connect(func(on):
		Router.settings["window_mode"] = "fullscreen" if on else "windowed"
		Router.apply_settings()
		Router.save_settings())
	col.add_child(fullscreen)
	var overlay := CheckBox.new()
	overlay.text = "Show debug overlay (F3)"
	overlay.button_pressed = DictUtil.get_bool(Router.settings, "debug_overlay", false)
	overlay.toggled.connect(func(on):
		Router.settings["debug_overlay"] = on
		Router.apply_settings()
		Router.save_settings())
	col.add_child(overlay)
	col.add_child(UiKit.separator())
	col.add_child(UiKit.muted("Controls: WASD / arrows move · Left mouse or Space attack · E interact · M world map · Esc pause", 13))
	col.add_child(UiKit.muted("Save files: " + ProjectSettings.globalize_path("user://saves"), 12))
	col.add_child(UiKit.button("Back", func(): Router.go("settlement" if Session.has_game() else "main_menu"), 200))
