class_name SaveRepository
extends RefCounted
## Slot-based, crash-safe JSON persistence.
##
## Layout:  <base_dir>/slot_<n>/save.json        (latest known-good)
##          <base_dir>/slot_<n>/save.json.bak    (previous known-good)
##          <base_dir>/slot_<n>/save.json.tmp    (in-flight write)
##
## Write protocol (never modifies the only known-good file in place):
##   1. serialize; write to .tmp; flush; close
##   2. read .tmp back and fully validate it (catches partial/corrupt writes)
##   3. if save.json exists: delete old .bak, rename save.json -> .bak
##   4. rename .tmp -> save.json; verify save.json exists; fall back to copy
##      if the rename fails (Windows can refuse renames while a file is open
##      by another process, so rename success is checked, not assumed)
## Load protocol: save.json, then .bak, then a validated .tmp (a completed
## write whose final rename never happened). Which file was used is reported.

const MAX_SLOTS: int = 3
const FILE_NAME := "save.json"

var base_dir: String


func _init(p_base_dir: String = "user://saves") -> void:
	base_dir = p_base_dir


func slot_dir(slot: int) -> String:
	return "%s/slot_%d" % [base_dir, slot]


func primary_path(slot: int) -> String:
	return slot_dir(slot) + "/" + FILE_NAME


func backup_path(slot: int) -> String:
	return primary_path(slot) + ".bak"


func temp_path(slot: int) -> String:
	return primary_path(slot) + ".tmp"


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOTS


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(primary_path(slot)) or FileAccess.file_exists(backup_path(slot))


func write(slot: int, save: SaveGame) -> OpResult:
	if not is_valid_slot(slot):
		return OpResult.failure("Invalid save slot %d" % slot)
	save.refresh_meta(slot)
	var pre_errors := save.validate()
	if not pre_errors.is_empty():
		return OpResult.failure("Refusing to write invalid state: " + "; ".join(pre_errors))
	var text := JSON.stringify(save.to_dict(), "\t")

	var dir_err := DirAccess.make_dir_recursive_absolute(slot_dir(slot))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return OpResult.failure("Cannot create save directory (%s)" % error_string(dir_err))

	# 1. write temp
	var tmp := temp_path(slot)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return OpResult.failure("Cannot open temp save for writing (%s)" % error_string(FileAccess.get_open_error()))
	f.store_string(text)
	f.flush()
	f.close()

	# 2. read back + validate
	var check := _read_and_validate(tmp)
	if not check.ok:
		DirAccess.remove_absolute(tmp)
		return OpResult.failure("Temp save failed verification: " + check.error)

	# 3. rotate previous known-good into backup
	var primary := primary_path(slot)
	var backup := backup_path(slot)
	if FileAccess.file_exists(primary):
		if FileAccess.file_exists(backup):
			var rm := DirAccess.remove_absolute(backup)
			if rm != OK:
				return OpResult.failure("Cannot remove old backup (%s)" % error_string(rm))
		var rot := DirAccess.rename_absolute(primary, backup)
		if rot != OK or not FileAccess.file_exists(backup):
			return OpResult.failure("Cannot rotate previous save into backup (%s)" % error_string(rot))

	# 4. promote temp
	var promote := DirAccess.rename_absolute(tmp, primary)
	if promote != OK or not FileAccess.file_exists(primary):
		var cp := DirAccess.copy_absolute(tmp, primary)
		if cp != OK or not FileAccess.file_exists(primary):
			return OpResult.failure("Cannot promote temp save (rename %s, copy %s); previous save preserved as backup" % [error_string(promote), error_string(cp)])
		DirAccess.remove_absolute(tmp)
	var final_check := _read_and_validate(primary)
	if not final_check.ok:
		return OpResult.failure("Promoted save failed verification: " + final_check.error)
	return OpResult.success(primary)


## Loads the best available file for the slot. value = SaveGame; warnings
## say if recovery was needed.
func load_slot(slot: int) -> OpResult:
	if not is_valid_slot(slot):
		return OpResult.failure("Invalid save slot %d" % slot)
	var candidates := [
		["primary", primary_path(slot)],
		["backup", backup_path(slot)],
		["temp", temp_path(slot)],
	]
	var problems: Array[String] = []
	for c in candidates:
		var label: String = c[0]
		var path: String = c[1]
		if not FileAccess.file_exists(path):
			continue
		var r := _read_and_validate(path)
		if r.ok:
			if label != "primary":
				r.with_warning("Recovered slot %d from %s file" % [slot, label])
				push_warning("Save slot %d: primary unusable (%s); recovered from %s" % [slot, "; ".join(problems), label])
			return r
		problems.append("%s: %s" % [label, r.error])
	if problems.is_empty():
		return OpResult.failure("No save in slot %d" % slot)
	return OpResult.failure("Slot %d unreadable — " % slot + "; ".join(problems))


## Metadata for every slot: slot -> meta dict or null.
func list_slots() -> Dictionary:
	var out := {}
	for slot in range(1, MAX_SLOTS + 1):
		out[slot] = null
		var r := load_slot(slot)
		if r.ok:
			out[slot] = (r.value as SaveGame).meta
	return out


func delete_slot(slot: int) -> OpResult:
	if not is_valid_slot(slot):
		return OpResult.failure("Invalid save slot %d" % slot)
	for p in [primary_path(slot), backup_path(slot), temp_path(slot)]:
		if FileAccess.file_exists(p):
			var e := DirAccess.remove_absolute(p)
			if e != OK:
				return OpResult.failure("Cannot delete %s (%s)" % [p, error_string(e)])
	return OpResult.success()


func _read_and_validate(path: String) -> OpResult:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return OpResult.failure("cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
	var text := f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return OpResult.failure("empty file")
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return OpResult.failure("JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	return SaveValidator.build_and_validate(json.data)
