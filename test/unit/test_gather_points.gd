class_name TestGatherPoints
extends GdUnitTestSuite
## 채집 포인트: 희귀도 가중 추첨, 도구 조건, 채집·상태 복원.


func _material(id: String, rarity: String, tool_kind: String = "none", min_level: int = 0) -> MaterialData:
	var material := MaterialData.new()
	material.id = id
	material.rarity = rarity
	material.tool_kind = tool_kind
	material.min_tool_level = min_level
	return material


func _region(point_count: int, pool: Array) -> RegionData:
	var region := RegionData.new()
	region.id = "r_test"
	region.gather_point_count = point_count
	region.gather_pool = pool
	return region


func _catalog() -> Dictionary:
	return {
		"m_a": _material("m_a", "common"),
		"m_b": _material("m_b", "rare"),
		"wood": _material("wood", "common", "axe", 1),
		"m_ore": _material("m_ore", "uncommon", "pickaxe", 2),
	}


func test_roll_uses_pool_and_rarity_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var points := GatherPoints.roll(_region(200, ["m_a", "m_b"]), _catalog(), rng)
	assert_int(points.size()).is_equal(200)
	var common := 0
	for i in points.size():
		if points.material_at(i) == "m_a":
			common += 1
	assert_int(common).is_greater(120)  # 3:1 가중이면 대략 150
	assert_int(common).is_less(200)
	assert_int(GatherPoints.roll(_region(5, []), _catalog(), rng).size()).is_equal(0)
	assert_int(GatherPoints.roll(_region(5, ["missing"]), _catalog(), rng).size()).is_equal(0)


func test_tool_requirements_and_take() -> void:
	var points := GatherPoints.from_state("r_test", ["m_a", "wood", "m_ore"], [])
	var catalog := _catalog()
	assert_int(points.check(0, catalog, {})).is_equal(GatherPoints.Outcome.OK)
	assert_int(points.check(1, catalog, {})).is_equal(GatherPoints.Outcome.NEED_TOOL)
	assert_int(points.check(1, catalog, {"axe": 1})).is_equal(GatherPoints.Outcome.OK)
	assert_int(points.check(2, catalog, {"pickaxe": 1})).is_equal(GatherPoints.Outcome.TOOL_TOO_WEAK)
	assert_int(points.check(2, catalog, {"pickaxe": 2})).is_equal(GatherPoints.Outcome.OK)
	assert_int(points.check(7, catalog, {})).is_equal(GatherPoints.Outcome.OUT_OF_RANGE)
	assert_str(points.take(0)).is_equal("m_a")
	assert_str(points.take(0)).is_equal("")
	assert_int(points.check(0, catalog, {})).is_equal(GatherPoints.Outcome.TAKEN)
	assert_int(points.remaining()).is_equal(2)
	assert_array(points.taken_indices()).contains_exactly(["0"])


func test_restore_taken_from_state() -> void:
	var points := GatherPoints.from_state("r_test", ["m_a", "m_a", "m_b"], ["2", "9"])
	assert_bool(points.is_taken(2)).is_true()
	assert_bool(points.is_taken(0)).is_false()
	assert_int(points.remaining()).is_equal(2)
