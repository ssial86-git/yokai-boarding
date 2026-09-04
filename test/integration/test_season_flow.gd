class_name TestSeasonFlow
extends GdUnitTestSuite
## P2-S1 통합: 28일 자동 진행으로 봄이 여름으로 넘어가고, 소절기 이벤트(장마 시작 10~11일 · 만월 20~21일)가 날씨를 고정하며,
## 매일 음기가 0~3 안에서 추첨된다. 음기 짙은 날 판정 → 마계 작물 가속, 비 → 텃밭 물주기, 음기 조건 재료, 손님 배율이 실제 시스템을 지난다.

var _day_cycle: DayCycle
var _farm_system: FarmSystem


func before_test() -> void:
	GameState.reset_new_game()
	_day_cycle = auto_free(DayCycle.new())
	add_child(_day_cycle)
	_farm_system = auto_free(FarmSystem.new())
	add_child(_farm_system)


func after_test() -> void:
	Clock.running = false


func test_28_days_roll_spring_into_summer_with_season_events() -> void:
	var log := {"weather": {}, "yin": {}, "events": [], "seasons": []}
	var on_weather := func(weather: String, yin: int) -> void:
		(log["weather"] as Dictionary)[GameState.day] = weather
		(log["yin"] as Dictionary)[GameState.day] = yin
	var on_event := func(event_id: String) -> void: (log["events"] as Array).append("%d:%s" % [GameState.day, event_id])
	var on_season := func(season_id: String) -> void: (log["seasons"] as Array).append("%d:%s" % [GameState.day, season_id])
	Events.weather_rolled.connect(on_weather)
	Events.season_event_started.connect(on_event)
	Events.season_changed.connect(on_season)

	Clock.start_day()
	assert_str(GameState.calendar.season_id).is_equal("spring")
	for _i in 28:
		Clock.sleep()
	Events.weather_rolled.disconnect(on_weather)
	Events.season_event_started.disconnect(on_event)
	Events.season_changed.disconnect(on_season)

	assert_int(GameState.day).is_equal(29)
	assert_str(GameState.calendar.season_id).is_equal("summer")
	assert_int(GameState.calendar.day_of_season).is_equal(1)
	assert_array(log["seasons"]).contains_exactly(["29:summer"])
	assert_array(log["events"]).contains_exactly(["10:se_rain_start", "20:se_full_moon"])
	for day in [10, 11]:
		assert_str(str((log["weather"] as Dictionary)[day])).override_failure_message("%d일은 장마" % day).is_equal("rain")
	for day in [20, 21]:
		assert_str(str((log["weather"] as Dictionary)[day])).override_failure_message("%d일은 달무리" % day).is_equal("moon_haze")
		assert_int(int((log["yin"] as Dictionary)[day])).is_equal(3)
	for day in range(1, 30):
		var yin := int((log["yin"] as Dictionary)[day])
		assert_bool(yin >= WeatherRoll.YIN_MIN and yin <= WeatherRoll.YIN_MAX).override_failure_message("%d일 음기 %d" % [day, yin]).is_true()
		assert_bool(DataRegistry.weather.has(str((log["weather"] as Dictionary)[day]))).is_true()


