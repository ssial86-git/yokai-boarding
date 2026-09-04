class_name TestChapterNight
extends GdUnitTestSuite
## P2-S4 통합 (메인 씬): 밤에 뒷산 문을 지나면 밤 변형(적·달빛 이슬)이 조립되고 아침엔 기본 뒷산으로 돌아온다,
## 뜨내기 승격(방문 2·평판 5 → 아침 예고 → 저녁 장기 계약 카드 → 받기 → 하숙생 + 1막 사연), 챕터 1 게이트(4 중 2) → 챕터 2·결계 이벤트.

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


func test_night_back_hill_variant_assembles_and_reverts_by_day() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var expedition: ExpeditionSystem = main.get("expedition_system")
	var gather: GatherSystem = main.get("gather_system")
	_drain(main.get("story_system"), main.get("intake_system"))
	for unlock_id in ["u_back_hill", "u_night_hill"]:
		GameState.unlocked[unlock_id] = GameState.day
	# 낮: 기본 뒷산
	assert_str(region_manager.resolve_variant("r_back_hill")).is_equal("r_back_hill")
	assert_bool(region_manager.travel("r_back_hill")).is_true()
	assert_str(GameState.player_region).is_equal("r_back_hill")
	assert_int(expedition.enemies.size()).is_equal(0)
	# 밤: 변형으로 조립 — 탐험지 규칙(적 2), 밤 풀에서만 뽑힌 채집 포인트
	Clock.restore(Clock.timeline.seconds_for_band(Clock.Band.NIGHT))
	_drain(main.get("story_system"), main.get("intake_system"))
	assert_str(region_manager.resolve_variant("r_back_hill")).is_equal("r_back_hill@night")
	assert_bool(region_manager.travel("r_back_hill")).is_true()
	await runner.simulate_frames(2)
	assert_str(GameState.player_region).is_equal("r_back_hill@night")
	assert_bool(expedition.is_active()).is_true()
	assert_int(expedition.enemies.size()).is_equal(2)
	var points := gather.points_for("r_back_hill@night")
	assert_int(points.size()).is_equal(8)
	var night_pool: Array = DataRegistry.get_region("r_back_hill@night").gather_pool
	for index in points.size():
		assert_bool(night_pool.has(points.material_at(index))).override_failure_message("밤 풀 밖 재료 %s" % points.material_at(index)).is_true()
	assert_bool(GameState.region_states.has("r_back_hill@night")).is_true()
	# 해금이 없으면 밤에도 기본 뒷산
	GameState.unlocked.erase("u_night_hill")
	assert_str(region_manager.resolve_variant("r_back_hill")).is_equal("r_back_hill")
	GameState.unlocked["u_night_hill"] = GameState.day
	# 아침이 오면 변형 상태는 비워지고(다시 뽑기) 문은 기본 뒷산으로 이어진다
	assert_bool(region_manager.travel("r_yard")).is_true()
	Clock.sleep()
	_drain(main.get("story_system"), main.get("intake_system"))
	assert_array(GameState.region_state("r_back_hill@night")["gather_materials"]).is_empty()
	assert_str(region_manager.resolve_variant("r_back_hill@night")).is_equal("r_back_hill")


func test_promotion_and_chapter_gate() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	var promotion: PromotionSystem = main.get("promotion_system")
	var chapter_system: ChapterSystem = main.get("chapter_system")
	var house: HouseController = main.get("house_controller")
	_drain(story, intake)
	assert_str(GameState.chapter_id).is_equal("c1")
	assert_that(chapter_system.gate_progress(chapter_system.current())).is_equal(Vector2i(0, 4))

	# 승격 조건: 금줄이 방문 2 · 평판 5 · 해금
	GameState.unlocked["u_promotion"] = GameState.day
	GameState.ledger["g_geumjuri"] = 2
	GameState.reputation = 5
	GameState.money = 5000
	assert_int(house.try_place_room(Vector2i(3, 0), "guest_room")).is_equal(RoomGrid.Outcome.OK)  # 빈 침대
	assert_str(promotion.offer_today()).is_equal("y05_geumjuri")
	assert_str(str(GameState.flags.get(PromotionSystem.FLAG_PENDING, ""))).is_equal("y05_geumjuri")
	assert_str(promotion.offer_today()).is_equal("")  # 하루 한 번
	intake.roll_visitor()
	assert_str(str(GameState.pending_visitor.get("kind"))).is_equal(Intake.KIND_PROMOTION)
	assert_str(str(GameState.pending_visitor.get("species_id"))).is_equal("g_geumjuri")
	assert_bool(GameState.flags.has(PromotionSystem.FLAG_PENDING)).is_false()
	assert_int(intake.decide(Intake.Decision.ACCEPT)).is_equal(Intake.Outcome.ACCEPTED)
	assert_bool(GameState.residents.has("y05_geumjuri")).is_true()
	assert_int(GameState.residents.size()).is_equal(3)
	assert_bool(GameState.flags.has("joined_y05_geumjuri")).is_true()
	assert_str(promotion.offer_today()).is_equal("")  # 이미 입주 → 다시 청하지 않는다
	# 승격 뒤 1막 사연이 밤에 열린다
	var ctx := story.build_context(Clock.Band.NIGHT)
	var ids: Array[String] = []
	for event in EventScheduler.eligible(DataRegistry.events, ctx):
		ids.append(event.id)
	assert_bool(ids.has("y05_act1")).is_true()

	# 챕터 1 게이트: 하숙생 셋(방금 충족) + 회색 장꾼 인사 → 4 중 2 → 챕터 2, flag chapter_c2, 결계 이벤트 열림
	var goal_system: GoalSystem = main.get("goal_system")
	goal_system.evaluate()
	assert_bool(goal_system.is_done("g_c1_residents")).is_true()
	assert_str(GameState.chapter_id).is_equal("c1")  # 아직 1개
	GameState.flags["merchant_met"] = true
	goal_system.evaluate()
	assert_bool(goal_system.is_done("g_c1_market")).is_true()
	assert_str(GameState.chapter_id).is_equal("c2")
	assert_bool(GameState.flags.has("chapter_c2")).is_true()
	var night_ids: Array[String] = []
	for event in EventScheduler.eligible(DataRegistry.events, story.build_context(Clock.Band.NIGHT)):
		night_ids.append(event.id)
	assert_bool(night_ids.has("c1_e8_ward")).is_true()
	assert_bool(chapter_system.evaluate()).is_false()  # 마지막 챕터는 더 넘어가지 않는다
	# NPC 대화(회색 장꾼)는 시간대 트리거로 뜨지 않는다
	assert_bool(night_ids.has("ev_merchant_greet")).is_false()
