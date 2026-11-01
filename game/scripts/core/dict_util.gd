class_name DictUtil
extends RefCounted
## Typed accessors for dictionaries that came out of JSON (where every number
## is a float) plus a few deterministic helpers.


static func get_int(d: Dictionary, key: String, default_value: int = 0) -> int:
	var v = d.get(key, default_value)
	if v is int:
		return v
	if v is float:
		return int(round(v))
	if v is String and (v as String).is_valid_int():
		return int(v)
	return default_value


static func get_float(d: Dictionary, key: String, default_value: float = 0.0) -> float:
	var v = d.get(key, default_value)
	if v is float or v is int:
		return float(v)
	return default_value


static func get_bool(d: Dictionary, key: String, default_value: bool = false) -> bool:
	var v = d.get(key, default_value)
	if v is bool:
		return v
	return default_value


static func get_string(d: Dictionary, key: String, default_value: String = "") -> String:
	var v = d.get(key, default_value)
	if v is String:
		return v
	return default_value


static func get_dict(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key, {})
	if v is Dictionary:
		return v
	return {}


static func get_array(d: Dictionary, key: String) -> Array:
	var v = d.get(key, [])
	if v is Array:
		return v
	return []


## Dictionary of int values (JSON floats are converted).
static func int_map(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		out[String(k)] = get_int(d, String(k), 0)
	return out


static func string_array(a: Array) -> Array[String]:
	var out: Array[String] = []
	for v in a:
		out.append(String(v))
	return out


## Keys sorted so that iteration order never depends on insertion history.
static func sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


## Deep-compare two JSON-like values (int/float equality is numeric).
static func deep_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k) or not deep_equal(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not deep_equal(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b)) if (a is float or b is float) else a == b
	return a == b
