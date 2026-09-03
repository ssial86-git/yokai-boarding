class_name Assignment
extends RefCounted
## 아침 배치: 요괴 id -> 일할 칸 (또는 REST). 순수 로직.
## 정원(RoomData.capacity)과 일터 종류만 검증한다. 시간대 제한은 호출자(AssignmentController) 몫.

enum Outcome { OK, NOT_BUILT, NOT_WORKPLACE, FULL }

const REST := Vector2i(-1, -1)
## 일할 수 있는 방 종류. lodging 은 휴식 장소, empty 는 일터가 아니다.
const WORKPLACE_KINDS: Array[String] = ["production", "service", "gate", "storage"]

var _slots: Dictionary = {}  # yokai_id -> Vector2i (REST 는 저장하지 않음)


static func is_workplace(room: RoomData) -> bool:
	return room != null and room.capacity > 0 and WORKPLACE_KINDS.has(room.kind)


func get_cell(yokai_id: String) -> Vector2i:
	return _slots.get(yokai_id, REST)


func is_resting(yokai_id: String) -> bool:
	return not _slots.has(yokai_id)


func workers_at(cell: Vector2i) -> Array[String]:
	var result: Array[String] = []
	for yokai_id: String in _slots:
		if _slots[yokai_id] == cell:
			result.append(yokai_id)
	return result


func working_ids() -> Array[String]:
	var result: Array[String] = []
	for yokai_id: String in _slots:
		result.append(yokai_id)
	return result


func check(grid: RoomGrid, cell: Vector2i, yokai_id: String) -> Outcome:
	if not grid.is_in_bounds(cell) or not grid.is_floor_built(cell.y):
		return Outcome.NOT_BUILT
	var room := grid.get_room(cell)
	if not is_workplace(room):
		return Outcome.NOT_WORKPLACE
	if get_cell(yokai_id) == cell:
		return Outcome.OK
	if workers_at(cell).size() >= room.capacity:
		return Outcome.FULL
	return Outcome.OK


func assign(grid: RoomGrid, cell: Vector2i, yokai_id: String) -> Outcome:
	var outcome := check(grid, cell, yokai_id)
	if outcome == Outcome.OK:
		_slots[yokai_id] = cell
	return outcome


func rest(yokai_id: String) -> void:
	_slots.erase(yokai_id)


## 방이 바뀌거나 요괴가 떠난 뒤 무효해진 배치를 휴식으로 되돌린다. 되돌린 id 목록을 반환.
func prune(grid: RoomGrid, residents: Array[String]) -> Array[String]:
	var reset: Array[String] = []
	for yokai_id: String in _slots.keys():
		var cell: Vector2i = _slots[yokai_id]
		var valid := residents.has(yokai_id) and grid.is_in_bounds(cell) \
			and grid.is_floor_built(cell.y) and is_workplace(grid.get_room(cell))
		if valid:
			var others := workers_at(cell)
			others.erase(yokai_id)
			valid = others.size() < grid.get_room(cell).capacity
		if not valid:
			_slots.erase(yokai_id)
			reset.append(yokai_id)
	return reset


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for yokai_id: String in _slots:
		var cell: Vector2i = _slots[yokai_id]
		result[yokai_id] = [cell.x, cell.y]
	return result


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다. 방 규칙 검증은 이후 prune() 으로.
func from_dict(data: Dictionary) -> bool:
	var parsed: Dictionary = {}
	for key: Variant in data:
		var value: Variant = data[key]
		if not value is Array or (value as Array).size() != 2:
			return false
		var pair := value as Array
		if not ((pair[0] is int or pair[0] is float) and (pair[1] is int or pair[1] is float)):
			return false
		parsed[str(key)] = Vector2i(int(pair[0]), int(pair[1]))
	_slots = parsed
	return true
