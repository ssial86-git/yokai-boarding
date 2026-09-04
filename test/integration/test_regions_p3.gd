class_name TestRegionsP3
extends GdUnitTestSuite
## P3-S2 통합 (메인 씬): 마을 상점가(낮만 개장, NPC 2·상점 2·마을 씨앗 값), 달무리 늪(회색 시장 너머, 적 3+늪어미, 낚시 자리, 밤 변형),
## 문서고 외곽(잿빛 들 심부 너머, 적 4+집행관). 상점별 재고가 따로 산다.

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


func test_village_opens_by_day_with_two_shops() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var market_system: MarketSystem = main.get("market_system")
	_drain(main.get("story_system"), main.get("intake_system"))
	GameState.unlocked["u_village"] = GameState.day
	Clock.restore(Clock.timeline.seconds_for_band(Clock.Band.NIGHT))
	_drain(main.get("story_system"), main.get("intake_system"))
	assert_bool(region_manager.is_region_open("r_village")).is_false()  # 밤에는 닫힘
	Clock.restore(Clock.timeline.seconds_for_band(Clock.Band.DAY))
	assert_bool(region_manager.is_region_open("r_village")).is_true()
	assert_bool(region_manager.travel("r_yard")).is_true()
	assert_bool(region_manager.travel("r_village")).is_true()
	await runner.simulate_frames(1)
	var view := region_manager.current_view()
	assert_that(view.get_node_or_null("Npc_village_grocer")).is_not_null()
	assert_that(view.get_node_or_null("Npc_herb_granny")).is_not_null()
	# 마을 씨앗은 회색 시장보다 싸고(×1.5 vs ×2.0), 재고는 상점마다 따로
	GameState.money = 1000
	var village_price := market_system.buy_price("seed_cabbage", "village")
	var gray_price := market_system.buy_price("seed_cabbage", "gray")
	assert_int(village_price).is_between(5, 7)
	assert_int(gray_price).is_greater(village_price)
	assert_int(market_system.buy("seed_cabbage", "village")).is_equal(village_price)
	assert_int(market_system.stock_left("seed_cabbage", "village")).is_equal(2)
	assert_int(market_system.stock_left("seed_cabbage", "gray")).is_equal(3)
	# 약방은 약초를 사고 팔며, 잡화상엔 약초 행이 없어 대문간 값 그대로
	GameState.inventory.add("m_herb", 2)
	assert_int(market_system.sell_price("m_herb", "apothecary")).is_greater(market_system.gate_price("m_herb"))
	assert_int(market_system.sell_price("m_herb", "village")).is_equal(market_system.gate_price("m_herb"))
	assert_int(market_system.buy_price("m_herb", "apothecary")).is_greater(0)
	assert_int(market_system.buy_price("m_herb", "village")).is_equal(0)
	# 첫 인사 플래그 규칙: <npc>_met 이 없으면 인사 대화 이벤트가 있다
	assert_that(DataRegistry.get_event("ev_village_grocer_greet")).is_not_null()
	assert_that(DataRegistry.get_event("ev_herb_granny_greet")).is_not_null()


func test_moon_marsh_and_archive_gate_assemble_with_bosses() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var expedition: ExpeditionSystem = main.get("expedition_system")
	var fishing: FishingSystem = main.get("fishing_system")
	_drain(main.get("story_system"), main.get("intake_system"))
	for unlock_id in ["u_well", "u_gray_market", "u_moon_marsh", "u_ash_field", "u_ash_field_deep", "u_archive_gate", "u_night_marsh"]:
		GameState.unlocked[unlock_id] = GameState.day
	GameState.yin = 3  # 회색 시장 개장
	assert_bool(region_manager.travel("r_well")).is_true()
	assert_bool(region_manager.travel("r_gray_market")).is_true()
	assert_bool(region_manager.travel("r_moon_marsh")).is_true()
	await runner.simulate_frames(2)
	assert_str(GameState.player_region).is_equal("r_moon_marsh")
	assert_bool(expedition.is_active()).is_true()
	assert_int(expedition.enemies.size()).is_equal(4)  # 적 3 + 늪어미
	assert_bool(fishing.has_spot(DataRegistry.get_region("r_moon_marsh"))).is_true()
	assert_int(Fishing.candidates(DataRegistry.fish, "r_moon_marsh", "night", 2).size()).is_equal(3)
	# 밤 변형: 늪귓것 풀·적 4+보스
	var night := DataRegistry.get_region("r_moon_marsh@night")
	assert_that(night).is_not_null()
	assert_bool(night.enemy_pool.has("e_marsh_wraith")).is_true()
	assert_int(night.enemy_count).is_equal(4)
	# 문서고 외곽: 심부 너머, 적 4 + 회수 집행관
	assert_bool(region_manager.travel("r_ash_field")).is_true()
	assert_bool(region_manager.travel("r_ash_field_deep")).is_true()
	assert_bool(region_manager.travel("r_archive_gate")).is_true()
	await runner.simulate_frames(2)
	assert_str(GameState.player_region).is_equal("r_archive_gate")
	assert_int(expedition.enemies.size()).is_equal(5)
	var boss_found := false
	for enemy in expedition.enemies:
		if enemy.enemy.id == "e_auditor":
			boss_found = true
	assert_bool(boss_found).is_true()
	assert_bool(region_manager.travel("r_house")).is_true()
