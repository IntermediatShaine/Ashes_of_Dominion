class_name IdFactory
extends RefCounted
## Stable gameplay identifiers.
##
## Sequential ids are drawn from a counters dictionary that lives inside the
## owning state object (UniverseState.id_counters, MultiverseState.id_counters),
## so they survive serialization and never collide. Node instance ids are never
## used as gameplay identifiers.


## Returns e.g. "exp_000007" and advances the counter stored in `counters`.
static func next_sequential(counters: Dictionary, prefix: String) -> String:
	var n: int = int(counters.get(prefix, 0)) + 1
	counters[prefix] = n
	return "%s_%06d" % [prefix, n]


## Non-sequential id for things created outside any universe (the character).
## Combines wall-clock time and a process-local random value; uniqueness is
## what matters here, not determinism.
static func new_global_id(prefix: String) -> String:
	var t := int(Time.get_unix_time_from_system() * 1000.0)
	var r := randi()
	var h := StableHash.hash_string("%s|%d|%d" % [prefix, t, r])
	return "%s_%s" % [prefix, hex16(h).right(12)]


static func universe_id(counter: int, world_seed: int) -> String:
	return "u%03d_%s" % [counter, hex16(StableHash.hash_string(str(world_seed))).right(8)]


## Unsigned 16-digit hex rendering of a 64-bit integer.
static func hex16(h: int) -> String:
	return String.num_uint64(h, 16).lpad(16, "0")
