extends Node
## JSON 한 파일 세이브. 스키마 변경 시 SAVE_VERSION 을 올리고 _migrate() 에 단계를 추가한다.
## 방 그리드·요괴 상태·인벤토리·이벤트 로그 직렬화는 해당 시스템이 생기는 마일스톤에서 붙인다.

const SAVE_VERSION := 1
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
	GameState.from_dict(migrated.get("game_state", {}))
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


## 구버전 데이터를 현재 스키마로 올린다. 실패하면 빈 Dictionary.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION or version < 1:
		push_error("SaveManager: 지원하지 않는 세이브 버전 %d" % version)
		return {}
	var result := data.duplicate(true)
	# version 1 -> 2 마이그레이션은 여기에 추가한다.
	result["version"] = SAVE_VERSION
	return result
