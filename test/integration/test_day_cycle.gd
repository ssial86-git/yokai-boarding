class_name TestDayCycle
extends GdUnitTestSuite
## M2 완료 판정: 3명 배치 → 낮 자동 진행(요괴 이동·일) → 저녁 정산까지 메인 씬에서 통째로 돈다.

const MAX_WALK_FRAMES := 900


func test_assign_three_then_settle() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var house: HouseController = main.get("house_controller")
	var assign: AssignmentController = main.get("assignment_controller")
	var manager: YokaiManager = main.get("yokai_manager")

	# M3 부터 달갤은 2일차 저녁 심사로 입주하므로 새 게임은 2명. 여기서는 바로 입주시켜 3명 배치를 검증한다.
	assert_array(GameState.residents).contains_exactly(["y01_ttukttagi", "y02_eoduki"])
	GameState.add_resident("y03_dalgael")
	await runner.simulate_frames(1)
	assert_int(manager.actor_count()).is_equal(3)
	assert_int(Clock.band).is_equal(Clock.Band.MORNING)

	GameState.money = 10_000
	assert_int(house.try_place_room(Vector2i(3, 0), "workshop")).is_equal(RoomGrid.Outcome.OK)
	assert_int(assign.try_assign("y01_ttukttagi", Vector2i(3, 0))).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y02_eoduki", Vector2i(2, 0))).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y03_dalgael", Vector2i(2, 0))).is_equal(AssignmentController.Outcome.FULL)
	assert_int(assign.try_assign("y03_dalgael", Vector2i(1, 0))).is_equal(AssignmentController.Outcome.NOT_WORKPLACE)
	assert_int(assign.try_assign("nobody", Vector2i(2, 0))).is_equal(AssignmentController.Outcome.UNKNOWN_YOKAI)

	# 낮: 뚝딱이가 작업장까지 걸어가서 일한다
	Clock.advance_to_band(Clock.Band.DAY)
	assert_int(Clock.band).is_equal(Clock.Band.DAY)
	var worker := manager.get_actor("y01_ttukttagi")
	assert_that(worker.target_cell).is_equal(Vector2i(3, 0))
	assert_int(worker.state).is_equal(YokaiActor.State.WALKING)
	for i in MAX_WALK_FRAMES:
		await runner.simulate_frames(1)
		if worker.state == YokaiActor.State.WORKING:
			break
	assert_int(worker.state).is_equal(YokaiActor.State.WORKING)
	assert_that(worker.current_cell).is_equal(Vector2i(3, 0))
	assert_int(manager.get_actor("y03_dalgael").state).is_equal(YokaiActor.State.RESTING)
	assert_int(assign.try_assign("y03_dalgael", Vector2i(3, 0))).is_equal(AssignmentController.Outcome.NOT_MORNING)

	# 저녁: 정산 — 작업장 1×1.25→1 잡동사니, 주방 2 밥. 일한 둘은 컨디션 -30, 쉰 달갤은 상한 유지.
	# 하숙비: 뚝딱이 재료 1개(무작위), 어둑이 심부름(모두 컨디션 +10) — 이 값은 컨디션에 더해진다.
	var summaries: Array[Dictionary] = []
	var capture := func(summary: Dictionary) -> void: summaries.append(summary)
	Events.day_settled.connect(capture)
	Clock.advance_to_band(Clock.Band.EVENING)
	Events.day_settled.disconnect(capture)
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	assert_int(summaries.size()).is_equal(1)
	assert_dict(summaries[0].get("totals", {})).is_equal({"trinket": 1, "meal": 2})
	assert_int(GameState.inventory.get_count("trinket")).is_greater_equal(1)
	assert_int(GameState.inventory.get_count("meal")).is_equal(2)
	var errand_bonus := DataRegistry.get_yokai("y02_eoduki").rent_amount
	assert_int(GameState.get_condition("y01_ttukttagi")).is_equal(70 + errand_bonus)
	assert_int(GameState.get_condition("y02_eoduki")).is_equal(70 + errand_bonus)
	assert_int(GameState.get_condition("y03_dalgael")).is_equal(100)

	# 저녁 심사·튜토리얼·밤 사연은 이 테스트의 관심사가 아니므로 대기 중인 것을 정리한다
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	_drain(story, intake)
	# 밤 → 취침 → 다음 날 아침: 날짜가 넘어가고 배치는 유지된다
	Clock.advance_to_band(Clock.Band.NIGHT)
	_drain(story, intake)
	Clock.sleep()
	_drain(story, intake)
	assert_int(GameState.day).is_equal(2)
	assert_int(Clock.band).is_equal(Clock.Band.MORNING)
	assert_that(GameState.assignment.get_cell("y01_ttukttagi")).is_equal(Vector2i(3, 0))


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


func test_demolished_workplace_resets_assignment() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var house: HouseController = main.get("house_controller")
	var assign: AssignmentController = main.get("assignment_controller")
	assert_int(assign.try_assign("y02_eoduki", Vector2i(2, 0))).is_equal(AssignmentController.Outcome.OK)
	assert_int(house.try_demolish(Vector2i(2, 0))).is_equal(RoomGrid.Outcome.OK)
	assert_bool(GameState.assignment.is_resting("y02_eoduki")).is_true()
