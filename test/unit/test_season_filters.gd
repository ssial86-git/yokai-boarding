class_name TestSeasonFilters
extends GdUnitTestSuite
## 절기 필터 (P3-S1): 절기 재료는 그 절기에만 채집 풀에, 절기 어종은 그 절기에만 후보에. 풀이 다 빠지면 조건 무시.


func _material(id: String, season: String, yin: String = "any") -> MaterialData:
	var material := MaterialData.new()
	material.id = id
	material.rarity = "common"
	material.season = season
	material.yin_condition = yin
	return material


func _fish(id: String, season: String, timeband: String = "any", kind: String = "fish") -> FishData:
	var fish := FishData.new()
	fish.id = id
	fish.region_id = "r_stream"
	fish.season = season
	fish.timeband = timeband
	fish.kind = kind
	fish.weight = 1
	fish.min_rod_level = 1
	return fish


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func test_gather_roll_respects_material_season() -> void:
	var region := RegionData.new()
	region.id = "r_hill"
	region.gather_point_count = 40
	region.gather_pool = ["m_any", "m_summer", "m_winter", "m_high"]
	var catalog := {
		"m_any": _material("m_any", "any"), "m_summer": _material("m_summer", "summer"),
		"m_winter": _material("m_winter", "winter"), "m_high": _material("m_high", "any", "high"),
	}
	var summer := GatherPoints.roll(region, catalog, _rng(), false, "summer")
	assert_bool(summer.material_ids.has("m_summer")).is_true()
	assert_bool(summer.material_ids.has("m_winter")).is_false()
	assert_bool(summer.material_ids.has("m_high")).is_false()  # 음기 조건도 함께
	var winter_high := GatherPoints.roll(region, catalog, _rng(), true, "winter")
	assert_bool(winter_high.material_ids.has("m_winter")).is_true()
	assert_bool(winter_high.material_ids.has("m_summer")).is_false()
	assert_bool(winter_high.material_ids.has("m_high")).is_true()
	var no_season := GatherPoints.roll(region, catalog, _rng(), false, "")
	assert_bool(no_season.material_ids.has("m_summer") or no_season.material_ids.has("m_winter")).is_true()
	# 조건으로 다 빠지면 무시
	region.gather_pool = ["m_winter"]
	var fallback := GatherPoints.roll(region, catalog, _rng(), false, "summer")
	assert_int(fallback.size()).is_equal(40)


func test_fishing_candidates_respect_season() -> void:
	var catalog := {
		"f_any": _fish("f_any", "any"), "f_summer": _fish("f_summer", "summer"), "f_winter": _fish("f_winter", "winter", "day"),
		"j_junk": _fish("j_junk", "any", "any", "junk"),
	}
	var ids := func(pool: Array[FishData]) -> Array[String]:
		var result: Array[String] = []
		for fish in pool:
			result.append(fish.id)
		return result
	assert_array(ids.call(Fishing.candidates(catalog, "r_stream", "day", 1, true, "summer"))).contains_exactly(["f_any", "f_summer", "j_junk"])
	assert_array(ids.call(Fishing.candidates(catalog, "r_stream", "day", 1, true, "winter"))).contains_exactly(["f_any", "f_winter", "j_junk"])
	assert_array(ids.call(Fishing.candidates(catalog, "r_stream", "night", 1, true, "winter"))).contains_exactly(["f_any", "j_junk"])
	assert_array(ids.call(Fishing.candidates(catalog, "r_stream", "day", 1, false, ""))).contains_exactly(["f_any", "f_summer", "f_winter"])
