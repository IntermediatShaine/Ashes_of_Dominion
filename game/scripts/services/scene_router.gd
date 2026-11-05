extends Node
## Autoload "Router": scene navigation, application settings and the
## development debug overlay. Scenes never reference each other's paths.

const SCENES := {
	"main_menu": "res://scenes/menus/main_menu.tscn",
	"new_game": "res://scenes/menus/new_game.tscn",
	"load_game": "res://scenes/menus/load_game.tscn",
	"settings": "res://scenes/menus/settings_menu.tscn",
	# "settlement" is home: since Stage 1 the walkable village. The earlier
	# management screen is kept, unreachable in normal play, until the village
	# dashboard replaces everything it showed.
	"settlement": "res://scenes/village/village.tscn",
	"settlement_legacy": "res://scenes/settlement/settlement.tscn",
	"world_map": "res://scenes/world_map/world_map.tscn",
	"exploration": "res://scenes/exploration/exploration.tscn",
	"poi": "res://scenes/exploration/poi.tscn",
}
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {"window_mode": "windowed", "debug_overlay": false, "diagnostic_logging": false}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var current_scene_key: String = ""
## Scenes may put extra lines here (e.g. player coordinates).
var debug_extra: Array[String] = []
## Tests set this to capture navigation instead of replacing the scene tree.
var navigation_hook: Callable = Callable()

var _overlay: CanvasLayer
var _overlay_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()
	_build_overlay()


func go(key: String) -> void:
	assert(SCENES.has(key), "Unknown scene key " + key)
	current_scene_key = key
	Telemetry.record_event("scene_" + key)
	debug_extra.clear()
	get_tree().paused = false
	if navigation_hook.is_valid():
		navigation_hook.call(key)
		return
	call_deferred("_change", SCENES[key])


func _change(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router: cannot change to %s (%s)" % [path, error_string(err)])


func quit() -> void:
	Telemetry.record_event("application_quit")
	get_tree().quit()


# --- settings -------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		for k in DEFAULT_SETTINGS.keys():
			if data.has(k) and typeof(data[k]) == typeof(DEFAULT_SETTINGS[k]):
				settings[k] = data[k]


func save_settings() -> OpResult:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return OpResult.failure("Cannot write settings (%s)" % error_string(FileAccess.get_open_error()))
	f.store_string(JSON.stringify(settings, "\t"))
	f.close()
	return OpResult.success()


func set_diagnostic_logging(enabled: bool) -> OpResult:
	var previous := DictUtil.get_bool(settings, "diagnostic_logging", false)
	var result := Telemetry.set_enabled(enabled)
	if not result.ok:
		return result
	settings["diagnostic_logging"] = enabled
	var saved := save_settings()
	if not saved.ok:
		settings["diagnostic_logging"] = previous
		Telemetry.set_enabled(previous)
	return saved


func apply_settings() -> void:
	# This must run in headless mode too; only window settings are graphical.
	var logging := Telemetry.set_enabled(DictUtil.get_bool(settings, "diagnostic_logging", false))
	if not logging.ok:
		settings["diagnostic_logging"] = false
		push_warning("Optional diagnostic logging unavailable: " + logging.error)
	if DisplayServer.get_name() == "headless":
		return
	match String(settings.get("window_mode", "windowed")):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if _overlay:
		_overlay.visible = DictUtil.get_bool(settings, "debug_overlay", false)


# --- debug overlay --------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.visible = DictUtil.get_bool(settings, "debug_overlay", false)
	_overlay_label = Label.new()
	_overlay_label.position = Vector2(8, 8)
	_overlay_label.add_theme_font_size_override("font_size", 12)
	_overlay_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_overlay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("shadow_offset_x", 1)
	_overlay_label.add_theme_constant_override("shadow_offset_y", 1)
	_overlay.add_child(_overlay_label)
	add_child(_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_overlay.visible = not _overlay.visible
		settings["debug_overlay"] = _overlay.visible
		save_settings()


func _process(_delta: float) -> void:
	if not _overlay.visible:
		return
	var lines: Array[String] = ["[F3] scene: %s   fps %d   %s" % [current_scene_key, Engine.get_frames_per_second(), Engine.get_version_info().get("string", "")]]
	lines.append_array(Session.debug_lines())
	lines.append_array(debug_extra)
	_overlay_label.text = "\n".join(lines)
