class_name TestDelegation
extends GdUnitTestSuite
## P3-S4 자동화 전환 (메인 씬): 아침 배치의 채집·낚시·판매 위임 슬롯이 해금으로 열리고, 낮에 하숙생이 대신 캐고 낚고 저녁에 팔며,
## 위임 결과가 활동 카운터·지표에 쌓인다. 세이브 왕복에 위임 배치가 남는다.

const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SLOT := 97


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


func after_test() -> void:
	Clock.running = false
	Clock.release(Clock.HOLD_INTAKE)
	Clock.release(Clock.HOLD_DIALOGUE)
	var path := SaveManager.slot_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_delegation_slots_unlock_and_work() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var panel: AssignmentPanel = main.get("assignment_panel")
	var assign: AssignmentController = main.get("assignment_controller")
	var gather: GatherSystem = main.get("gather_system")
	var fishing: FishingSystem = main.get("fishing_system")
	var market: MarketSystem = main.get("market_system")
	_drain(main.get("story_system"), main.get("intake_system"))
	# 해금 전엔 위임 줄이 숨어 있다
	assert_int(panel.open_delegation_zones()).is_equal(0)
	for unlock_id in ["u_back_hill", "u_fishing", "u_rod", "u_delegate_gather", "u_delegate_fishing", "u_delegate_market"]:
		GameState.unlocked[unlock_id] = GameState.day
	GameState.tools["rod"] = 1
	Events.unlocked.emit("u_delegate_market")
	assert_int(panel.open_delegation_zones()).is_equal(3)
	# 아침 배치: 뚝딱이 → 채집, 어둑이 → 낚시 (정원 1씩)
	assert_int(assign.try_assign("y01_ttukttagi", Assignment.GATHER)).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y02_eoduki", Assignment.GATHER)).is_not_equal(AssignmentController.Outcome.OK)  # 정원 1
	assert_int(assign.try_assign("y02_eoduki", Assignment.FISHING)).is_equal(AssignmentController.Outcome.OK)
	assert_that(GameState.assignment.get_cell("y01_ttukttagi")).is_equal(Assignment.GATHER)
	# 낮: 채집 위임은 뒷산 남은 포인트 × 효율 만큼 캐 온다 (8 × 0.6 → 4, 도구 필요 재료는 건너뛴다)
	var before := GameState.inventory.items().size()
	var gathered := gather.auto_gather()
	assert_int(gathered).is_between(1, 4)
	assert_int(gather.points_for("r_back_hill").remaining()).is_equal(8 - gathered)
	assert_int(int(GameState.counters.get("gather", 0))).is_equal(gathered)
	assert_bool(GameState.inventory.items().size() >= before).is_true()
	# 낚시 위임: 두 번 던져 효율 확률로 낚는다 (시드 고정 없이 0~2)
	var caught := fishing.auto_fish()
	assert_int(caught).is_between(0, 2)
	assert_int(int(GameState.counters.get("fish", 0))).is_equal(caught)
	# 판매 위임: 물고기·수확물을 종류별 3개만 남기고 대문간 값 × 효율로 판다
	assert_int(assign.try_assign("y01_ttukttagi", Assignment.MARKET)).is_equal(AssignmentController.Outcome.OK)
	GameState.inventory.clear()  # 위에서 캐고 낚은 것과 섞이지 않게
	GameState.inventory.add("radish", 5)
	GameState.inventory.add("f_minnow", 4)
	GameState.inventory.add("m_stone", 9)  # 재료는 팔지 않는다
	var money := GameState.money
	var earned := market.auto_sell()
	assert_int(earned).is_greater(0)
	assert_int(GameState.money).is_equal(money + earned)
	assert_int(GameState.inventory.get_count("radish")).is_equal(3)
	assert_int(GameState.inventory.get_count("f_minnow")).is_equal(3)
	assert_int(GameState.inventory.get_count("m_stone")).is_equal(9)
	var radish_price := int(floor(market.gate_price("radish") * 0.6 + 0.5))
	var minnow_price := int(floor(market.gate_price("f_minnow") * 0.6 + 0.5))
	assert_int(earned).is_equal(radish_price * 2 + minnow_price * 1)
	assert_int(Metrics.count("delegation")).is_greater_equal(3)
	# 세이브 왕복에 위임 배치가 남는다
	assert_int(SaveManager.save_slot(TEST_SLOT)).is_equal(OK)
	assign.try_rest("y02_eoduki")
	assert_int(SaveManager.load_slot(TEST_SLOT)).is_equal(OK)
	assert_that(GameState.assignment.get_cell("y02_eoduki")).is_equal(Assignment.FISHING)
	assert_that(GameState.assignment.get_cell("y01_ttukttagi")).is_equal(Assignment.MARKET)


func test_chapter_two_gate_and_epilogue_data() -> void:
	var c2 := DataRegistry.get_chapter("c2")
	assert_int(c2.gate_goals.size()).is_equal(4)
	assert_int(c2.gate_required).is_equal(2)
	assert_str(c2.next_id).is_equal("c3")
	var epilogue := DataRegistry.get_event("y01_epilogue")
	assert_str(epilogue.kind).is_equal("epilogue")
	assert_int(epilogue.min_affinity).is_equal(5)
	assert_str(epilogue.requires_flag).is_equal("chapter_c3")
	assert_bool(DataRegistry.story_event_ids("y01_ttukttagi").has("y01_epilogue")).is_false()  # 사연 3막 수에 섞이지 않는다
