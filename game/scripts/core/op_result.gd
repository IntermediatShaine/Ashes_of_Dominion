class_name OpResult
extends RefCounted
## Explicit success/failure value for operations that can fail in controlled
## ways (saving, loading, construction, planning). Errors are never swallowed:
## callers either branch on `ok` or surface `error` to the UI/log.

var ok: bool = false
var error: String = ""
var value: Variant = null
## Optional non-fatal notes (e.g. "recovered from backup").
var warnings: Array[String] = []


static func success(p_value: Variant = null) -> OpResult:
	var r := OpResult.new()
	r.ok = true
	r.value = p_value
	return r


static func failure(message: String) -> OpResult:
	var r := OpResult.new()
	r.ok = false
	r.error = message
	return r


func with_warning(message: String) -> OpResult:
	warnings.append(message)
	return self
