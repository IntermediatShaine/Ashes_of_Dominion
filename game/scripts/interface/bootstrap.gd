extends Control
## Entry scene. Verifies content loaded, then hands off to the main menu.
## Kept separate from the menu so startup diagnostics have a home.


func _ready() -> void:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	if not Content.load_errors.is_empty():
		label.text = "Content errors:\n" + "\n".join(Content.load_errors)
		push_error("Bootstrap: content errors, staying on bootstrap screen")
		return
	label.text = "Ashes of Dominion"
	await get_tree().process_frame
	Router.go("main_menu")
