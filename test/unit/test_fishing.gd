class_name TestFishing
extends GdUnitTestSuite
## 낚시: 타이밍 바 판정(관대한 구간), 구역·시간대·낚싯대 필터, 가중 추첨.


func _fish(id: String, kind: String, region: String, weight: int, timeband: String, rod: int) -> FishData:
	var fish := FishData.new()
	fish.id = id
	fish.kind = kind
	fish.region_id = region
	fish.weight = weight
	fish.timeband = timeband
	fish.min_rod_level = rod
	return fish


func _catalog() -> Dictionary:
	return {
		"f_a": _fish("f_a", "fish", "r_stream", 5, "any", 1),
		"f_night": _fish("f_night", "fish", "r_stream", 2, "night", 1),
		"f_pro": _fish("f_pro", "fish", "r_stream", 2, "any", 2),
		"j_boot": _fish("j_boot", "junk", "r_stream", 3, "any", 1),
		"f_other": _fish("f_other", "fish", "r_ash_field", 9, "any", 1),
	}


func test_cast_window_and_marker_hit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cast := Fishing.new_cast(rng, 0.4, 1.0)
	assert_float(cast.half_width).is_equal(0.2)
	assert_float(cast.center).is_between(0.2, 0.8)
	# 마커는 0.5 에서 출발해 1주기 동안 0..1 을 왕복한다
	cast.elapsed = 0.0
	assert_float(cast.marker()).is_equal_approx(0.5, 0.0001)
	cast.elapsed = 0.25
	assert_float(cast.marker()).is_equal_approx(1.0, 0.0001)
	cast.elapsed = 0.75
	assert_float(cast.marker()).is_equal_approx(0.0, 0.0001)
	# 구간 판정은 |마커 - 중심| <= 반폭
	cast.center = 0.5
	cast.elapsed = 0.0
	assert_bool(cast.is_hit()).is_true()
	cast.elapsed = 0.25
	assert_bool(cast.is_hit()).is_false()
	cast.advance(0.5)
	assert_float(cast.elapsed).is_equal(0.75)
	cast.advance(-3.0)
	assert_float(cast.elapsed).is_equal(0.75)


func test_candidates_filter_by_region_timeband_and_rod() -> void:
	var catalog := _catalog()
	var ids: Array[String] = []
	for fish in Fishing.candidates(catalog, "r_stream", "day", 1):
		ids.append(fish.id)
	assert_array(ids).contains_exactly(["f_a", "j_boot"])
	ids.clear()
	for fish in Fishing.candidates(catalog, "r_stream", "night", 2, false):
		ids.append(fish.id)
	assert_array(ids).contains_exactly(["f_a", "f_night", "f_pro"])
	assert_int(Fishing.candidates(catalog, "r_yard", "day", 1).size()).is_equal(0)


func test_roll_is_weighted_and_junk_only() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pool := Fishing.candidates(_catalog(), "r_stream", "day", 1)
	var counts := {"f_a": 0, "j_boot": 0}
	for i in 400:
		counts[Fishing.roll(pool, rng).id] += 1
	assert_int(counts["f_a"]).is_greater(counts["j_boot"])  # 5:3
	assert_int(counts["j_boot"]).is_greater(60)
	var junk := Fishing.junk_only(pool)
	assert_int(junk.size()).is_equal(1)
	assert_str(junk[0].id).is_equal("j_boot")
	var empty: Array[FishData] = []
	assert_object(Fishing.roll(empty, rng)).is_null()
