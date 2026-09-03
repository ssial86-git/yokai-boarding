class_name TestDayTimeline
extends GdUnitTestSuite
## 실시간 하루 타임라인: 경과 초 → 시각·시간대, 경계 통과 보고, 하루 끝 판정.


func _timeline() -> DayTimeline:
	var timeline := DayTimeline.new()
	timeline.day_length_seconds = 720.0
	timeline.start_hour = 6.0
	timeline.end_hour = 24.0
	timeline.band_start_hours = [6.0, 9.0, 17.0, 20.0]
	return timeline


func test_hour_maps_linearly_over_the_day() -> void:
	var timeline := _timeline()
	assert_float(timeline.hour()).is_equal(6.0)
	assert_str(timeline.format_hour()).is_equal("06:00")
	timeline.elapsed_seconds = 360.0
	assert_float(timeline.hour()).is_equal(15.0)
	assert_float(timeline.progress()).is_equal(0.5)
	timeline.elapsed_seconds = 370.0
	assert_str(timeline.format_hour()).is_equal("15:15")
	timeline.elapsed_seconds = 720.0
	assert_str(timeline.format_hour()).is_equal("24:00")
	assert_bool(timeline.is_over()).is_true()


func test_band_follows_hour_boundaries() -> void:
	var timeline := _timeline()
	assert_int(timeline.band()).is_equal(DayTimeline.Band.MORNING)
	# 경계 초로 되돌린 시각은 부동소수 오차가 있어도 그 시간대여야 한다 (advance_to_band 의 전제)
	for band in [DayTimeline.Band.DAY, DayTimeline.Band.EVENING, DayTimeline.Band.NIGHT]:
		timeline.elapsed_seconds = timeline.seconds_for_band(band)
		assert_int(timeline.band()).override_failure_message("band %d 시작 초에서 시간대 불일치" % band).is_equal(band)
	timeline.elapsed_seconds = timeline.seconds_for_hour(16.99)
	assert_int(timeline.band()).is_equal(DayTimeline.Band.DAY)
	assert_float(timeline.seconds_for_band(DayTimeline.Band.EVENING)).is_equal_approx(440.0, 0.001)
	assert_float(timeline.seconds_for_hour(30.0)).is_equal(720.0)


func test_advance_reports_every_crossed_band_in_order() -> void:
	var timeline := _timeline()
	assert_array(timeline.advance(60.0)).is_empty()  # 06:00 → 07:30, 아직 아침
	assert_array(timeline.advance(501.0)).contains_exactly([1, 2, 3])  # 한 번에 낮·저녁·밤을 지나도 전부 보고
	assert_int(timeline.band()).is_equal(DayTimeline.Band.NIGHT)
	assert_array(timeline.advance(1000.0)).is_empty()
	assert_float(timeline.elapsed_seconds).is_equal(720.0)  # 하루 끝을 넘지 않는다
	assert_bool(timeline.is_over()).is_true()
	assert_array(timeline.advance(-5.0)).is_empty()
	timeline.reset()
	assert_float(timeline.elapsed_seconds).is_equal(0.0)
	assert_bool(timeline.is_over()).is_false()


func test_from_tuning_and_band_names() -> void:
	var tuning := TuningData.new()
	tuning.values = {
		"day_length_seconds": 600.0, "clock_start_hour": 7.0, "clock_end_hour": 23.0,
		"timeband_day_hour": 10.0, "timeband_evening_hour": 18.0, "timeband_night_hour": 21.0,
	}
	var timeline := DayTimeline.from_tuning(tuning)
	assert_float(timeline.day_length_seconds).is_equal(600.0)
	assert_array(timeline.band_start_hours).contains_exactly([7.0, 10.0, 18.0, 21.0])
	assert_str(DayTimeline.band_name(DayTimeline.Band.EVENING)).is_equal("evening")
	assert_int(DayTimeline.band_from_name("Night")).is_equal(DayTimeline.Band.NIGHT)
	assert_int(DayTimeline.band_from_name("noon")).is_equal(-1)
