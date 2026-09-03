class_name TestWeatherRoll
extends GdUnitTestSuite
## 날씨 × 음기 추첨 (P2-S1)과 음기의 세 효과: 손님 종족 가중치 배율, 채집 재료의 음기 조건, 작물 제철·음기 성장.


func _weather(id: String, season: String, weight: int, yin_min: int, yin_max: int, mortal := 1.0, demon := 1.0) -> WeatherData:
	var weather := WeatherData.new()
	weather.id = id
	weather.name_ko = id
	weather.season = season
	weather.weight = weight
	weather.yin_min = yin_min
	weather.yin_max = yin_max
	weather.mortal_guest_multiplier = mortal
	weather.demon_guest_multiplier = demon
	return weather


func _catalog() -> Dictionary:
	return {
		"clear": _weather("clear", "any", 50, 0, 1, 1.0, 0.5),
		"rain": _weather("rain", "any", 25, 1, 2, 0.8, 1.0),
		"fog": _weather("fog", "spring", 15, 2, 3, 0.4, 1.6),
		"snow": _weather("snow", "winter", 30, 1, 3),
		"never": _weather("never", "any", 0, 0, 0),
	}


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _species(id: String, realm: String, weight: int) -> GuestSpeciesData:
	var species := GuestSpeciesData.new()
	species.id = id
	species.realm = realm
	species.weight = weight
	return species


func _visitor() -> VisitorData:
	var visitor := VisitorData.new()
	visitor.id = "v_guest"
	visitor.kind = "guest"
	visitor.weight = 1
	return visitor


func _material(id: String, yin_condition: String) -> MaterialData:
	var material := MaterialData.new()
	material.id = id
	material.rarity = "common"
	material.yin_condition = yin_condition
	return material


func test_eligible_filters_by_season_and_zero_weight() -> void:
	var spring := WeatherRoll.eligible(_catalog(), "spring")
	var ids: Array[String] = []
	for weather in spring:
		ids.append(weather.id)
	assert_array(ids).contains_exactly(["clear", "fog", "rain"])  # 눈은 겨울만, never 는 가중치 0
	var winter := WeatherRoll.eligible(_catalog(), "winter")
	assert_int(winter.size()).is_equal(3)


func test_roll_stays_in_yin_range_and_is_deterministic() -> void:
	var catalog := _catalog()
	var seen: Dictionary = {}
	for seed in 60:
		var result := WeatherRoll.roll(catalog, "spring", _rng(seed))
		var weather := catalog[result.weather_id] as WeatherData
		assert_that(weather).is_not_null()
		assert_bool(result.yin >= weather.yin_min and result.yin <= weather.yin_max).is_true()
		assert_bool(result.yin >= WeatherRoll.YIN_MIN and result.yin <= WeatherRoll.YIN_MAX).is_true()
		seen[result.weather_id] = true
	assert_bool(seen.has("clear") and seen.has("rain")).is_true()
	assert_bool(seen.has("snow")).is_false()
	var a := WeatherRoll.roll(catalog, "spring", _rng(7))
	var b := WeatherRoll.roll(catalog, "spring", _rng(7))
	assert_str(a.weather_id).is_equal(b.weather_id)
	assert_int(a.yin).is_equal(b.yin)


func test_override_skips_roll_and_unknown_override_falls_back() -> void:
	var catalog := _catalog()
	var forced := WeatherRoll.roll(catalog, "spring", _rng(1), "fog")
	assert_str(forced.weather_id).is_equal("fog")
	assert_bool(forced.yin >= 2 and forced.yin <= 3).is_true()
	var fallback := WeatherRoll.roll(catalog, "spring", _rng(1), "typhoon")
	assert_str(fallback.weather_id).is_not_equal("")
	assert_bool(WeatherRoll.roll({}, "spring", _rng(1)).weather_id.is_empty()).is_true()


