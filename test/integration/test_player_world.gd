class_name TestPlayerWorld
extends GdUnitTestSuite
## P1-S2: 플레이어가 집에서 시작해 마당으로 나가 텃밭을 가꾸고(괭이질→파종→물주기→성장→수확),
## 2일차에 뒷산이 열려 채집하고, 텃밭 배치 요괴가 효율 계수로 물을 주는지 메인 씬에서 확인한다.

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


func _next_day(story: StorySystem, intake: IntakeSystem) -> void:
	Clock.advance_to_band(Clock.Band.EVENING)
	_drain(story, intake)
	Clock.advance_to_band(Clock.Band.NIGHT)
	_drain(story, intake)
	Clock.sleep()
	_drain(story, intake)


func test_back_hill_is_locked_on_day_one_and_house_is_start() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(2)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var player: PlayerController = main.get("player")
	assert_str(GameState.player_region).is_equal(HouseRegion.REGION_ID)
	assert_str(region_manager.current_region_id).is_equal(HouseRegion.REGION_ID)
	assert_object(player).is_not_null()
	assert_bool(GameState.has_tool("hoe")).is_true()  # u_hoe: 1일차 아침
	assert_bool(GameState.unlocked.has("u_hoe")).is_true()
	assert_bool(region_manager.is_region_open("r_yard")).is_true()  # 해금 행이 없는 구역은 늘 열려 있다
	assert_bool(region_manager.is_region_open("r_back_hill")).is_false()
	assert_bool(region_manager.travel("r_back_hill")).is_false()
	assert_str(region_manager.current_region_id).is_equal(HouseRegion.REGION_ID)


func test_farm_cycle_then_gather_on_back_hill() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(2)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var farm_system: FarmSystem = main.get("farm_system")
	var gather_system: GatherSystem = main.get("gather_system")
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	var player: PlayerController = main.get("player")
	_drain(story, intake)

	# 마당으로: 텃밭 6칸이 조립된다
	assert_bool(region_manager.travel("r_yard")).is_true()
	await runner.simulate_frames(2)
	assert_str(GameState.player_region).is_equal("r_yard")
	assert_bool(region_manager.current_view() is RegionView).is_true()
	var plots := 0
	for child in region_manager.current_view().get_children():
		if child is FarmPlotNode:
			plots += 1
	assert_int(plots).is_equal(DataRegistry.tuning.get_int("farm_plots_initial"))
	assert_float(player.global_position.y).is_equal(0.0)

	# 괭이질 → 파종(무 씨앗 3→2) → 물주기
	assert_bool(farm_system.act(0)).is_true()
	assert_int(GameState.farm.get_plot(0).state).is_equal(Farm.PlotState.TILLED)
	assert_bool(farm_system.act(0)).is_true()
	assert_int(GameState.farm.get_plot(0).state).is_equal(Farm.PlotState.GROWING)
	assert_str(GameState.farm.get_plot(0).crop_id).is_equal("c_radish")
	assert_int(GameState.inventory.get_count("seed_radish")).is_equal(2)
	assert_bool(farm_system.act(0)).is_true()
	assert_float(GameState.farm.get_plot(0).water).is_equal(1.0)
	assert_bool(farm_system.can_act(0)).is_false()  # 오늘은 다 줬다
	assert_float(GameState.stamina.value).is_less(GameState.stamina.params.max_value)

	# 무는 3일: 매일 물을 주면 4일차 아침에 익어 있다
	for i in 3:
		_next_day(story, intake)
		if GameState.farm.get_plot(0).state == Farm.PlotState.GROWING:
			farm_system.act(0)
	assert_int(GameState.day).is_equal(4)
	assert_int(GameState.farm.get_plot(0).state).is_equal(Farm.PlotState.READY)
	assert_bool(farm_system.act(0)).is_true()
	assert_int(GameState.inventory.get_count("radish")).is_greater_equal(1)
	assert_int(GameState.farm.get_plot(0).state).is_equal(Farm.PlotState.TILLED)

	# 2일차 아침에 뒷산·도끼·곡괭이가 열렸다
	assert_bool(region_manager.is_region_open("r_back_hill")).is_true()
	assert_bool(GameState.has_tool("axe")).is_true()
	assert_bool(GameState.has_tool("pickaxe")).is_true()
	assert_bool(region_manager.travel("r_back_hill")).is_true()
	await runner.simulate_frames(2)
	var points := gather_system.points_for("r_back_hill")
	assert_int(points.size()).is_equal(8)
	var gathered := 0
	for index in points.size():
		if gather_system.can_gather("r_back_hill", index):
			var material_id := points.material_at(index)
			var before := GameState.inventory.get_count(material_id)
			assert_bool(gather_system.gather("r_back_hill", index)).is_true()
			assert_int(GameState.inventory.get_count(material_id)).is_equal(before + 1)
			gathered += 1
	assert_int(gathered).is_greater(0)
	assert_int((GameState.region_state("r_back_hill")["gather_taken"] as Array).size()).is_equal(gathered)
	assert_int(Metrics.count("gather")).is_greater_equal(gathered)

	# 다음 날 채집물이 다시 자란다
	_next_day(story, intake)
	assert_int(gather_system.points_for("r_back_hill").remaining()).is_equal(8)

	# 세이브에 텃밭·도구·해금·구역 상태가 들어간다
	var saved := SaveManager.build_save_data()
	var state: Dictionary = saved["game_state"]
	assert_bool(state.has("farm") and state.has("tools") and state.has("unlocked")).is_true()
	assert_str(str((state["player"] as Dictionary)["region"])).is_equal("r_back_hill")


func test_field_assignment_auto_waters_with_efficiency() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(2)
	var main: Node = runner.scene()
	var farm_system: FarmSystem = main.get("farm_system")
	var assign: AssignmentController = main.get("assignment_controller")
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	_drain(story, intake)
	assert_bool(farm_system.act(0)).is_true()  # 괭이질
	assert_bool(farm_system.act(0)).is_true()  # 파종
	assert_int(assign.try_assign("y01_ttukttagi", Assignment.FIELD)).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y02_eoduki", Assignment.FIELD)).is_equal(AssignmentController.Outcome.FULL)
	Clock.advance_to_band(Clock.Band.DAY)
	var efficiency := DataRegistry.tuning.get_float("automation_efficiency")
	assert_float(GameState.farm.get_plot(0).water).is_equal_approx(efficiency, 0.0001)
	_next_day(story, intake)
	assert_float(GameState.farm.get_plot(0).growth).is_equal_approx(efficiency, 0.0001)  # 위임은 하루에 0.6일
	# 텃밭 배치도 일한 것: 컨디션이 깎인다
	assert_int(GameState.get_condition("y01_ttukttagi")).is_less(DataRegistry.tuning.get_int("condition_max"))
