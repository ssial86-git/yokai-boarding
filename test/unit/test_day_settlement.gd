class_name TestDaySettlement
extends GdUnitTestSuite


func _room(id: String, kind: String, capacity: int, quiet: bool = false, item: String = "", amount: int = 0) -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.kind = kind
	room.capacity = capacity
	room.quiet = quiet
	room.output_item = item
	room.output_amount = amount
	return room


func _yokai(id: String, preferred: String, bonus: float, noise: int) -> YokaiData:
	var yokai := YokaiData.new()
	yokai.id = id
	yokai.preferred_room = preferred
	yokai.work_bonus = bonus
	yokai.noise = noise
	return yokai


func _grid() -> RoomGrid:
	var catalog := {
		"empty_lot": _room("empty_lot", "empty", 0),
		"gate": _room("gate", "gate", 1),
		"guest_room": _room("guest_room", "lodging", 1, true),
		"kitchen": _room("kitchen", "production", 1, false, "meal", 2),
		"workshop": _room("workshop", "production", 1, false, "trinket", 1),
	}
	var grid := RoomGrid.new(catalog, 3, 4)
	grid.configure_costs(0, 1.0, 0.0)
	grid.apply_layout(0, ["gate", "guest_room", "workshop", "kitchen"])
	return grid


func _catalog() -> Dictionary:
	return {
		"loud": _yokai("loud", "workshop", 0.25, 3),
		"cook": _yokai("cook", "gate", 0.15, 0),
		"quiet": _yokai("quiet", "guest_room", 0.0, 0),
	}


func _params() -> DaySettlement.Params:
	var p := DaySettlement.Params.new()
	p.condition_max = 100
	p.work_condition_cost = 30
	p.rest_condition_gain = 40
	p.noise_condition_penalty_per_level = 10
	p.low_condition_threshold = 40
	p.low_condition_multiplier = 0.5
	return p


func test_rest_cell_prefers_lodging_then_gate() -> void:
	var grid := _grid()
	assert_that(DaySettlement.rest_cell(grid)).is_equal(Vector2i(1, 0))
	grid.demolish_room(Vector2i(1, 0))
	assert_that(DaySettlement.rest_cell(grid)).is_equal(Vector2i(0, 0))


func test_outputs_with_preferred_bonus_and_rounding() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(2, 0), "loud")  # 작업장, 선호 +25% -> 1 * 1.25 = 1.25 -> 1
	a.assign(grid, Vector2i(3, 0), "cook")  # 주방, 보너스 없음 -> 2
	var residents: Array[String] = ["loud", "cook", "quiet"]
	var result := DaySettlement.settle(grid, a, residents, _catalog(), {}, _params())
	assert_int(result.outputs.size()).is_equal(2)
	assert_dict(result.totals()).is_equal({"trinket": 1, "meal": 2})
	var loud_output: DaySettlement.Output = result.outputs[0]
	assert_bool(loud_output.preferred).is_true()
	assert_float(loud_output.multiplier).is_equal(1.25)


func test_conditions_work_rest_and_noise() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(2, 0), "loud")  # 객실(1,0) 옆에서 소음 3
	var residents: Array[String] = ["loud", "cook", "quiet"]
	var conditions := {"loud": 100, "cook": 80, "quiet": 50}
	var result := DaySettlement.settle(grid, a, residents, _catalog(), conditions, _params())
	assert_int(result.conditions["loud"]).is_equal(70)  # 일 -30
	assert_int(result.conditions["cook"]).is_equal(90)  # 휴식 +40, 소음 -30, 상한 100 -> 80+40-30
	assert_int(result.conditions["quiet"]).is_equal(60)  # 50+40-30
	assert_dict(result.noise_hits).is_equal({"cook": 3, "quiet": 3})


func test_no_noise_when_loud_worker_not_adjacent_or_room_not_quiet() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(3, 0), "loud")  # 주방은 객실과 떨어져 있다
	var residents: Array[String] = ["loud", "quiet"]
	var result := DaySettlement.settle(grid, a, residents, _catalog(), {"quiet": 50}, _params())
	assert_int(result.conditions["quiet"]).is_equal(90)
	assert_dict(result.noise_hits).is_empty()


func test_low_condition_halves_output() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(3, 0), "cook")
	var residents: Array[String] = ["cook"]
	var result := DaySettlement.settle(grid, a, residents, _catalog(), {"cook": 10}, _params())
	assert_int(result.outputs[0].amount).is_equal(1)
	assert_bool(result.outputs[0].low_condition).is_true()
	assert_int(result.conditions["cook"]).is_equal(0)  # 10-30 -> 0 으로 클램프