func test_yin_threshold_and_guest_multipliers() -> void:
	assert_bool(WeatherRoll.is_yin_high(2, 2)).is_true()
	assert_bool(WeatherRoll.is_yin_high(1, 2)).is_false()
	var fog := _catalog()["fog"] as WeatherData
	var multipliers := WeatherRoll.guest_multipliers(fog, 1.5)
	assert_float(float(multipliers["mortal"])).is_equal_approx(0.4, 0.0001)
	assert_float(float(multipliers["demon"])).is_equal_approx(2.4, 0.0001)
	var none := WeatherRoll.guest_multipliers(null)
	assert_float(float(none["mortal"])).is_equal(1.0)
	assert_float(float(none["demon"])).is_equal(1.0)


func test_visitor_roll_applies_realm_multipliers() -> void:
	var visitors := {"v_guest": _visitor()}
	var species := {"g_mortal": _species("g_mortal", "mortal", 40), "g_demon": _species("g_demon", "demon", 5)}
	# 이승 배율 0 → 마계 손님만 온다
	for seed in 20:
		var visitor := VisitorRoll.roll(visitors, species, _rng(seed), 1.0, "clear", {"mortal": 0.0, "demon": 2.0})
		assert_str(visitor.species_id).is_equal("g_demon")
	# 마계 배율 0 → 이승 손님만
	for seed in 20:
		var visitor := VisitorRoll.roll(visitors, species, _rng(seed), 1.0, "clear", {"mortal": 1.0, "demon": 0.0})
		assert_str(visitor.species_id).is_equal("g_mortal")
	# 둘 다 0 이면 아무도 안 온다
	assert_that(VisitorRoll.roll(visitors, species, _rng(3), 1.0, "clear", {"mortal": 0.0, "demon": 0.0})).is_null()
	# 배율을 비우면 기존 정수 가중치 경로 그대로
	assert_that(VisitorRoll.roll(visitors, species, _rng(3), 1.0, "clear")).is_not_null()


func test_gather_roll_respects_yin_condition_and_falls_back_when_empty() -> void:
	var region := RegionData.new()
	region.id = "r_test"
	region.gather_point_count = 30
	region.gather_pool = ["m_any", "m_high", "m_low"]
	var catalog := {"m_any": _material("m_any", "any"), "m_high": _material("m_high", "high"), "m_low": _material("m_low", "low")}
	var low_day := GatherPoints.roll(region, catalog, _rng(5), false)
	assert_bool(low_day.material_ids.has("m_high")).is_false()
	assert_bool(low_day.material_ids.has("m_low")).is_true()
	var high_day := GatherPoints.roll(region, catalog, _rng(5), true)
	assert_bool(high_day.material_ids.has("m_low")).is_false()
	assert_bool(high_day.material_ids.has("m_high")).is_true()
	# 조건으로 풀이 다 빠지면 조건을 무시해 구역이 비지 않는다
	region.gather_pool = ["m_high"]
	var fallback := GatherPoints.roll(region, catalog, _rng(5), false)
	assert_int(fallback.size()).is_equal(30)
	assert_bool(fallback.material_ids.has("m_high")).is_true()


func test_farm_sow_rejects_out_of_season_crop() -> void:
	var crop := CropData.new()
	crop.id = "c_radish"
	crop.seed_item = "seed_radish"
	crop.harvest_item = "radish"
	crop.season = "spring"
	var farm := Farm.new(1)
	var inventory := Inventory.new()
	inventory.add("seed_radish", 2)
	farm.till(0)
	assert_int(farm.sow(0, crop, inventory, "summer")).is_equal(Farm.Outcome.OUT_OF_SEASON)
	assert_int(inventory.get_count("seed_radish")).is_equal(2)  # 씨앗은 안 쓴다
	assert_bool(Farm.in_season(crop, "")).is_true()
	assert_int(farm.sow(0, crop, inventory, "spring")).is_equal(Farm.Outcome.OK)
	crop.season = "any"
	assert_bool(Farm.in_season(crop, "winter")).is_true()
