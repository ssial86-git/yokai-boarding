extends Node
## JSON 한 파일 세이브. 스키마 변경 시 SAVE_VERSION 을 올리고 _migrate() 에 단계를 추가한다.
## v1: game_state(day/money/reputation/affinity/residents) + clock
## v2: game_state.room_grid 추가 (M1)

const SAVE_VERSION := 2
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
		"clock": {"phase": Clock.phase, "elapsed_in_phase": Clock.elapsed_in_phase},
	}


func apply_save_data(data: Dictionary) -> bool:
	var migrated := _migrate(data)
	if migrated.is_empty():
		return false
	if not GameState.from_dict(migrated.get("game_state", {})):
		push_error("SaveManager: game_state 형식 오류")
		return false
	var clock_data: Dictionary = migrated.get("clock", {})
	Clock.phase = int(clock_data.get("phase", Clock.Phase.MORNING)) as Clock.Phase
	Clock.elapsed_in_phase = float(clock_data.get("elapsed_in_phase", 0.0))
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
	result["version"] = SAVE_VERSION
	return result


## v1 에는 room_grid 가 없다. 비워 두면 GameState.from_dict 가 시작 배치로 채운다.
func _migrate_1_to_2(data: Dictionary) -> void:
	var game_state: Dictionary = data.get("game_state", {})
	game_state.erase("room_grid")
	data["game_state"] = game_state
