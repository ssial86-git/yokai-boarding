class_name TestRoomGrid
extends GdUnitTestSuite
## RoomGrid 순수 로직 검증. DataRegistry 없이 카탈로그를 코드로 만든다.

const FLOORS := 3
const COLUMNS := 4
const FLOOR_COST := 300
const GROWTH := 1.5
const REFUND := 0.5


func _room(id: String, kind: String, cost: int, requires: String = "") -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.kind = kind
	room.build_cost = cost
	room.requires_room = requires
	return room


func _catalog() -> Dictionary:
	var rooms: Array[RoomData] = [
		_room("empty_lot", "empty", 0),
		_room("guest_room", "lodging", 100),
		_room("kitchen", "production", 150),
		_room("gate", "gate", 120),
		_room("bath", "service", 200, "kitchen"),
	]
	var result: Dictionary = {}
	for room in rooms:
		result[room.id] = room
	return result


func _grid() -> RoomGrid:
	var grid := RoomGrid.new(_catalog(), FLOORS, COLUMNS)
	grid.configure_costs(FLOOR_COST, GROWTH, REFUND)
	return grid


func test_initial_state_first_floor_empty_others_locked() -> void:
	var grid := _grid()
	assert_int(grid.built_floors).is_equal(1)
	assert_str(grid.get_empty_room_id()).is_equal("empty_lot")
	for column in COLUMNS:
		assert_bool(grid.is_empty(Vector2i(column, 0))).is_true()
	assert_str(grid.get_room_id(Vector2i(0, 1))).is_equal("")
	assert_bool(grid.is_floor_built(1)).is_false()
	assert_int(grid.get_built_cells().size()).is_equal(COLUMNS)


func test_out_of_bounds_and_locked() -> void:
	var grid := _grid()
	assert_int(grid.check_place(Vector2i(COLUMNS, 0), "guest_room", 999)).is_equal(RoomGrid.Outcome.OUT_OF_BOUNDS)
	assert_int(grid.check_place(Vector2i(0, 1), "guest_room", 999)).is_equal(RoomGrid.Outcome.FLOOR_LOCKED)
	assert_int(grid.check_demolish(Vector2i(-1, 0))).is_equal(RoomGrid.Outcome.OUT_OF_BOUNDS)


func test_place_room_on_empty_cell() -> void:
	var grid := _grid()
	assert_int(grid.get_place_cost("guest_room")).is_equal(100)
	assert_int(grid.place_room(Vector2i(0, 0), "guest_room", 100)).is_equal(RoomGrid.Outcome.OK)
	assert_str(grid.get_room_id(Vector2i(0, 0))).is_equal("guest_room")
	assert_int(grid.count_rooms("guest_room")).is_equal(1)


func test_place_rejections() -> void:
	var grid := _grid()
	assert_int(grid.place_room(Vector2i(0, 0), "guest_room", 99)).is_equal(RoomGrid.Outcome.INSUFFICIENT_FUNDS)
	assert_bool(grid.is_empty(Vector2i(0, 0))).is_true()
	assert_int(grid.place_room(Vector2i(0, 0), "nope", 999)).is_equal(RoomGrid.Outcome.UNKNOWN_ROOM)
	assert_int(grid.place_room(Vector2i(0, 0), "empty_lot", 999)).is_equal(RoomGrid.Outcome.CANNOT_PLACE_EMPTY)
	grid.place_room(Vector2i(0, 0), "guest_room", 999)
	assert_int(grid.place_room(Vector2i(0, 0), "guest_room", 999)).is_equal(RoomGrid.Outcome.SAME_ROOM)


func test_renovate_replaces_room() -> void:
	var grid := _grid()
	grid.place_room(Vector2i(1, 0), "guest_room", 999)
	assert_int(grid.place_room(Vector2i(1, 0), "kitchen", 150)).is_equal(RoomGrid.Outcome.OK)
	assert_str(grid.get_room_id(Vector2i(1, 0))).is_equal("kitchen")


func test_requirement_missing_then_satisfied() -> void:
	var grid := _grid()
	assert_int(grid.check_place(Vector2i(0, 0), "bath", 999)).is_equal(RoomGrid.Outcome.REQUIREMENT_MISSING)
	grid.place_room(Vector2i(1, 0), "kitchen", 999)
	assert_int(grid.place_room(Vector2i(0, 0), "bath", 999)).is_equal(RoomGrid.Outcome.OK)


