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
	var logging := CheckBox.new()
	logging.text = "Keep local diagnostic logs (optional)"
	logging.button_pressed = DictUtil.get_bool(Router.settings, "diagnostic_logging", false)
	logging.toggled.connect(func(on: bool):
		var result := Router.set_diagnostic_logging(on)
		if not result.ok:
			logging.set_pressed_no_signal(not on)
			UiKit.message(self, "Diagnostic logging", result.error))
	col.add_child(logging)
	col.add_child(UiKit.muted("Off by default. Records gameplay events and save checks locally; never uploads data. Keeps up to 5 session logs (1 MiB each).", 12))
	col.add_child(UiKit.muted("Log folder: " + ProjectSettings.globalize_path("user://telemetry"), 12))
	col.add_child(UiKit.button("Delete stored diagnostic logs", func(): _clear_logs(logging), 310))
	col.add_child(UiKit.separator())
	col.add_child(UiKit.muted("Controls: WASD / arrows move · Left mouse or Space attack · E interact · M world map · Esc pause", 13))
	col.add_child(UiKit.muted("Save files: " + ProjectSettings.globalize_path("user://saves"), 12))
	col.add_child(UiKit.button("Back", func(): Router.go("settlement" if Session.has_game() else "main_menu"), 200))


func _clear_logs(logging: CheckBox) -> void:
	var off := Router.set_diagnostic_logging(false)
	if not off.ok:
		UiKit.message(self, "Cannot disable logging", off.error)
		return
	logging.set_pressed_no_signal(false)
	var cleared := Telemetry.clear_logs()
	UiKit.message(self, "Diagnostic logs", "Stored diagnostic logs deleted." if cleared.ok else cleared.error)
