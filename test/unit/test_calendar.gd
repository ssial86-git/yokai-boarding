class_name TestCalendar
extends GdUnitTestSuite
## 절기 달력 (P2-S1): 28일이 차면 다음 절기, 통산 일차 → 달력 변환(v5 마이그레이션), 소절기 이벤트 활성·배율, 직렬화.


func _season(id: String, order: int, length: int, next_id: String) -> SeasonData:
	var season := SeasonData.new()
	season.id = id
	season.name_ko = id
	season.order = order
	season.length_days = length
	season.next_id = next_id
	return season


func _catalog() -> Dictionary:
	return {
		"spring": _season("spring", 1, 28, "summer"),
		"summer": _season("summer", 2, 28, "autumn"),
		"autumn": _season("autumn", 3, 28, "winter"),
		"winter": _season("winter", 4, 28, "spring"),
	}


func _event(id: String, season: String, day: int, duration: int, override: String = "", gather := 1.0, demon := 1.0) -> SeasonEventData:
	var event := SeasonEventData.new()
	event.id = id
	event.name_ko = id
	event.season = season
	event.day_of_season = day
	event.duration_days = duration
	event.weather_override = override
	event.gather_multiplier = gather
	event.demon_guest_multiplier = demon
	return event


func _events() -> Dictionary:
	return {
		"se_rain": _event("se_rain", "spring", 10, 2, "rain"),
		"se_moon": _event("se_moon", "spring", 20, 2, "moon_haze", 1.2, 1.5),
		"se_summer": _event("se_summer", "summer", 3, 1),
	}


func test_advance_rolls_season_after_length_and_wraps_year() -> void:
	var calendar := Calendar.start(_catalog(), "spring")
	assert_str(calendar.season_id).is_equal("spring")
	assert_int(calendar.day_of_season).is_equal(1)
	assert_int(calendar.length()).is_equal(28)
	for _i in 27:
		assert_bool(calendar.advance_day()).is_false()
	assert_int(calendar.day_of_season).is_equal(28)
	assert_int(calendar.days_left()).is_equal(0)
	assert_bool(calendar.advance_day()).is_true()
	assert_str(calendar.season_id).is_equal("summer")
	assert_int(calendar.day_of_season).is_equal(1)
	for _i in 28 * 3:
		calendar.advance_day()
	assert_str(calendar.season_id).is_equal("spring")  # 겨울 다음은 다시 봄


func test_unknown_start_falls_back_to_lowest_order() -> void:
	var calendar := Calendar.start(_catalog(), "nope")
	assert_str(calendar.season_id).is_equal("spring")


func test_from_absolute_day_matches_migration_expectation() -> void:
	assert_int(Calendar.from_absolute_day(_catalog(), "spring", 1).day_of_season).is_equal(1)
	var day28 := Calendar.from_absolute_day(_catalog(), "spring", 28)
	assert_str(day28.season_id).is_equal("spring")
	assert_int(day28.day_of_season).is_equal(28)
	var day30 := Calendar.from_absolute_day(_catalog(), "spring", 30)
	assert_str(day30.season_id).is_equal("summer")
	assert_int(day30.day_of_season).is_equal(2)


func test_events_active_window_and_multipliers() -> void:
	var calendar := Calendar.start(_catalog(), "spring")
	var events := _events()
	var in_season := calendar.events_in_season(events)
	assert_int(in_season.size()).is_equal(2)  # 여름 이벤트는 제외
	assert_str(in_season[0].id).is_equal("se_rain")
	assert_array(calendar.events_on(events, 9)).is_empty()
	assert_int(calendar.events_on(events, 10).size()).is_equal(1)
	assert_int(calendar.events_on(events, 11).size()).is_equal(1)
	assert_array(calendar.events_on(events, 12)).is_empty()
	for _i in 19:
		calendar.advance_day()
	assert_int(calendar.day_of_season).is_equal(20)
	assert_str(calendar.weather_override(events)).is_equal("moon_haze")
	assert_float(calendar.gather_multiplier(events)).is_equal_approx(1.2, 0.0001)
	assert_float(calendar.demon_guest_multiplier(events)).is_equal_approx(1.5, 0.0001)
	assert_int(calendar.events_starting_today(events).size()).is_equal(1)
	calendar.advance_day()
	assert_array(calendar.events_starting_today(events)).is_empty()  # 둘째 날은 '시작' 이 아니다
	assert_str(calendar.weather_override(events)).is_equal("moon_haze")
	calendar.advance_day()
	assert_str(calendar.weather_override(events)).is_equal("")
	assert_float(calendar.gather_multiplier(events)).is_equal_approx(1.0, 0.0001)


func test_dict_round_trip_and_rejects_unknown_season() -> void:
	var calendar := Calendar.from_absolute_day(_catalog(), "spring", 12)
	var data := calendar.to_dict()
	data["day_of_season"] = float(data["day_of_season"])  # JSON 왕복 흉내
	var restored := Calendar.new()
	assert_bool(restored.from_dict(data, _catalog())).is_true()
	assert_str(restored.season_id).is_equal("spring")
	assert_int(restored.day_of_season).is_equal(12)
	assert_int(restored.length()).is_equal(28)
	assert_bool(Calendar.new().from_dict({"season": "monsoon", "day_of_season": 1}, _catalog())).is_false()
	var clamped := Calendar.new()
	assert_bool(clamped.from_dict({"season": "spring", "day_of_season": 99}, _catalog())).is_true()
	assert_int(clamped.day_of_season).is_equal(28)