func test_required_room_cannot_be_removed_or_renovated() -> void:
	var grid := _grid()
	grid.place_room(Vector2i(1, 0), "kitchen", 999)
	grid.place_room(Vector2i(0, 0), "bath", 999)
	assert_int(grid.check_demolish(Vector2i(1, 0))).is_equal(RoomGrid.Outcome.REQUIRED_BY_OTHER)
	assert_int(grid.check_place(Vector2i(1, 0), "gate", 999)).is_equal(RoomGrid.Outcome.REQUIRED_BY_OTHER)
	# 주방이 하나 더 있으면 하나는 철거 가능
	grid.place_room(Vector2i(2, 0), "kitchen", 999)
	assert_int(grid.demolish_room(Vector2i(1, 0))).is_equal(RoomGrid.Outcome.OK)


func test_demolish_refund() -> void:
	var grid := _grid()
	grid.place_room(Vector2i(3, 0), "kitchen", 999)
	assert_int(grid.get_demolish_refund(Vector2i(3, 0))).is_equal(75)
	assert_int(grid.demolish_room(Vector2i(3, 0))).is_equal(RoomGrid.Outcome.OK)
	assert_bool(grid.is_empty(Vector2i(3, 0))).is_true()
	assert_int(grid.get_demolish_refund(Vector2i(3, 0))).is_equal(0)
	assert_int(grid.demolish_room(Vector2i(3, 0))).is_equal(RoomGrid.Outcome.ALREADY_EMPTY)


func test_add_floor_costs_grow_and_cap() -> void:
	var grid := _grid()
	assert_int(grid.get_next_floor_cost()).is_equal(300)
	assert_int(grid.add_floor(299)).is_equal(RoomGrid.Outcome.INSUFFICIENT_FUNDS)
	assert_int(grid.add_floor(300)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.built_floors).is_equal(2)
	assert_bool(grid.is_empty(Vector2i(0, 1))).is_true()
	assert_int(grid.get_next_floor_cost()).is_equal(450)
	assert_int(grid.add_floor(450)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.add_floor(9999)).is_equal(RoomGrid.Outcome.MAX_FLOORS_REACHED)
	assert_int(grid.get_built_cells().size()).is_equal(FLOORS * COLUMNS)


func test_apply_layout_ignores_unknown_ids() -> void:
	var grid := _grid()
	grid.apply_layout(0, ["gate", "guest_room", "nope"])
	assert_str(grid.get_room_id(Vector2i(0, 0))).is_equal("gate")
	assert_str(grid.get_room_id(Vector2i(1, 0))).is_equal("guest_room")
	assert_str(grid.get_room_id(Vector2i(2, 0))).is_equal("empty_lot")
	assert_str(grid.get_room_id(Vector2i(3, 0))).is_equal("empty_lot")


func test_serialization_round_trip() -> void:
	var grid := _grid()
	grid.apply_layout(0, ["gate", "guest_room", "kitchen", "empty_lot"])
	grid.add_floor(9999)
	grid.place_room(Vector2i(2, 1), "bath", 9999)
	var data := grid.to_dict()

	var restored := _grid()
	assert_bool(restored.from_dict(data)).is_true()
	assert_dict(restored.to_dict()).is_equal(data)
	assert_str(restored.get_room_id(Vector2i(2, 1))).is_equal("bath")
	assert_int(restored.built_floors).is_equal(2)


func test_from_dict_rejects_bad_data_without_mutating() -> void:
	var grid := _grid()
	var before := grid.to_dict()
	assert_bool(grid.from_dict({"floors": 2, "columns": COLUMNS, "built_floors": 1, "cells": []})).is_false()
	assert_bool(grid.from_dict({"floors": FLOORS, "columns": COLUMNS, "built_floors": 9, "cells": []})).is_false()
	var bad_cells: Array = []
	bad_cells.resize(FLOORS * COLUMNS)
	bad_cells.fill("")
	bad_cells[0] = "nope"
	assert_bool(grid.from_dict({"floors": FLOORS, "columns": COLUMNS, "built_floors": 1, "cells": bad_cells})).is_false()
	# 잠긴 층에 방이 있으면 거부
	var locked_cells: Array = before["cells"].duplicate()
	locked_cells[COLUMNS] = "gate"
	assert_bool(grid.from_dict({"floors": FLOORS, "columns": COLUMNS, "built_floors": 1, "cells": locked_cells})).is_false()
	assert_dict(grid.to_dict()).is_equal(before)