## 같은 시드·같은 날이면 같은 날씨 (tuning visitor_seed 가 0 이면 새 게임마다 무작위라 여기서 시드를 고정한다).
## P3-S1: 112일 자동 진행 — 4절기가 돌아 다시 봄, 매일 날씨가 그 절기의 표 안, 소절기 8·명절 3이 제 날에 시작한다.
func test_112_days_cycle_four_seasons_with_events_and_festivals() -> void:
	var festival_system: FestivalSystem = auto_free(FestivalSystem.new())
	add_child(festival_system)
	var log := {"seasons": [], "events": [], "festivals": [], "bad_weather": []}
	var on_season := func(season_id: String) -> void: (log["seasons"] as Array).append(season_id)
	var on_event := func(event_id: String) -> void: (log["events"] as Array).append(event_id)
	var on_festival := func(festival_id: String, _decorated: bool) -> void: (log["festivals"] as Array).append(festival_id)
	var on_weather := func(weather_id: String, _yin: int) -> void:
		var weather := DataRegistry.get_weather(weather_id)
		if weather == null or (weather.season != WeatherRoll.SEASON_ANY and weather.season != GameState.calendar.season_id):
			(log["bad_weather"] as Array).append("%d:%s" % [GameState.day, weather_id])
	Events.season_changed.connect(on_season)
	Events.season_event_started.connect(on_event)
	Events.festival_started.connect(on_festival)
	Events.weather_rolled.connect(on_weather)
	Clock.start_day()
	for _i in 112:
		Clock.sleep()
	Events.season_changed.disconnect(on_season)
	Events.season_event_started.disconnect(on_event)
	Events.festival_started.disconnect(on_festival)
	Events.weather_rolled.disconnect(on_weather)
	assert_int(GameState.day).is_equal(113)
	assert_array(log["seasons"]).contains_exactly(["summer", "autumn", "winter", "spring"])
	assert_str(GameState.calendar.season_id).is_equal("spring")
	assert_int(GameState.calendar.day_of_season).is_equal(1)
	assert_array(log["bad_weather"]).is_empty()
	assert_array(log["events"]).contains_exactly([
		"se_rain_start", "se_full_moon", "se_meteor", "se_heat", "se_typhoon", "se_foliage", "se_first_snow", "se_blizzard"])
	assert_array(log["festivals"]).contains_exactly(["f_dongji", "f_dano", "f_baekjung"])


func test_weather_roll_is_deterministic_per_seed_and_day() -> void:
	GameState.rng.seed = 4242
	Clock.start_day()
	var first := GameState.weather
	var first_yin := GameState.yin
	GameState.reset_new_game()
	GameState.rng.seed = 4242
	Clock.start_day()
	assert_str(GameState.weather).is_equal(first)
	assert_int(GameState.yin).is_equal(first_yin)


func test_yin_high_day_effects_and_rain_waters_farm() -> void:
	GameState.tools["hoe"] = 1
	GameState.inventory.add("seed_moon_melon", 1)
	assert_int(GameState.farm.till(0)).is_equal(Farm.Outcome.OK)
	var melon := DataRegistry.get_crop("c_moon_melon")
	assert_int(GameState.farm.sow(0, melon, GameState.inventory, GameState.calendar.season_id)).is_equal(Farm.Outcome.OK)
	# 비 오는 아침: weather.csv crop_water_bonus 만큼 텃밭이 절로 젖는다
	assert_int(_farm_system.rain_water("clear")).is_equal(0)
	assert_int(_farm_system.rain_water("rain")).is_equal(1)
	assert_float(GameState.farm.get_plot(0).water).is_equal(1.0)
	# 음기 짙은 날: 마계 작물이 yin_growth_bonus(1.0) 만큼 더 자란다
	GameState.yin = 3
	assert_bool(GameState.is_yin_high()).is_true()
	_farm_system.advance_day()
	assert_float(GameState.farm.get_plot(0).growth).is_equal_approx(2.0, 0.0001)
	GameState.yin = 1
	assert_bool(GameState.is_yin_high()).is_false()
	# 음기 조건 재료: 그늘이끼(high)는 짙은 날에만 잿빛 들에 난다
	var region := DataRegistry.get_region("r_ash_field")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var low_day := GatherPoints.roll(region, DataRegistry.materials, rng, false)
	assert_bool(low_day.material_ids.has("m_shadow_moss")).is_false()
	assert_int(low_day.size()).is_equal(region.gather_point_count)
	# 손님 배율: 달무리(이승 0.2 · 마계 2.0) × 만월 1.5
	var multipliers := WeatherRoll.guest_multipliers(DataRegistry.get_weather("moon_haze"), 1.5)
	assert_float(float(multipliers["demon"])).is_equal_approx(3.0, 0.0001)
	assert_float(float(multipliers["mortal"])).is_equal_approx(0.2, 0.0001)
	# 제철: 봄에 무는 심지만 여름 키를 주면 거절
	var radish := DataRegistry.get_crop("c_radish")
	GameState.inventory.add(radish.seed_item, 1)
	assert_int(GameState.farm.till(1)).is_equal(Farm.Outcome.OK)
	assert_int(GameState.farm.sow(1, radish, GameState.inventory, "summer")).is_equal(Farm.Outcome.OUT_OF_SEASON)
	assert_int(GameState.farm.sow(1, radish, GameState.inventory, GameState.calendar.season_id)).is_equal(Farm.Outcome.OK)
