class_name RngStream
extends RefCounted
## One named, independently seeded pseudorandom stream whose internal state can
## be persisted and restored exactly.
##
## Wraps Godot's RandomNumberGenerator (PCG32, pure integer arithmetic, identical
## across platforms). The seed comes from StableHash.derive_seed so that two
## streams of the same universe never share a sequence, and the `state` is
## written to the save file so that reloading continues the sequence rather
## than restarting it.

var stream_name: String
var seed_value: int
var draw_count: int = 0
var _rng := RandomNumberGenerator.new()


func _init(p_name: String, p_seed: int) -> void:
	stream_name = p_name
	seed_value = p_seed
	_rng.seed = p_seed


func randi_range(from: int, to: int) -> int:
	draw_count += 1
	return _rng.randi_range(from, to)


func randf() -> float:
	draw_count += 1
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	draw_count += 1
	return _rng.randf_range(from, to)


## True with probability `p` (clamped to [0, 1]).
## NOTE: the unqualified names randf()/randi_range() resolve to the GLOBAL
## (non-deterministic) functions inside this class, so every internal call
## goes through `self.` explicitly.
func chance(p: float) -> bool:
	return self.randf() < clampf(p, 0.0, 1.0)


## Pick one element of a non-empty array.
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "RngStream.pick on empty array")
	return items[self.randi_range(0, items.size() - 1)]


## Weighted pick: `weights` is an Array of positive floats parallel to `items`.
func weighted_pick(items: Array, weights: Array) -> Variant:
	assert(items.size() == weights.size() and not items.is_empty())
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := self.randf_range(0.0, total)
	var acc := 0.0
	for i in items.size():
		acc += float(weights[i])
		if roll < acc:
			return items[i]
	return items[items.size() - 1]


## Deterministic in-place Fisher–Yates shuffle.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := self.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


func get_state() -> Dictionary:
	# 64-bit values are stored as strings: JSON numbers are doubles and would
	# silently lose precision above 2^53.
	return {
		"name": stream_name,
		"seed": str(seed_value),
		"state": str(_rng.state),
		"draws": draw_count,
	}


static func from_state(data: Dictionary) -> RngStream:
	var s := RngStream.new(String(data.get("name", "")), DictUtil.get_int(data, "seed", 0))
	# Setting `seed` resets the state, so the state must be applied afterwards.
	if data.has("state"):
		s._rng.state = DictUtil.get_int(data, "state", 0)
	s.draw_count = DictUtil.get_int(data, "draws", 0)
	return s
