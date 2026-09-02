class_name TestHudTutorial
extends GdUnitTestSuite
## M4: 안내 문구가 상황에 따라 바뀌고, 메시지 로그·효과음·또렷함 연출이 이벤트에 반응하는지 메인 씬에서 확인한다.


func _drain(story: StorySystem) -> void:
	for i in 100:
		if not story.is_busy():
			return
		var node := story.current_node()
		if node != null and node.has_options():
			story.choose(0)
		else:
			story.advance()


func test_hints_follow_first_actions() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var tutorial: TutorialSystem = main.get("tutorial_system")
	var assign: AssignmentController = main.get("assignment_controller")
	var house: HouseController = main.get("house_controller")
	var story: StorySystem = main.get("story_system")
	_drain(story)

	assert_object(tutorial.current_hint).is_not_null()
	assert_str(tutorial.current_hint.id).is_equal("hint_assign")
	assert_int(assign.try_assign("y02_eoduki", Vector2i(2, 0))).is_equal(AssignmentController.Outcome.OK)
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_FIRST_ASSIGNMENT)).is_true()
	assert_str(tutorial.current_hint.id).is_equal("hint_start_day")
	GameState.money = 1000
	assert_int(house.try_place_room(Vector2i(3, 0), "guest_room")).is_equal(RoomGrid.Outcome.OK)
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_FIRST_BUILD)).is_true()
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_EXTRA_BED)).is_true()
	Clock.advance_phase()  # DAY
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_FIRST_DAY)).is_true()
	assert_str(tutorial.current_hint.id).is_equal("hint_day")


func test_message_log_and_clarity_react_to_events() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var log: MessageLog = main.get("message_log")
	var manager: YokaiManager = main.get("yokai_manager")
	var audio: AudioSystem = main.get("audio_system")
	var story: StorySystem = main.get("story_system")
	_drain(story)

	var before := log.line_count()
	Events.message_posted.emit("테스트 메시지")
	assert_int(log.line_count()).is_equal(before + 1)

	# 어둑이는 호감도 0 에서 흐리고, 호감도가 오르면 또렷해진다
	var eoduki := manager.get_actor("y02_eoduki")
	var alpha_min := DataRegistry.tuning.get_float("clarity_alpha_min")
	assert_float(eoduki.get_clarity()).is_equal_approx(alpha_min, 0.001)
	GameState.add_affinity("y02_eoduki", DataRegistry.tuning.get_int("clarity_affinity_max"))
	assert_float(eoduki.get_clarity()).is_equal_approx(1.0, 0.001)
	assert_float(manager.get_actor("y01_ttukttagi").get_clarity()).is_equal_approx(1.0, 0.001)

	# 효과음 항목이 전부 로드됐고, 이벤트가 재생을 건드려도 headless 에서 오류가 없다
	for sfx_id in DataRegistry.sfx:
		audio.play(sfx_id)
	Events.room_changed.emit(Vector2i(3, 0), "kitchen")
	await runner.simulate_frames(1)
