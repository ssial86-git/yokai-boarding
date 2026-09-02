class_name TestRoomGraph
extends GdUnitTestSuite

const STAIR := 0


func _room(id: String, kind: String) -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.kind = kind
	return room


func _grid(built: int) -> RoomGrid:
	var catalog := {"empty_lot": _room("empty_lot", "empty"), "gate": _room("gate", "gate")}
	var grid := RoomGrid.new(catalog, 3, 4)
	grid.configure_costs(0, 1.0, 0.0)
	for i in built - 1:
		grid.add_floor(0)
	return grid


func test_same_floor_path_is_straight() -> void:
	var grid := _grid(1)
	var path := RoomGraph.find_path(grid, Vector2i(0, 0), Vector2i(3, 0), STAIR)
	assert_array(path).contains_exactly([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_floor_change_goes_through_stair_column() -> void:
	var grid := _grid(2)
	var path := RoomGraph.find_path(grid, Vector2i(3, 0), Vector2i(2, 1), STAIR)
	assert_array(path).contains_exactly([
		Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	])


func test_unbuilt_floor_unreachable_and_same_cell() -> void:
	var grid := _grid(1)
	assert_array(RoomGraph.find_path(grid, Vector2i(0, 0), Vector2i(0, 1), STAIR)).is_empty()
	assert_array(RoomGraph.find_path(grid, Vector2i(2, 0), Vector2i(2, 0), STAIR)).contains_exactly([Vector2i(2, 0)])
	assert_array(RoomGraph.find_path(grid, Vector2i(9, 0), Vector2i(0, 0), STAIR)).is_empty()


func test_neighbors_respect_stair_column() -> void:
	var grid := _grid(2)
	assert_array(RoomGraph.neighbors(grid, Vector2i(1, 0), STAIR)).contains_exactly([Vector2i(0, 0), Vector2i(2, 0)])
	assert_array(RoomGraph.neighbors(grid, Vector2i(0, 0), STAIR)).contains_exactly([Vector2i(1, 0), Vector2i(0, 1)])
	assert_array(RoomGraph.neighbors(grid, Vector2i(0, 1), 2)).contains_exactly([Vector2i(1, 1)])
