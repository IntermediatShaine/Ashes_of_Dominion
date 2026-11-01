extends Control
## Main menu: New Game / Continue / Load Game / Settings / Quit.
## Actions that cannot work are disabled rather than hidden so the player
## sees that they exist.


func _ready() -> void:
	UiKit.style_screen(self)
	var col := UiKit.centered_column(self, 360)
	col.add_child(UiKit.title("ASHES OF DOMINION", 40))
	col.add_child(UiKit.muted("First playable vertical slice — placeholder visuals"))
	col.add_child(UiKit.separator())
	col.add_child(UiKit.button("New Game", func(): Router.go("new_game"), 360))
	var latest := Session.latest_slot()
	var cont := UiKit.button("Continue" + (" (slot %d)" % latest if latest > 0 else ""), _on_continue, 360)
	cont.disabled = latest == 0
	col.add_child(cont)
	var any_saves := latest > 0
	var load_btn := UiKit.button("Load Game", func(): Router.go("load_game"), 360)
	load_btn.disabled = not any_saves
	col.add_child(load_btn)
	col.add_child(UiKit.button("Settings", func(): Router.go("settings"), 360))
	col.add_child(UiKit.button("Quit", func(): Router.quit(), 360))
	col.add_child(UiKit.separator())
	col.add_child(UiKit.muted("Godot %s  ·  F3 toggles the debug overlay" % Engine.get_version_info().get("string", ""), 12))
	if not Content.load_errors.is_empty():
		col.add_child(UiKit.label("Content errors:\n" + "\n".join(Content.load_errors), 13, UiKit.BAD, true))


func _on_continue() -> void:
	var r := Session.continue_latest()
	if r.ok:
		Router.go("settlement")
	else:
		UiKit.message(self, "Cannot continue", r.error)
