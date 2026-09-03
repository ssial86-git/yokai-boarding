class_name TestSaveRoundtrip
extends GdUnitTestSuite
## 세이브 → 로드 왕복 동일성과 구버전(v1/v2/v4) → v5 마이그레이션 (CLAUDE.md 6절 최소 통합 테스트 2번).

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
	GameState.conditions["y02_eoduki"] = 55
	GameState.inventory.add("meal", 3)
	GameState.inventory.add("trinket", 1)
	GameState.guests.append({"species_id": "g_ibulnang", "visitor_id": "v_guest", "arrived_day": 4, "depart_day": 5, "omen": 1})
	GameState.ledger["g_ibulnang"] = 2
	GameState.flags["clue_y01"] = true
	GameState.seen_events.append("y01_act1")
	GameState.pending_visitor = {"visitor_id": "v_guest", "kind": "guest", "species_id": "g_mongdanggwi", "yokai_id": "", "omen": 0}
	GameState.weather = "rain"
	GameState.yin = 2
	assert_bool(GameState.calendar.from_dict({"season": "spring", "day_of_season": 12}, DataRegistry.seasons)).is_true()
	GameState.counters["gather"] = 7
	GameState.counters["cook.r_patjuk"] = 1
	GameState.goals_done["g_t_till"] = 2
	GameState.festival_results["f_dongji"] = 9
	GameState.rng.seed = 777
	var grid := GameState.room_grid
	assert_int(grid.add_floor(GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.add_floor(GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.place_room(Vector2i(0, 2), "workshop", GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(grid.demolish_room(Vector2i(2, 0))).is_equal(RoomGrid.Outcome.OK)
	assert_int(GameState.assignment.assign(grid, Vector2i(0, 2), "y01_ttukttagi")).is_equal(Assignment.Outcome.OK)
	Clock.restore(452.5)  # 저녁 시간대 한가운데
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	GameState.set_player_location("r_back_hill", Vector2(120.0, -16.0))
	var ash := GameState.region_state("r_ash_field")
	ash["visited"] = true
	ash["gather_taken"] = ["gp_1", "gp_5"]
	ash["enemies_defeated"] = ["e_ash_wisp"]
	GameState.stamina.value = 42.5
	GameState.tools["axe"] = 2
	GameState.unlocked["u_hoe"] = 1
	assert_int(GameState.farm.till(1)).is_equal(Farm.Outcome.OK)
	assert_int(GameState.assignment.assign(grid, Assignment.FIELD, "y02_eoduki")).is_equal(Assignment.Outcome.OK)
	var expected := SaveManager.build_save_data()

	assert_int(SaveManager.save_slot(TEST_SLOT)).is_equal(OK)
	GameState.reset_new_game()  # 상태를 완전히 바꿔 로드가 실제로 복원하는지 확인
	Clock.restore(0.0)
	assert_dict(SaveManager.build_save_data()).is_not_equal(expected)

	assert_int(SaveManager.load_slot(TEST_SLOT)).is_equal(OK)
	assert_dict(SaveManager.build_save_data()).is_equal(expected)
	assert_float(Clock.elapsed_seconds()).is_equal(452.5)
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	assert_str(GameState.player_region).is_equal("r_back_hill")
	assert_that(GameState.player_position).is_equal(Vector2(120.0, -16.0))
	assert_bool(GameState.region_state("r_back_hill")["visited"]).is_true()
	assert_array(GameState.region_state("r_ash_field")["gather_taken"]).contains_exactly(["gp_1", "gp_5"])
	assert_array(GameState.region_state("r_ash_field")["enemies_defeated"]).contains_exactly(["e_ash_wisp"])
	assert_bool(GameState.region_state("r_ash_field")["boss_defeated"]).is_false()
	assert_float(GameState.stamina.value).is_equal(42.5)
	assert_int(int(GameState.tools["axe"])).is_equal(2)
	assert_bool(GameState.unlocked.has("u_hoe")).is_true()
	assert_int(GameState.farm.get_plot(1).state).is_equal(Farm.PlotState.TILLED)
	assert_that(GameState.assignment.get_cell("y02_eoduki")).is_equal(Assignment.FIELD)
	assert_int(GameState.room_grid.built_floors).is_equal(3)
	assert_str(GameState.room_grid.get_room_id(Vector2i(0, 2))).is_equal("workshop")
	assert_bool(GameState.room_grid.is_empty(Vector2i(2, 0))).is_true()
	assert_that(GameState.assignment.get_cell("y01_ttukttagi")).is_equal(Vector2i(0, 2))
	assert_int(GameState.inventory.get_count("meal")).is_equal(3)
	assert_int(GameState.get_condition("y02_eoduki")).is_equal(55)
	assert_int(GameState.guests.size()).is_equal(1)
	assert_int(GameState.guests[0]["depart_day"]).is_equal(5)
	assert_int(GameState.ledger["g_ibulnang"]).is_equal(2)
	assert_bool(GameState.flags.has("clue_y01")).is_true()
	assert_str(GameState.weather).is_equal("rain")
	assert_int(GameState.yin).is_equal(2)
	assert_str(GameState.calendar.season_id).is_equal("spring")
	assert_int(GameState.calendar.day_of_season).is_equal(12)
	assert_int(int(GameState.counters["gather"])).is_equal(7)
	assert_int(int(GameState.counters["cook.r_patjuk"])).is_equal(1)
	assert_int(int(GameState.goals_done["g_t_till"])).is_equal(2)
	assert_int(int(GameState.festival_results["f_dongji"])).is_equal(9)
	assert_str(str(GameState.pending_visitor.get("species_id"))).is_equal("g_mongdanggwi")


## v6 에는 활동 누계·목표·명절 기록이 없다 → 빈 상태로 채워진다 (P2-S2).
func test_v6_save_gets_empty_goal_state() -> void:
	GameState.reset_new_game()
	GameState.counters["gather"] = 3
	var v6 := {"version": 6, "game_state": GameState.to_dict(), "clock": {"elapsed_seconds": 10.0}}
	var state := v6["game_state"] as Dictionary
	for key in ["counters", "goals_done", "festival_results"]:
		state.erase(key)
	assert_bool(SaveManager.apply_save_data(v6)).is_true()
	assert_bool(GameState.counters.is_empty()).is_true()
	assert_bool(GameState.goals_done.is_empty()).is_true()
	assert_bool(GameState.festival_results.is_empty()).is_true()
	assert_int(SaveManager.build_save_data()["version"]).is_equal(SaveManager.SAVE_VERSION)


## v5 에는 절기 달력·음기가 없다. 통산 30일차 → 여름 2일, 음기 0 으로 채워진다 (P2-S1).
func test_v5_save_gets_calendar_from_absolute_day() -> void:
	GameState.reset_new_game()
	var v5 := {"version": 5, "game_state": GameState.to_dict(), "clock": {"elapsed_seconds": 10.0}}
	var state := v5["game_state"] as Dictionary
	state["day"] = 30
	state.erase("calendar")
	state.erase("yin")
	assert_bool(SaveManager.apply_save_data(v5)).is_true()
	assert_int(GameState.day).is_equal(30)
	assert_str(GameState.calendar.season_id).is_equal("summer")
	assert_int(GameState.calendar.day_of_season).is_equal(2)
	assert_int(GameState.yin).is_equal(0)
	assert_int(SaveManager.build_save_data()["version"]).is_equal(SaveManager.SAVE_VERSION)


func test_v1_save_migrates_to_default_house() -> void:
	var v1 := {
		"version": 1,
		"game_state": {"day": 3, "money": 50, "reputation": 1, "affinity": {}, "residents": []},
		"clock": {"phase": 3, "elapsed_in_phase": 0.0},  # v1~v4 의 페이즈 NIGHT
	}
	assert_bool(SaveManager.apply_save_data(v1)).is_true()
	assert_int(GameState.day).is_equal(3)
	assert_int(Clock.band).is_equal(Clock.Band.NIGHT)
	assert_int(GameState.money).is_equal(50)
	assert_int(GameState.room_grid.built_floors).is_equal(1)
	# 시작 배치(tuning start_layout_floor0)가 적용된다
	assert_str(GameState.room_grid.get_room_id(Vector2i(0, 0))).is_equal("gate")
	assert_int(SaveManager.build_save_data()["version"]).is_equal(SaveManager.SAVE_VERSION)


func test_v2_save_gets_default_inventory_assignment_conditions() -> void:
	GameState.reset_new_game()
	var v2 := {
		"version": 2,
		"game_state": {
			"day": 2, "money": 10, "reputation": 0, "affinity": {},
			"residents": ["y01_ttukttagi", "y02_eoduki", "y03_dalgael"],
			"room_grid": GameState.room_grid.to_dict(),
		},
		"clock": {"phase": 0, "elapsed_in_phase": 0.0},
	}
	assert_bool(SaveManager.apply_save_data(v2)).is_true()
	assert_bool(GameState.inventory.is_empty()).is_true()
	assert_bool(GameState.assignment.is_resting("y01_ttukttagi")).is_true()
	assert_int(GameState.get_condition("y03_dalgael")).is_equal(DataRegistry.tuning.get_int("condition_max"))


func test_unsupported_version_or_bad_grid_rejected() -> void:
	assert_bool(SaveManager.apply_save_data({"version": 99})).is_false()
	assert_bool(SaveManager.apply_save_data({"version": 0})).is_false()
	var bad := {
		"version": 4,
		"game_state": {"day": 1, "room_grid": {"floors": 1, "columns": 1, "built_floors": 1, "cells": ["x"]}},
	}
	assert_bool(SaveManager.apply_save_data(bad)).is_false()
	var bad_inventory := {"version": 4, "game_state": {"day": 1, "inventory": {"meal": -3}}}
	assert_bool(SaveManager.apply_save_data(bad_inventory)).is_false()


## v4 의 페이즈 시계는 그 시간대의 시작 시각으로 복원된다 (페이즈 안 경과는 길이 체계가 달라 버린다).
func test_v4_phase_clock_migrates_to_timeband_start() -> void:
	GameState.reset_new_game()
	var v4 := {
		"version": 4,
		"game_state": GameState.to_dict(),
		"clock": {"phase": 2, "elapsed_in_phase": 30.0},  # EVENING
	}
	(v4["game_state"] as Dictionary).erase("player")  # v4 세이브에는 이 키들이 없다
	(v4["game_state"] as Dictionary).erase("regions")
	GameState.set_player_location("r_ash_field", Vector2(9.0, 9.0))  # 로드가 v4 기본값으로 덮는지 확인
	assert_bool(SaveManager.apply_save_data(v4)).is_true()
	assert_int(Clock.band).is_equal(Clock.Band.EVENING)
	assert_float(Clock.elapsed_seconds()).is_equal(Clock.timeline.seconds_for_band(Clock.Band.EVENING))
	# v4 에는 플레이어·탐험지 상태가 없으므로 시작 위치와 빈 상태로 채워진다
	assert_str(GameState.player_region).is_equal(DataRegistry.tuning.get_string("player_start_region"))
	assert_that(GameState.player_position).is_equal(Vector2(
		DataRegistry.tuning.get_float("player_start_x"), DataRegistry.tuning.get_float("player_start_y")))
	assert_bool(GameState.region_states.is_empty()).is_true()
	var saved := SaveManager.build_save_data()
	assert_int(saved["version"]).is_equal(SaveManager.SAVE_VERSION)
	assert_bool((saved["clock"] as Dictionary).has("elapsed_seconds")).is_true()
	assert_bool((saved["clock"] as Dictionary).has("phase")).is_false()
