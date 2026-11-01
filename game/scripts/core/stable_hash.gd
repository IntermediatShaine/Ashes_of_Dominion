class_name StableHash
extends RefCounted
## Deterministic, platform-independent hashing used for seed derivation.
##
## Algorithm: FNV-1a (64-bit) over UTF-8 bytes, followed by a splitmix64-style
## finalizer so that nearby inputs ("seed|combat" vs "seed|rewards") produce
## well-separated outputs. GDScript integers are 64-bit and wrap on overflow,
## which is exactly the modular arithmetic FNV requires.
##
## Never use Godot's built-in `hash()` for anything persisted: it is not
## guaranteed stable between engine versions.

## 14695981039346656037 expressed as a signed 64-bit integer.
const FNV_OFFSET_BASIS: int = -3750763034362895579
const FNV_PRIME: int = 1099511628211

## 0xBF58476D1CE4E5B9 and 0x94D049BB133111EB as signed 64-bit integers.
const MIX_A: int = -4658895280553007687
const MIX_B: int = -7723592293110705685


## Logical (unsigned) right shift for 64-bit integers; `n` must be in 1..63.
static func ushr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


## Raw FNV-1a of the UTF-8 bytes of `text` (no finalizer).
static func fnv1a(text: String) -> int:
	var h: int = FNV_OFFSET_BASIS
	for b in text.to_utf8_buffer():
		h = h ^ int(b)
		h = h * FNV_PRIME
	return h


## splitmix64 finalizer. Bijective on 64-bit integers, good avalanche.
static func mix(z: int) -> int:
	z = (z ^ ushr(z, 30)) * MIX_A
	z = (z ^ ushr(z, 27)) * MIX_B
	return z ^ ushr(z, 31)


## Stable 64-bit hash of a string.
static func hash_string(text: String) -> int:
	return mix(fnv1a(text))


## Derive a child seed from a root seed and a label. Deterministic forever
## (this is part of the save-compatibility contract; see docs/technical_decisions.md).
static func derive_seed(root_seed: int, label: String) -> int:
	return hash_string("%d|%s" % [root_seed, label])


## Hash of a 2D integer cell plus a seed; used by value noise in generation.
static func hash_cell(seed_value: int, x: int, y: int) -> int:
	var h: int = seed_value
	h = mix(h ^ (x * 1099511628211))
	h = mix(h ^ (y * -7046029254386353131))
	return h


## Map a hash to a float in [0, 1).
static func to_unit_float(h: int) -> float:
	return float(ushr(h, 11)) / 9007199254740992.0  # 2^53


## Parse a user-supplied seed string: numeric strings become that integer,
## anything else is hashed. Empty input is rejected by the caller.
static func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_valid_int():
		return int(trimmed)
	return hash_string(trimmed)
