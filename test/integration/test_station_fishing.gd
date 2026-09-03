class_name TestStationFishing
extends GdUnitTestSuite
## P1-S3: 가마솥 요리(실시간)·배식 버프·판매·부적 제작·도구 벼리기·손님 만족·낚시를 메인 씬에서 확인한다.

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


func test_cook_serve_sell_in_real_time() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var station_system: StationSystem = main.get("station_system")
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	_drain(story, intake)

	assert_int(station_system.start_cook("r_namul_muchim")).is_equal(WorkStation.Outcome.INVALID)  # 티어 1 미해금(1일차)
	GameState.unlocked["u_recipes_tier1"] = 1
	assert_int(station_system.start_cook("r_namul_muchim")).is_equal(WorkStation.Outcome.MISSING_INGREDIENTS)
	GameState.inventory.add("m_namul", 2)
	assert_int(station_system.start_cook("r_namul_muchim")).is_equal(WorkStation.Outcome.OK)
	assert_int(GameState.inventory.get_count("m_namul")).is_equal(0)
	assert_bool(GameState.station(GameState.STATION_KITCHEN).is_busy()).is_true()
	assert_int(station_system.start_cook("r_namul_muchim")).is_equal(WorkStation.Outcome.BUSY)
	station_system.tick_all(19.0)
	assert_int(GameState.inventory.get_count("dish_namul_muchim")).is_equal(0)
	station_system.tick_all(2.0)
	assert_int(GameState.inventory.get_count("dish_namul_muchim")).is_equal(1)
	assert_bool(GameState.station(GameState.STATION_KITCHEN).is_busy()).is_false()
	assert_int(Metrics.count("cook")).is_greater_equal(1)
	assert_int(station_system.start_cook("r_kimchi")).is_equal(WorkStation.Outcome.INVALID)  # 티어 2

	# 배식: 버섯국은 눈 +1, 나물무침은 버프 없음. 버프는 다음 날 사라진다
	GameState.inventory.add("m_mushroom", 2)
	GameState.inventory.add("m_spring_water", 1)
	assert_int(station_system.start_cook("r_mushroom_soup")).is_equal(WorkStation.Outcome.OK)
	station_system.tick_all(31.0)
	var base := GameState.stat_of("y01_ttukttagi", "sight")
	assert_bool(station_system.serve("dish_namul_muchim", "y01_ttukttagi")).is_false()
	assert_bool(station_system.serve("dish_mushroom_soup", "y01_ttukttagi")).is_true()
	assert_int(GameState.stat_of("y01_ttukttagi", "sight")).is_equal(base + 1)
	assert_int(GameState.inventory.get_count("dish_mushroom_soup")).is_equal(0)
	Clock.sleep()
	_drain(story, intake)
	assert_int(GameState.stat_of("y01_ttukttagi", "sight")).is_equal(base)

	# 판매: 대문간 행상. 씨앗은 팔 수 없다
	var money := GameState.money
	var price := station_system.unit_price("dish_namul_muchim")
	assert_int(price).is_equal(14)
	assert_int(station_system.sell("dish_namul_muchim", 1)).is_equal(price)
	assert_int(GameState.money).is_equal(money + price)
	assert_int(station_system.sell("seed_radish", 1)).is_equal(0)
	assert_int(Metrics.count("sell")).is_equal(1)


