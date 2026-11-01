extends Node
## Autoload "Telemetry": optional, on-device diagnostics only.
## Turning this off never affects normal gameplay or Godot's native error output.

var _log: DiagnosticLog = DiagnosticLog.new()


func set_enabled(on: bool) -> OpResult:
	return _log.set_enabled(on)


func is_enabled() -> bool:
	return _log.is_enabled()


func record_event(event_name: String, values: Dictionary = {}) -> void:
	_log.record_event(event_name, values)


func log_paths() -> Array[String]:
	return _log.log_paths()


func clear_logs() -> OpResult:
	return _log.clear_logs()


func _exit_tree() -> void:
	_log.set_enabled(false)
