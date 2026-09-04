class_name TestRosterP3
extends GdUnitTestSuite
## P3-S3 통합 (메인 씬): 도착 하숙생(바리 30일)이 빈 카드 심사로 입주하고 사연 3막이 호감도 순으로 열린다,
## 종족 해금(species 행)이 심사 추첨을 가르고, 방 해금(room 행)이 건설 메뉴를 가르며, 하루 두 번 가호 기능.

const MAIN_SCENE := "res://scenes/main.tscn"


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


func test_bari_arrives_on_day_30_and_story_acts_open_by_affinity() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	var house: HouseController = main.get("house_controller")
	_drain(story, intake)
	GameState.money = 5000
	assert_int(house.try_place_room(Vector2i(3, 0), "guest_room")).is_equal(RoomGrid.Outcome.OK)
	GameState.day = 30
	assert_bool(GameState.calendar.from_dict({"season": "summer", "day_of_season": 2}, DataRegistry.seasons)).is_true()
	intake.roll_visitor()
	assert_str(str(GameState.pending_visitor.get("kind"))).is_equal(Intake.KIND_ERASED)
	assert_str(str(GameState.pending_visitor.get("yokai_id"))).is_equal("y04_bari")
	assert_int(intake.decide(Intake.Decision.ACCEPT)).is_equal(Intake.Outcome.ACCEPTED)
	assert_bool(GameState.residents.has("y04_bari")).is_true()
	assert_array(DataRegistry.story_event_ids("y04_bari")).contains_exactly(["y04_act1", "y04_act2", "y04_act3"])
	var ids := func(ctx: EventScheduler.Context) -> Array[String]:
		var result: Array[String] = []
		for event in EventScheduler.eligible(DataRegistry.events, ctx):
			result.append(event.id)
		return result
	var night: Array[String] = ids.call(story.build_context(Clock.Band.NIGHT))
	assert_bool(night.has("y04_act1")).is_true()
	assert_bool(night.has("y04_act3")).is_false()  # 호감도 2 필요
	GameState.affinity["y04_bari"] = 2
	GameState.seen_events.append("y04_act1")
	GameState.seen_events.append("y04_act2")
	night = ids.call(story.build_context(Clock.Band.NIGHT))
	assert_bool(night.has("y04_act3")).is_true()
	# 모든 장기 하숙생에 사연 3막·가호 1개가 있다
	for yokai_id in DataRegistry.slice_yokai_ids():
		assert_int(DataRegistry.story_event_ids(yokai_id).size()).override_failure_message("%s 사연 수" % yokai_id).is_equal(3)
		assert_that(DataRegistry.blessing_of_yokai(yokai_id)).override_failure_message("%s 가호" % yokai_id).is_not_null()


func test_species_and_room_unlock_gates_and_double_blessing() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var intake: IntakeSystem = main.get("intake_system")
	var blessing: BlessingSystem = main.get("blessing_system")
	var unlock_system: UnlockSystem = main.get("unlock_system")
	_drain(main.get("story_system"), intake)
	# 종족 해금: 돌미륵은 u_species_stone_mireuk 이 열려야 추첨에 든다, 몽당귀는 가리키는 행이 없어 늘 든다
	var species := intake.open_species()
	assert_bool(species.has("g_mongdanggwi")).is_true()
	assert_bool(species.has("g_stone_mireuk")).is_false()
	GameState.unlocked["u_species_stone_mireuk"] = GameState.day
	assert_bool(intake.open_species().has("g_stone_mireuk")).is_true()
	# 방 해금: 온돌방·서고는 room 행이 열려야
	assert_bool(unlock_system.is_target_open("room", "ondol_room")).is_false()
	assert_bool(unlock_system.is_target_open("room", "guest_room")).is_true()
	GameState.unlocked["u_room_ondol"] = GameState.day
	assert_bool(unlock_system.is_target_open("room", "ondol_room")).is_true()
	assert_int(DataRegistry.get_room("ondol_room").capacity).is_equal(3)
	# 하루 두 번 가호
	assert_int(blessing.per_day()).is_equal(1)
	GameState.unlocked["u_second_blessing"] = GameState.day
	assert_int(blessing.per_day()).is_equal(2)
	# 승격 대상 3종 (금줄이·옹기귀·달토끼)
	var promotable := 0
	for data: GuestSpeciesData in DataRegistry.guest_species.values():
		if data.promotable and not data.promotes_to.is_empty():
			promotable += 1
	assert_int(promotable).is_equal(3)