func test_craft_talisman_and_upgrade_tool() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var station_system: StationSystem = main.get("station_system")
	_drain(main.get("story_system"), main.get("intake_system"))

	assert_int(station_system.available_talismans().size()).is_equal(0)
	GameState.unlocked["u_t_throw"] = 1
	assert_int(station_system.available_talismans().size()).is_equal(1)
	assert_int(station_system.start_craft("t_gather")).is_equal(WorkStation.Outcome.INVALID)
	GameState.inventory.add("cloth", 1)
	GameState.inventory.add("m_ember_stone", 1)  # 잿빛 들 전리품 → 투척 부적 (사슬)
	assert_int(station_system.start_craft("t_throw")).is_equal(WorkStation.Outcome.OK)
	station_system.tick_all(30.0)
	assert_int(GameState.inventory.get_count("t_throw")).is_equal(1)
	assert_int(Metrics.count("craft")).is_greater_equal(1)

	# 도끼 벼리기: Lv1 을 들고 있고 u_axe_2 가 열려야 목록에 뜬다
	assert_int(station_system.available_upgrades().size()).is_equal(0)
	GameState.tools["axe"] = 1
	GameState.unlocked["u_axe_2"] = 1
	var ids: Array[String] = []
	for tool in station_system.available_upgrades():
		ids.append(tool.id)
	assert_array(ids).contains_exactly(["axe_2"])
	assert_bool(station_system.upgrade_tool("axe_2")).is_false()  # 재료 없음
	GameState.inventory.add("wood", 3)
	GameState.inventory.add("scrap", 3)
	assert_bool(station_system.upgrade_tool("axe_2")).is_true()
	assert_bool(GameState.has_tool("axe", 2)).is_true()
	assert_int(GameState.inventory.get_count("wood")).is_equal(0)
	assert_bool(station_system.upgrade_tool("axe_2")).is_false()  # 이미 Lv2


func test_guest_eats_liked_dish_at_checkout() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var day_cycle: DayCycle = main.get("day_cycle")
	_drain(main.get("story_system"), main.get("intake_system"))
	GameState.guests.append({"species_id": "g_mongdanggwi", "visitor_id": "v_guest", "arrived_day": GameState.day, "depart_day": GameState.day, "omen": 0})
	GameState.inventory.add("dish_acorn_jelly", 1)
	var money := GameState.money
	var bonus := DataRegistry.tuning.get_int("guest_dish_bonus_money")
	var summary := day_cycle.settle_rent(DataRegistry.tuning.get_int("condition_max"))
	assert_int(int(summary["dish_bonus"])).is_equal(bonus)
	assert_int((summary["dish_texts"] as Array).size()).is_equal(1)
	assert_int(GameState.inventory.get_count("dish_acorn_jelly")).is_equal(0)
	assert_int(GameState.money).is_equal(money + int(summary["money"]))
	assert_int(int(summary["money"])).is_greater_equal(bonus)
	assert_bool(GameState.guests.is_empty()).is_true()


func test_fishing_hit_miss_and_timeout() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var fishing_system: FishingSystem = main.get("fishing_system")
	_drain(main.get("story_system"), main.get("intake_system"))

	assert_bool(fishing_system.can_start("r_stream")).is_false()  # 낚시 미해금·낚싯대 없음
	GameState.unlocked["u_fishing"] = 1
	GameState.tools["rod"] = 1
	assert_bool(fishing_system.can_start("r_yard")).is_false()  # 낚시 자리 없음
	assert_bool(region_manager.travel("r_stream")).is_true()
	await runner.simulate_frames(2)
	assert_object(region_manager.current_view().get_node_or_null("FishingSpot")).is_not_null()

	assert_bool(fishing_system.start("r_stream")).is_true()
	assert_bool(fishing_system.is_active()).is_true()
	assert_str(fishing_system.prompt_for("r_stream")).is_equal(DataRegistry.text("prompt_fish_strike"))
	fishing_system.cast.center = fishing_system.cast.marker()  # 확실히 맞는 자리
	var caught := fishing_system.strike()
	assert_str(caught).is_not_empty()
	assert_int(GameState.inventory.get_count(caught)).is_equal(1)
	assert_bool(fishing_system.is_active()).is_false()

	assert_bool(fishing_system.start("r_stream")).is_true()
	fishing_system.cast.half_width = 0.01
	fishing_system.cast.center = 0.0
	fishing_system.cast.elapsed = 0.0  # 마커 0.5 → 놓침
	var missed := fishing_system.strike()
	if not missed.is_empty():
		assert_str(DataRegistry.get_fish(missed).kind).is_equal("junk")  # 놓치면 고물뿐

	assert_bool(fishing_system.start("r_stream")).is_true()
	fishing_system.tick(DataRegistry.tuning.get_float("fishing_max_seconds") + 1.0)
	assert_bool(fishing_system.is_active()).is_false()  # 제한 시간 초과
	assert_int(Metrics.count("fish")).is_equal(3)
	assert_bool(region_manager.travel("r_house")).is_true()
