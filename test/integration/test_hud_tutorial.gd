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
	Clock.advance_to_band(Clock.Band.DAY)
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_FIRST_DAY)).is_true()
	assert_str(tutorial.current_hint.id).is_equal("hint_day")


## 1일차 밤: 튜토리얼을 넘기면 하숙생 사연이 곧바로 이어져야 한다 (검증 에이전트가 잡은 회귀: 튜토리얼만 뜨고 끝남).
func test_story_follows_tutorial_on_first_night() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	_drain(story)
	Clock.advance_to_band(Clock.Band.DAY)
	Clock.advance_to_band(Clock.Band.EVENING)
	_drain(story)
	if intake.has_pending():
		intake.decide(Intake.Decision.DECLINE)
	_drain(story)
	Clock.advance_to_band(Clock.Band.NIGHT)
	assert_bool(story.is_busy()).is_true()
	assert_str(story.current_event.kind).is_equal("tutorial")
	while story.is_busy() and story.current_event.kind == "tutorial":
		var node := story.current_node()
		if node != null and node.has_options():
			story.choose(0)
		else:
			story.advance()
	assert_bool(story.is_busy()).override_failure_message("튜토리얼 뒤에 사연이 이어지지 않았다").is_true()
	assert_str(story.current_event.kind).is_equal("story")
	_drain(story)
	assert_bool(story.is_busy()).is_false()  # 사연은 하루 하나만


## 받은 손님은 배치 대상이 아니지만 패널에 카드(정보)로 보여야 한다 — 사용자가 "카드가 안 나온다" 고 보고한 회귀.
func test_accepted_guest_gets_a_card_and_an_actor() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var panel: AssignmentPanel = main.get("assignment_panel")
	var manager: YokaiManager = main.get("yokai_manager")
	var house: HouseController = main.get("house_controller")
	var story: StorySystem = main.get("story_system")
	_drain(story)
	GameState.money = 1000
	assert_int(house.try_place_room(Vector2i(3, 0), "guest_room")).is_equal(RoomGrid.Outcome.OK)
	var before := panel.card_count()
	var visitor := VisitorRoll.Visitor.new()
	visitor.visitor_id = "v_guest"
	visitor.kind = "guest"
	visitor.species_id = "g_mongdanggwi"
	GameState.pending_visitor = visitor.to_dict()
	var intake: IntakeSystem = main.get("intake_system")
	assert_int(intake.decide(Intake.Decision.ACCEPT)).is_equal(Intake.Outcome.ACCEPTED)
	await runner.simulate_frames(1)
	assert_int(GameState.guests.size()).is_equal(1)
	assert_int(panel.card_count()).is_equal(before + 1)
	assert_int(panel.guest_card_count()).is_equal(1)
	assert_int(manager.actor_count()).is_equal(GameState.residents.size() + 1)


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
