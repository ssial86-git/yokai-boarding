extends Node
## JSON 한 파일 세이브. 스키마 변경 시 SAVE_VERSION 을 올리고 _migrate() 에 단계를 추가한다.
## v1: game_state(day/money/reputation/affinity/residents) + clock
## v2: game_state.room_grid 추가 (M1)
## v3: game_state.conditions / inventory / assignment 추가 (M2)
## v4: game_state.guests / ledger / flags / seen_events / pending_visitor / weather / rng_state 추가 (M3)
## v5: clock 이 페이즈(phase/elapsed_in_phase)에서 실시간 경과 초(elapsed_seconds)로 바뀜,
##     game_state.player(구역·위치) / regions(탐험지 상태) 추가 (P1-S1)
## v6: game_state.calendar(절기·절기 안 날짜) / yin(음기 지수) 추가 (P2-S1)
## v7: game_state.counters(활동 누계) / goals_done(완료 목표) / festival_results(명절 점수) 추가 (P2-S2)
## v8: game_state.blessings_today / blessing_log / market_bought 추가 (P2-S3)

const SAVE_VERSION := 8
const SAVE_DIR := "user://saves"
const SLOT_FILE_FORMAT := "slot_%d.json"


func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join(SLOT_FILE_FORMAT % slot)


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"game_state": GameState.to_dict(),
		"clock": {"elapsed_seconds": Clock.elapsed_seconds()},
	}


func apply_save_data(data: Dictionary) -> bool:
	var migrated := _migrate(data)
	if migrated.is_empty():
		return false
	if not GameState.from_dict(migrated.get("game_state", {})):
		push_error("SaveManager: game_state 형식 오류")
		return false
	var clock_data: Dictionary = migrated.get("clock", {})
	Clock.restore(float(clock_data.get("elapsed_seconds", 0.0)))
	return true


func save_slot(slot: int) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(build_save_data(), "\t"))
	file.close()
	Events.game_saved.emit(slot)
	return OK


func load_slot(slot: int) -> Error:
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	if not apply_save_data(parsed as Dictionary):
		return ERR_INVALID_DATA
	Events.game_loaded.emit(slot)
	return OK


## 구버전 데이터를 현재 스키마로 한 단계씩 올린다. 실패하면 빈 Dictionary.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION or version < 1:
		push_error("SaveManager: 지원하지 않는 세이브 버전 %d" % version)
		return {}
	var result := data.duplicate(true)
	if version < 2:
		_migrate_1_to_2(result)
	if version < 3:
		_migrate_2_to_3(result)
	if version < 4:
		_migrate_3_to_4(result)
	if version < 5:
		_migrate_4_to_5(result)
	if version < 6:
		_migrate_5_to_6(result)
	if version < 7:
		_migrate_6_to_7(result)
	if version < 8:
		_migrate_7_to_8(result)
	result["version"] = SAVE_VERSION
	return result


## v7 에는 가호·시장 기록이 없다. 비워 두면 빈 상태.
func _migrate_7_to_8(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	for key in ["blessings_today", "blessing_log", "market_bought"]:
		if not game_state.has(key):
			game_state[key] = {}
	data["game_state"] = game_state


## v6 에는 활동 누계·목표·명절 기록이 없다. 비워 두면 새 게임과 같은 빈 상태.
func _migrate_6_to_7(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	for key in ["counters", "goals_done", "festival_results"]:
		if not game_state.has(key):
			game_state[key] = {}
	data["game_state"] = game_state


## v5 에는 절기 달력·음기가 없다. 달력을 비워 두면 GameState.from_dict 가 통산 일차에서 계산한다.
func _migrate_5_to_6(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	if not game_state.has("calendar"):
		game_state["calendar"] = {}
	if not game_state.has("yin"):
		game_state["yin"] = 0
	data["game_state"] = game_state


## v4 의 페이즈를 그 시간대의 시작 시각으로 옮긴다. 페이즈 안 경과(elapsed_in_phase)는 길이 체계가 달라 버린다.
func _migrate_4_to_5(data: Dictionary) -> void:
	var clock_data: Dictionary = data.get("clock", {})
	if not clock_data.has("elapsed_seconds"):
		var band := clampi(int(clock_data.get("phase", Clock.Band.MORNING)), Clock.Band.MORNING, Clock.Band.NIGHT)
		clock_data["elapsed_seconds"] = Clock.timeline.seconds_for_band(band)
	clock_data.erase("phase")
	clock_data.erase("elapsed_in_phase")
	data["clock"] = clock_data
	# v4 에는 플레이어 위치·탐험지 상태가 없다. 비워 두면 GameState.from_dict 가 시작 위치·빈 상태로 채운다.
	var game_state: Dictionary = data.get("game_state", {})
	for key in ["player", "regions"]:
		if not game_state.has(key):
			game_state[key] = {}
	data["game_state"] = game_state


## v3 에는 손님·명부·서사 상태가 없다. 빈 값이면 GameState.from_dict 가 기본값(새 RNG 시드 포함)으로 채운다.
func _migrate_3_to_4(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	for key in ["guests", "seen_events"]:
		if not game_state.has(key):
			game_state[key] = []
	for key in ["ledger", "flags", "pending_visitor"]:
		if not game_state.has(key):
			game_state[key] = {}
	data["game_state"] = game_state


## v1 에는 room_grid 가 없다. 비워 두면 GameState.from_dict 가 시작 배치로 채운다.
func _migrate_1_to_2(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	game_state.erase("room_grid")
	data["game_state"] = game_state


## v2 에는 컨디션·인벤토리·배치가 없다. 빈 값으로 두면 GameState.from_dict 가 기본값으로 채운다.
func _migrate_2_to_3(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	for key in ["conditions", "inventory", "assignment"]:
		if not game_state.has(key):
			game_state[key] = {}
	data["game_state"] = game_state
