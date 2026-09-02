class_name TestHouseView
extends GdUnitTestSuite
## 메인 씬을 띄워 HouseController 조작이 HouseView 렌더링·돈에 반영되는지 확인한다.


func test_build_and_expand_updates_view() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var view: HouseView = main.get("house_view")
	var controller: HouseController = main.get("house_controller")
	assert_object(view).is_not_null()
	assert_object(controller).is_not_null()

	var grid := controller.grid()
	assert_int(view.get_cell_count()).is_equal(grid.columns)
	# 시작 배치
	assert_str(grid.get_room_id(Vector2i(0, 0))).is_equal("gate")
	assert_bool(grid.is_empty(Vector2i(3, 0))).is_true()

	GameState.money = 10_000
	var money_before := GameState.money
	assert_int(controller.try_place_room(Vector2i(3, 0), "workshop")).is_equal(RoomGrid.Outcome.OK)
	assert_int(GameState.money).is_equal(money_before - grid.get_place_cost("workshop"))

	assert_int(controller.try_add_floor()).is_equal(RoomGrid.Outcome.OK)
	assert_int(controller.try_add_floor()).is_equal(RoomGrid.Outcome.OK)
	assert_int(controller.try_add_floor()).is_equal(RoomGrid.Outcome.MAX_FLOORS_REACHED)
	await runner.simulate_frames(1)
	assert_int(view.get_cell_count()).is_equal(grid.floors * grid.columns)

	GameState.money = 0
	assert_int(controller.try_place_room(Vector2i(0, 2), "kitchen")).is_equal(RoomGrid.Outcome.INSUFFICIENT_FUNDS)


func test_world_to_cell_matches_cell_rect() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(1)
	var view: HouseView = runner.scene().get("house_view")
	for coords: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(1, 2)]:
		var center := view.to_global(view.cell_rect(coords).get_center())
		assert_that(view.world_to_cell(center)).is_equal(coords)
