class_name TestWorkStation
extends GdUnitTestSuite
## 작업대: 재료 소모 → 초 단위 진행 → 완성품 수거, 한 번에 하나, 직렬화.


func test_start_consumes_ingredients_and_ticks_to_completion() -> void:
	var station := WorkStation.new()
	var inventory := Inventory.new()
	inventory.add("m_namul", 3)
	assert_int(station.start("cook", "r_x", ["m_namul:2"], 10.0, "dish_x", 1, inventory)).is_equal(WorkStation.Outcome.OK)
	assert_int(inventory.get_count("m_namul")).is_equal(1)
	assert_bool(station.is_busy()).is_true()
	assert_int(station.start("cook", "r_y", [], 1.0, "dish_y", 1, inventory)).is_equal(WorkStation.Outcome.BUSY)
	assert_bool(station.tick(4.0)).is_false()
	assert_float(station.progress()).is_equal_approx(0.4, 0.0001)
	assert_dict(station.collect()).is_empty()
	assert_bool(station.tick(6.0)).is_true()
	assert_bool(station.tick(1.0)).is_false()  # 이미 끝난 뒤에는 다시 알리지 않는다
	assert_bool(station.is_done()).is_true()
	var result := station.collect()
	assert_str(str(result["item"])).is_equal("dish_x")
	assert_int(int(result["count"])).is_equal(1)
	assert_str(str(result["kind"])).is_equal("cook")
	assert_bool(station.is_busy()).is_false()


func test_missing_ingredients_and_invalid() -> void:
	var station := WorkStation.new()
	var inventory := Inventory.new()
	inventory.add("cloth", 1)
	assert_int(station.start("craft", "t_throw", ["cloth:1", "scrap:1"], 5.0, "t_throw", 1, inventory)) \
		.is_equal(WorkStation.Outcome.MISSING_INGREDIENTS)
	assert_int(inventory.get_count("cloth")).is_equal(1)  # 실패하면 소모하지 않는다
	assert_int(station.start("craft", "", [], 5.0, "t_throw", 1, inventory)).is_equal(WorkStation.Outcome.INVALID)
	assert_int(station.start("craft", "t_throw", ["bad"], 5.0, "t_throw", 1, inventory)).is_equal(WorkStation.Outcome.MISSING_INGREDIENTS)
	assert_bool(WorkStation.has_ingredients(["cloth:1"], inventory)).is_true()
	assert_array(WorkStation.parse_cost("wood:3")).contains_exactly(["wood", 3])
	assert_array(WorkStation.parse_cost("wood")).is_empty()


func test_zero_seconds_finishes_on_first_tick_and_serialization() -> void:
	var station := WorkStation.new()
	var inventory := Inventory.new()
	assert_int(station.start("craft", "axe_2", [], 0.0, "axe_2", 1, inventory)).is_equal(WorkStation.Outcome.OK)
	assert_bool(station.is_done()).is_true()
	station.clear()
	inventory.add("radish", 1)
	station.start("cook", "r_radish", ["radish:1"], 30.0, "dish_radish", 2, inventory)
	station.tick(12.5)
	var restored := WorkStation.new()
	assert_bool(restored.from_dict(station.to_dict())).is_true()
	assert_str(restored.job_id).is_equal("r_radish")
	assert_int(restored.output_count).is_equal(2)
	assert_float(restored.remaining_seconds).is_equal(17.5)
	assert_bool(restored.from_dict({})).is_true()  # 빈 작업대
	assert_bool(restored.is_busy()).is_false()
	assert_bool(restored.from_dict({"id": "x", "count": "many"})).is_false()
