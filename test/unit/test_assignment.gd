class_name TestAssignment
extends GdUnitTestSuite


func _room(id: String, kind: String, capacity: int) -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.kind = kind
	room.capacity = capacity
	return room


func _grid() -> RoomGrid:
	var catalog := {
		"empty_lot": _room("empty_lot", "empty", 0),
		"guest_room": _room("guest_room", "lodging", 1),
		"kitchen": _room("kitchen", "production", 1),
		"workshop": _room("workshop", "production", 2),
		"storage": _room("storage", "storage", 0),
	}
	var grid := RoomGrid.new(catalog, 3, 4)
	grid.configure_costs(0, 1.0, 0.0)
	grid.apply_layout(0, ["guest_room", "kitchen", "workshop", "storage"])
	return grid


func test_assign_and_capacity() -> void:
	var grid := _grid()
	var a := Assignment.new()
	assert_bool(a.is_resting("y1")).is_true()
	assert_int(a.assign(grid, Vector2i(1, 0), "y1")).is_equal(Assignment.Outcome.OK)
	assert_int(a.assign(grid, Vector2i(1, 0), "y1")).is_equal(Assignment.Outcome.OK)  # 같은 칸 재배치
	assert_int(a.assign(grid, Vector2i(1, 0), "y2")).is_equal(Assignment.Outcome.FULL)
	assert_int(a.assign(grid, Vector2i(2, 0), "y2")).is_equal(Assignment.Outcome.OK)
	assert_int(a.assign(grid, Vector2i(2, 0), "y3")).is_equal(Assignment.Outcome.OK)
	assert_array(a.workers_at(Vector2i(2, 0))).contains_exactly(["y2", "y3"])
	assert_that(a.get_cell("y1")).is_equal(Vector2i(1, 0))
	a.rest("y1")
	assert_bool(a.is_resting("y1")).is_true()
	assert_array(a.working_ids()).contains_exactly_in_any_order(["y2", "y3"])


func test_rejections() -> void:
	var grid := _grid()
	var a := Assignment.new()
	assert_int(a.check(grid, Vector2i(0, 0), "y1")).is_equal(Assignment.Outcome.NOT_WORKPLACE)  # 객실
	assert_int(a.check(grid, Vector2i(3, 0), "y1")).is_equal(Assignment.Outcome.NOT_WORKPLACE)  # 정원 0 창고
	assert_int(a.check(grid, Vector2i(1, 1), "y1")).is_equal(Assignment.Outcome.NOT_BUILT)
	assert_int(a.check(grid, Vector2i(-1, 0), "y1")).is_equal(Assignment.Outcome.NOT_BUILT)


func test_prune_after_room_change_and_departure() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(1, 0), "y1")
	a.assign(grid, Vector2i(2, 0), "y2")
	a.assign(grid, Vector2i(2, 0), "y3")
	grid.demolish_room(Vector2i(1, 0))
	var residents: Array[String] = ["y1", "y2"]
	var reset := a.prune(grid, residents)
	assert_array(reset).contains_exactly_in_any_order(["y1", "y3"])
	assert_bool(a.is_resting("y1")).is_true()
	assert_that(a.get_cell("y2")).is_equal(Vector2i(2, 0))


func test_serialization() -> void:
	var grid := _grid()
	var a := Assignment.new()
	a.assign(grid, Vector2i(1, 0), "y1")
	var data := a.to_dict()
	assert_dict(data).is_equal({"y1": [1, 0]})
	var b := Assignment.new()
	assert_bool(b.from_dict({"y1": [1.0, 0.0]})).is_true()
	assert_that(b.get_cell("y1")).is_equal(Vector2i(1, 0))
	assert_bool(b.from_dict({"y1": [1]})).is_false()
	assert_bool(b.from_dict({"y1": "x"})).is_false()
	assert_that(b.get_cell("y1")).is_equal(Vector2i(1, 0))
