extends Control
## Lists the save slots with metadata; loads or deletes one.

var _list: VBoxContainer
var _error: Label


func _ready() -> void:
	UiKit.style_screen(self)
	var col := UiKit.centered_column(self, 560)
	col.add_child(UiKit.title("Load Game"))
	_list = UiKit.vbox(8)
	col.add_child(_list)
	_error = UiKit.label("", 14, UiKit.BAD)
	col.add_child(_error)
	col.add_child(UiKit.button("Back", func(): Router.go("main_menu"), 200))
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var slots := Session.repository.list_slots()
	for s in range(1, SaveRepository.MAX_SLOTS + 1):
		var meta = slots[s]
		var panel := UiKit.panel()
		var row := UiKit.hbox(12)
		panel.add_child(row)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if meta is Dictionary:
			info.add_child(UiKit.label("Slot %d — %s, level %d" % [s, DictUtil.get_string(meta, "character_name"), DictUtil.get_int(meta, "level")], 18))
			info.add_child(UiKit.muted("Day %d · saved %s · universe %s" % [DictUtil.get_int(meta, "day"), DictUtil.get_string(meta, "saved_at_text"), DictUtil.get_string(meta, "universe_id")], 13))
			row.add_child(UiKit.button("Load", func(): _load(s), 110))
			row.add_child(UiKit.button("Delete", func(): _delete(s), 110))
		else:
			info.add_child(UiKit.label("Slot %d — empty" % s, 18, UiKit.MUTED))
		_list.add_child(panel)


func _load(slot: int) -> void:
	var r := Session.load_slot(slot)
	if not r.ok:
		_error.text = r.error
		return
	Router.go(Session.resume_scene_key())


func _delete(slot: int) -> void:
	var d := ConfirmationDialog.new()
	d.theme = UiKit.theme()
	d.dialog_text = "Delete slot %d permanently?" % slot
	add_child(d)
	d.confirmed.connect(func():
		var r := Session.repository.delete_slot(slot)
		if not r.ok:
			_error.text = r.error
		_refresh()
		d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	d.popup_centered()
