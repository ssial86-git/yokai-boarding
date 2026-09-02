class_name TestSaveRoundtrip
extends GdUnitTestSuite
## 세이브 → 로드 왕복 동일성과 v1 → v2 마이그레이션 (CLAUDE.md 6절 최소 통합 테스트 2번).

const TEST_SLOT := 99


func after_test() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_round_trip_through_file_is_identical() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	GameState.day = 4
	GameState.reputation = 7
	GameState.affinity["y01_ttukttagi"] = 3
	GameState.residents.append("y01_ttukttagi")
	var grid := GameState.room_grid
	assert_int(grid.add_floor(GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.add_floor(GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.place_room(Vector2i(0, 2), "workshop", GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.demolish_room(Vector2i(2, 0))).is_equal(RoomGrid.Outcome.OK)
	Clock.phase = Clock.Phase.EVENING
	Clock.elapsed_in_phase = 12.5
	var expected := SaveManager.build_save_data()

	assert_int(SaveManager.save_slot(TEST_SLOT)).is_equal(OK)
	GameState.reset_new_game()  # 상태를 완전히 바꿔 로드가 실제로 복원하는지 확인
	Clock.phase = Clock.Phase.MORNING
	Clock.elapsed_in_phase = 0.0
	assert_dict(SaveManager.build_save_data()).is_not_equal(expected)

	assert_int(SaveManager.load_slot(TEST_SLOT)).is_equal(OK)
	assert_dict(SaveManager.build_save_data()).is_equal(expected)
	assert_int(GameState.room_grid.built_floors).is_equal(3)
	assert_str(GameState.room_grid.get_room_id(Vector2i(0, 2))).is_equal("workshop")
	assert_bool(GameState.room_grid.is_empty(Vector2i(2, 0))).is_true()


func test_v1_save_migrates_to_default_house() -> void:
	var v1 := {
		"version": 1,
		"game_state": {"day": 3, "money": 50, "reputation": 1, "affinity": {}, "residents": []},
		"clock": {"phase": Clock.Phase.NIGHT, "elapsed_in_phase": 0.0},
	}
	assert_bool(SaveManager.apply_save_data(v1)).is_true()
	assert_int(GameState.day).is_equal(3)
	assert_int(GameState.money).is_equal(50)
	assert_int(GameState.room_grid.built_floors).is_equal(1)
	# 시작 배치(tuning start_layout_floor0)가 적용된다
	assert_str(GameState.room_grid.get_room_id(Vector2i(0, 0))).is_equal("gate")
	assert_int(SaveManager.build_save_data()["version"]).is_equal(SaveManager.SAVE_VERSION)


func test_unsupported_version_or_bad_grid_rejected() -> void:
	assert_bool(SaveManager.apply_save_data({"version": 99})).is_false()
	assert_bool(SaveManager.apply_save_data({"version": 0})).is_false()
	var bad := {
		"version": 2,
		"game_state": {"day": 1, "room_grid": {"floors": 1, "columns": 1, "built_floors": 1, "cells": ["x"]}},
	}
	assert_bool(SaveManager.apply_save_data(bad)).is_false()
