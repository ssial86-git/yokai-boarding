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

	# P1-S2: 첫 안내는 조작법. 마당에 한 번 나갔다 오면(first_region_change) 배치 안내로 넘어간다
	assert_object(tutorial.current_hint).is_not_null()
	assert_str(tutorial.current_hint.id).is_equal("hint_move")
	var region_manager: RegionManager = main.get("region_manager")
	assert_bool(region_manager.travel("r_yard")).is_true()
	assert_bool(region_manager.travel(HouseRegion.REGION_ID)).is_true()
	assert_bool(GameState.flags.has(TutorialSystem.FLAG_FIRST_REGION_CHANGE)).is_true()
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


## ESC(ui_cancel) 는 열린 메뉴(건설·명부·하숙부·디버그)를 닫는다. 디버그 오버레이의 시간 건너뛰기도 확인.
func test_escape_closes_menus_and_debug_time_skip() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var story: StorySystem = main.get("story_system")
	_drain(story)
	var build_menu: BuildMenu = main.get("build_menu")
	var hud: Hud = main.get("hud")
	build_menu.open_for_cell(Vector2i(3, 0), Vector2(100, 100))
	assert_bool(build_menu.is_open()).is_true()
	runner.simulate_action_pressed("ui_cancel")
	await runner.simulate_frames(1)
	runner.simulate_action_release("ui_cancel")
	await runner.simulate_frames(1)
	assert_bool(build_menu.is_open()).override_failure_message("ESC 로 건설 메뉴가 닫히지 않았다").is_false()
	# 장부 탭 메뉴 (UI 정리): Tab 하나로 창고·하숙부·명부. 창고 탭은 종류별 소제목 + 행, ESC 로 닫힌다
	var hub: MenuHub = main.get("menu_hub")
	GameState.inventory.add("m_namul", 2)
	GameState.inventory.add("dish_kimchi", 1)
	hub.open_tab(MenuHub.Tab.INVENTORY)
	assert_bool(hub.is_open()).is_true()
	assert_int(hub.row_count()).is_greater_equal(4)  # 소제목 2 + 행 2 + 시작 씨앗
	hub.open_tab(MenuHub.Tab.ROSTER)
	assert_int(hub.row_count()).is_equal(GameState.residents.size())
	hub.open_tab(MenuHub.Tab.LEDGER)
	assert_int(hub.row_count()).is_equal(1)  # 명부 비어 있음 안내
	runner.simulate_action_pressed("ui_cancel")
	await runner.simulate_frames(1)
	runner.simulate_action_release("ui_cancel")
	await runner.simulate_frames(1)
	assert_bool(hub.is_open()).override_failure_message("ESC 로 장부 메뉴가 닫히지 않았다").is_false()
	hub.toggle()
	assert_bool(hub.is_open()).is_true()
	hub.toggle()
	assert_bool(hub.is_open()).is_false()
	# 배치 패널 접기
	var panel: AssignmentPanel = main.get("assignment_panel")
	panel.toggle_collapsed()
	assert_bool(panel.collapsed).is_true()
	panel.toggle_collapsed()
	assert_bool(panel.collapsed).is_false()

	var overlay := DebugOverlay.new()
	main.add_child(overlay)
	await runner.simulate_frames(1)
	assert_int(Clock.band).is_equal(Clock.Band.MORNING)
	overlay.skip_hour()
	assert_float(Clock.get_hour()).is_equal_approx(7.0, 0.01)
	overlay.skip_to_band(Clock.Band.EVENING)
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	_drain(story)
	var intake: IntakeSystem = main.get("intake_system")
	if intake.has_pending():
		intake.decide(Intake.Decision.DECLINE)
	_drain(story)
	overlay.skip_to_band(Clock.Band.DAY)  # 이미 지난 시간대 → 취침 후 다음 날 낮
	_drain(story)
	assert_int(GameState.day).is_equal(2)
	assert_int(Clock.band).is_equal(Clock.Band.DAY)


func test_message_log_and_clarity_react_to_events() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var log: MessageLog = main.get("message_log")
	var manager: YokaiManager = main.get("yokai_manager")
	var audio: AudioSystem = main.get("audio_system")
	var story: StorySystem = main.get("story_system")
	_drain(story)

	# 토스트 더미는 줄 수·높이 상한이 있어(오래된 줄부터 지움) 개수 대신 "새 줄이 맨 아래에 붙었는가" 를 본다
	Events.message_posted.emit("테스트 메시지")
	assert_int(log.line_count()).is_between(1, DataRegistry.tuning.get_int("message_log_lines"))
	var newest := log.get_child(log.get_child_count() - 1) as Control
	assert_str((newest.get_child(0) as Label).text).is_equal("테스트 메시지")

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
