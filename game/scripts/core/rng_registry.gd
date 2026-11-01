class_name RngRegistry
extends RefCounted
## Universe-scoped set of independent random streams.
##
## Each subsystem draws only from its own stream, so combat rolls never change
## future terrain, opening a menu never changes rewards, etc. Streams are
## seeded from the universe seed via StableHash.derive_seed and their live
## state is persisted inside UniverseState.rng_states.

const STREAM_NAMES: Array[String] = [
	"world_geometry",   # strategic map layout (used at generation time only)
	"route",            # route alternatives / hazards
	"encounter",        # enemy placement inside explorable areas
	"combat",           # damage variance
	"rewards",          # drops and loot
	"events",           # world simulation / settlement events
]

var _streams: Dictionary = {}


static func create_fresh(universe_seed: int) -> RngRegistry:
	var reg := RngRegistry.new()
	for name in STREAM_NAMES:
		reg._streams[name] = RngStream.new(name, StableHash.derive_seed(universe_seed, "stream:" + name))
	return reg


static func from_dict(data: Dictionary, universe_seed: int) -> RngRegistry:
	var reg := RngRegistry.new()
	for name in STREAM_NAMES:
		if data.has(name) and data[name] is Dictionary:
			reg._streams[name] = RngStream.from_state(data[name])
		else:
			# A stream missing from an older save is recreated deterministically.
			reg._streams[name] = RngStream.new(name, StableHash.derive_seed(universe_seed, "stream:" + name))
	return reg


func to_dict() -> Dictionary:
	var out := {}
	for name in STREAM_NAMES:
		out[name] = (_streams[name] as RngStream).get_state()
	return out


func stream(name: String) -> RngStream:
	assert(_streams.has(name), "Unknown rng stream: " + name)
	return _streams[name]


func has_stream(name: String) -> bool:
	return _streams.has(name)
