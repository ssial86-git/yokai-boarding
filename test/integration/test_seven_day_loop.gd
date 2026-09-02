class_name TestSevenDayLoop
extends GdUnitTestSuite
## M3 완료 판정: 시드를 고정하고 메인 씬에서 7일을 자동 진행한다.
## 배치 → 낮 → 정산·하숙비 → 심사(받기) → 밤 사연 → 다음 날이 막힘 없이 돌고, 경제·서사·세이브가 이어지는지 확인.

const SEED := 20260902
const DAYS := 7
const TEST_SLOT := 98


func after_test() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _drain_dialogue(story: StorySystem) -> int:
	var steps := 0
	while story.is_busy() and steps < 100:
		var node := story.current_node()
		if node != null and node.has_options():
			story.choose(0)
		else:
			story.advance()
		steps += 1
	return steps


func test_seven_days_close_the_loop() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var house: HouseController = main.get("house_controller")
	var assign: AssignmentController = main.get("assignment_controller")
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	GameState.rng.seed = SEED

	# 람다는 지역 변수를 값으로 잡으므로 참조 타입(Dictionary)에 누적한다
	var stats := {"rent": 0, "dialogues": 0}
	var rent_capture := func(rent: Dictionary) -> void: stats["rent"] += int(rent.get("money", 0))
	Events.rent_settled.connect(rent_capture)
	var dialogue_capture := func(_id: String) -> void: stats["dialogues"] += 1
	Events.dialogue_started.connect(dialogue_capture)

	assert_array(GameState.residents).contains_exactly(["y01_ttukttagi", "y02_eoduki"])
	assert_bool(story.is_busy()).override_failure_message("1일차 아침 튜토리얼이 떠야 한다").is_true()
	_drain_dialogue(story)

	# 1일차 아침: 달갤과 손님을 받을 침대를 미리 늘린다 (객실 2침대 추가)
	assert_int(house.try_place_room(Vector2i(3, 0), "guest_room")).is_equal(RoomGrid.Outcome.OK)
	var accepted := 0
	var declined := 0
	for day in DAYS:
		assert_int(Clock.phase).is_equal(Clock.Phase.MORNING)
		assert_int(GameState.day).is_equal(day + 1)
		_drain_dialogue(story)
		assign.try_assign("y02_eoduki", Vector2i(2, 0))  # 주방
		Clock.advance_phase()  # DAY
		Clock.advance_phase()  # EVENING: 정산 → (튜토리얼) → 심사
		_drain_dialogue(story)
		await runner.simulate_frames(1)
		if intake.has_pending():
			var outcome := intake.decide(Intake.Decision.ACCEPT)
			if outcome == Intake.Outcome.ACCEPTED:
				accepted += 1
			else:
				intake.decide(Intake.Decision.DECLINE)
				declined += 1
		_drain_dialogue(story)
		Clock.advance_phase()  # NIGHT: 사연
		_drain_dialogue(story)
		Clock.advance_phase()  # 다음 날
	Events.rent_settled.disconnect(rent_capture)
	Events.dialogue_started.disconnect(dialogue_capture)

	assert_int(GameState.day).is_equal(DAYS + 1)
	assert_bool(story.is_busy()).is_false()
	assert_bool(intake.has_pending()).is_false()
	# 2일차 저녁 '빈 카드' 로 달갤 입주
	assert_array(GameState.residents).contains("y03_dalgael")
	assert_bool(GameState.flags.has("joined_y03_dalgael")).is_true()
	# 경제: 주방 산출과 하숙비가 들어왔고, 손님이 최소 한 번은 묵어 돈을 냈다
	assert_int(GameState.inventory.get_count("meal")).is_greater(0)
	assert_int(accepted).is_greater(1)
	assert_int(stats["rent"]).is_greater(0)
	assert_int(GameState.ledger.size()).is_greater(0)
	# 서사: 튜토리얼 4개와 각 하숙생 1막 이상 (밤마다 하나씩, 호감도 낮은 순으로 돌아가며)
	for event_id in ["tut_morning", "tut_evening", "tut_night", "tut_arrival", "y01_act1", "y02_act1", "y03_act1"]:
		assert_array(GameState.seen_events).override_failure_message("이벤트 미발생: %s" % event_id).contains([event_id])
	assert_int(stats["dialogues"]).is_greater_equal(7)
	assert_int(GameState.affinity.get("y01_ttukttagi", 0)).is_greater(0)

	# 세이브 왕복
	var expected := SaveManager.build_save_data()
	assert_int(SaveManager.save_slot(TEST_SLOT)).is_equal(OK)
	GameState.reset_new_game()
	assert_int(SaveManager.load_slot(TEST_SLOT)).is_equal(OK)
	assert_dict(SaveManager.build_save_data()).is_equal(expected)
