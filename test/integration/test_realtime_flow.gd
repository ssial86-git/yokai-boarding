class_name TestRealtimeFlow
extends GdUnitTestSuite
## P1-S3 4항: 실시간 시계가 초 단위로 흐를 때 저녁 정산·심사와 밤 사연이 제때 뜨고,
## 대화·심사가 열린 동안 시간이 멈추며, 시계가 다 흐르면 강제 취침해 다음 날이 되는지 메인 씬에서 확인한다.

const MAIN_SCENE := "res://scenes/main.tscn"
const MAX_SECONDS := 4000


func _drain(story: StorySystem, intake: IntakeSystem) -> void:
	for i in 100:
		if story.is_busy():
			var node := story.current_node()
			if node != null and node.has_options():
				story.choose(0)
			else:
				story.advance()
		elif intake.has_pending():
			intake.decide(Intake.Decision.DECLINE)
		else:
			return


func _advance_until_band(band: int) -> int:
	var seconds := 0
	while Clock.band != band and seconds < MAX_SECONDS:
		Clock.advance_seconds(1.0)
		seconds += 1
	return seconds


func test_evening_and_night_triggers_under_real_time() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	_drain(story, intake)  # 1일차 아침 튜토리얼

	var stats := {"settled": 0, "knocked": 0, "forced": -1}
	var on_settled := func(_summary: Dictionary) -> void: stats["settled"] += 1
	var on_knock := func(_visitor: Dictionary) -> void: stats["knocked"] += 1
	var on_slept := func(_day: int, forced: bool) -> void: stats["forced"] = 1 if forced else 0
	Events.day_settled.connect(on_settled)
	Events.visitor_knocked.connect(on_knock)
	Events.slept.connect(on_slept)

	# 1초씩 흘려 저녁 진입: 정산 1회, 저녁 튜토리얼 대화가 열린다
	_advance_until_band(Clock.Band.EVENING)
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	assert_float(Clock.get_hour()).is_equal_approx(DataRegistry.tuning.get_float("timeband_evening_hour"), 0.05)
	assert_int(stats["settled"]).is_equal(1)
	assert_bool(story.is_busy()).override_failure_message("저녁 진입 시 튜토리얼 대화가 떠야 한다").is_true()
	assert_bool(Clock.is_held()).is_true()

	# 대화가 열린 동안 프레임이 흘러도 시계는 멈춘다
	var before := Clock.elapsed_seconds()
	Clock._process(5.0)
	assert_float(Clock.elapsed_seconds()).is_equal(before)
	_drain(story, intake)  # 튜토리얼 → 심사(있으면 거절) → 남은 대화
	assert_int(stats["knocked"]).is_greater_equal(1)  # 방문자가 없어도 빈 노크는 한 번 온다
	assert_bool(Clock.is_held()).is_false()
	Clock._process(1.0)
	assert_float(Clock.elapsed_seconds()).is_equal_approx(before + 1.0, 0.0001)

	# 밤 진입: 밤 튜토리얼 → 하숙생 사연
	_advance_until_band(Clock.Band.NIGHT)
	assert_int(Clock.band).is_equal(Clock.Band.NIGHT)
	assert_bool(story.is_busy()).is_true()
	assert_str(story.current_event.kind).is_equal("tutorial")
	while story.is_busy() and story.current_event.kind == "tutorial":
		var node := story.current_node()
		if node != null and node.has_options():
			story.choose(0)
		else:
			story.advance()
	assert_bool(story.is_busy()).is_true()
	assert_str(story.current_event.kind).is_equal("story")
	_drain(story, intake)

	# 시계가 다 흐르면 강제 취침 → 2일차 아침
	var seconds := 0
	while GameState.day == 1 and seconds < MAX_SECONDS:
		Clock.advance_seconds(1.0)
		seconds += 1
	assert_int(GameState.day).is_equal(2)
	assert_int(stats["forced"]).is_equal(1)
	assert_int(Clock.band).is_equal(Clock.Band.MORNING)
	assert_float(Clock.elapsed_seconds()).is_less(1.0)
	Events.day_settled.disconnect(on_settled)
	Events.visitor_knocked.disconnect(on_knock)
	Events.slept.disconnect(on_slept)
