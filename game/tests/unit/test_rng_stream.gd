extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := RngStream.new("x", 777)
	var b := RngStream.new("x", 777)
	for i in 50:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000))


func test_state_roundtrip_continues_sequence() -> void:
	var a := RngStream.new("x", 4242)
	for i in 17:
		a.randf()
	var state := a.get_state()
	var b := RngStream.from_state(JSON.parse_string(JSON.stringify(state)))
	for i in 20:
		assert_eq(a.randi_range(0, 99999), b.randi_range(0, 99999))
	assert_eq(b.draw_count, a.draw_count)


func test_registry_streams_are_independent() -> void:
	var reg := RngRegistry.create_fresh(9001)
	var combat_first := reg.stream("combat").randi_range(0, 1 << 30)
	var reg2 := RngRegistry.create_fresh(9001)
	# Draw heavily from other streams first; combat must be unaffected.
	for i in 100:
		reg2.stream("rewards").randf()
		reg2.stream("events").randf()
		reg2.stream("encounter").randf()
	assert_eq(reg2.stream("combat").randi_range(0, 1 << 30), combat_first)
	assert_ne(reg.stream("rewards").randi_range(0, 1 << 30), reg.stream("events").randi_range(0, 1 << 30))


func test_registry_serialization() -> void:
	var reg := RngRegistry.create_fresh(5)
	reg.stream("rewards").randf()
	reg.stream("rewards").randf()
	var d: Dictionary = JSON.parse_string(JSON.stringify(reg.to_dict()))
	var restored := RngRegistry.from_dict(d, 5)
	assert_eq(restored.stream("rewards").randi_range(0, 1 << 30), reg.stream("rewards").randi_range(0, 1 << 30))
	assert_eq(restored.stream("combat").randi_range(0, 1 << 30), reg.stream("combat").randi_range(0, 1 << 30))


func test_helpers() -> void:
	var s := RngStream.new("h", 1)
	var items := [1, 2, 3, 4, 5]
	var copy := items.duplicate()
	s.shuffle(copy)
	copy.sort()
	assert_eq(copy, items)
	var w: String = s.weighted_pick(["a", "b"], [0.0, 1.0])
	assert_eq(w, "b")
