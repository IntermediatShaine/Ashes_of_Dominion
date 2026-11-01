extends TestCase


func test_fnv1a_known_vectors() -> void:
	# Reference values for FNV-1a 64 (from the FNV test suite), as signed int64.
	assert_eq(StableHash.fnv1a(""), StableHash.FNV_OFFSET_BASIS)
	assert_eq(StableHash.fnv1a("a"), -5808556873153909620)        # 0xaf63dc4c8601ec8c
	assert_eq(StableHash.fnv1a("foobar"), -8821353812377114648)   # 0x85944171f73967e8


func test_hash_is_stable_and_distinct() -> void:
	assert_eq(StableHash.hash_string("ashes"), StableHash.hash_string("ashes"))
	assert_ne(StableHash.hash_string("ashes"), StableHash.hash_string("ashez"))
	assert_ne(StableHash.derive_seed(1, "combat"), StableHash.derive_seed(1, "rewards"))
	assert_ne(StableHash.derive_seed(1, "combat"), StableHash.derive_seed(2, "combat"))


func test_ushr_is_logical() -> void:
	assert_eq(StableHash.ushr(-1, 1), 9223372036854775807)
	assert_eq(StableHash.ushr(-1, 63), 1)
	assert_eq(StableHash.ushr(1024, 10), 1)


func test_unit_float_range() -> void:
	for i in 200:
		var f := StableHash.to_unit_float(StableHash.hash_cell(99, i, i * 7))
		assert_true(f >= 0.0 and f < 1.0, "unit float out of range: %f" % f)


func test_seed_from_text() -> void:
	assert_eq(StableHash.seed_from_text("42"), 42)
	assert_eq(StableHash.seed_from_text(" -7 "), -7)
	assert_eq(StableHash.seed_from_text("emberfall"), StableHash.hash_string("emberfall"))
