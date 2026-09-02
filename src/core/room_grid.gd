class_name RoomGrid
extends RefCounted
## 하숙집 방 슬롯 그리드 (층 × 칸). 순수 로직 — 노드·씬·DataRegistry 에 의존하지 않는다.
## 좌표는 Vector2i(column, floor). floor 0 이 1층(맨 아래).
## 돈은 그리드 상태가 아니므로 인자로 받아 검증만 하고, 차감은 호출자(HouseController)가 한다.

enum Outcome {
	OK,
	OUT_OF_BOUNDS,
	FLOOR_LOCKED,
	UNKNOWN_ROOM,
	SAME_ROOM,
	ALREADY_EMPTY,
	CANNOT_PLACE_EMPTY,
	REQUIREMENT_MISSING,
	REQUIRED_BY_OTHER,
	INSUFFICIENT_FUNDS,
	MAX_FLOORS_REACHED,
}

const ROOM_KIND_EMPTY := "empty"

var floors: int
var columns: int
var built_floors: int = 1
var floor_build_cost: int = 0
var floor_build_cost_growth: float = 1.0
var demolish_refund_ratio: float = 0.0

var _catalog: Dictionary = {}  # room_id -> RoomData
var _empty_room_id: String = ""
var _cells: Array[String] = []  # index = floor * columns + column. "" = 잠긴 층


func _init(catalog: Dictionary, floor_count: int, column_count: int) -> void:
	_catalog = catalog
	floors = floor_count
	columns = column_count
	for room: RoomData in catalog.values():
		if room.kind == ROOM_KIND_EMPTY:
			_empty_room_id = room.id
			break
	assert(not _empty_room_id.is_empty(), "RoomGrid: kind=empty 인 방이 카탈로그에 없다")
	_cells.resize(floors * columns)
	for column in columns:
		_cells[_index(Vector2i(column, 0))] = _empty_room_id


func configure_costs(floor_cost: int, growth: float, refund_ratio: float) -> void:
	floor_build_cost = floor_cost
	floor_build_cost_growth = growth
	demolish_refund_ratio = refund_ratio


# --- 조회 ---

func get_empty_room_id() -> String:
	return _empty_room_id


func is_in_bounds(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < columns and coords.y >= 0 and coords.y < floors


func is_floor_built(floor: int) -> bool:
	return floor >= 0 and floor < built_floors


func get_room_id(coords: Vector2i) -> String:
	if not is_in_bounds(coords):
		return ""
	return _cells[_index(coords)]


func get_room(coords: Vector2i) -> RoomData:
	return _catalog.get(get_room_id(coords)) as RoomData


func is_empty(coords: Vector2i) -> bool:
	return get_room_id(coords) == _empty_room_id


func count_rooms(room_id: String, exclude: Vector2i = Vector2i(-1, -1)) -> int:
	var count := 0
	for floor in built_floors:
		for column in columns:
			var coords := Vector2i(column, floor)
			if coords != exclude and _cells[_index(coords)] == room_id:
				count += 1
	return count


func get_built_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for floor in built_floors:
		for column in columns:
			result.append(Vector2i(column, floor))
	return result


# --- 비용 ---

func get_place_cost(room_id: String) -> int:
	var room := _catalog.get(room_id) as RoomData
	return room.build_cost if room != null else 0


func get_demolish_refund(coords: Vector2i) -> int:
	var room := get_room(coords)
	if room == null or room.id == _empty_room_id:
		return 0
	return int(floor(room.build_cost * demolish_refund_ratio))


func get_next_floor_cost() -> int:
	return roundi(floor_build_cost * pow(floor_build_cost_growth, built_floors - 1))


# --- 설치·개조 ---

func check_place(coords: Vector2i, room_id: String, money: int) -> Outcome:
	if not is_in_bounds(coords):
		return Outcome.OUT_OF_BOUNDS
	if not is_floor_built(coords.y):
		return Outcome.FLOOR_LOCKED
	var target := _catalog.get(room_id) as RoomData
	if target == null:
		return Outcome.UNKNOWN_ROOM
	if room_id == _empty_room_id:
		return Outcome.CANNOT_PLACE_EMPTY
	var current_id := get_room_id(coords)
	if current_id == room_id:
		return Outcome.SAME_ROOM
	if not target.requires_room.is_empty() and count_rooms(target.requires_room, coords) == 0:
		return Outcome.REQUIREMENT_MISSING
	if current_id != _empty_room_id and _is_required_by_other(coords):
		return Outcome.REQUIRED_BY_OTHER
	if money < target.build_cost:
		return Outcome.INSUFFICIENT_FUNDS
	return Outcome.OK


## 빈터면 설치, 다른 방이면 개조. 성공 시 그리드가 바뀐다. 비용 차감은 호출자 몫.
func place_room(coords: Vector2i, room_id: String, money: int) -> Outcome:
	var outcome := check_place(coords, room_id, money)
	if outcome == Outcome.OK:
		_cells[_index(coords)] = room_id
	return outcome


# --- 철거 ---

func check_demolish(coords: Vector2i) -> Outcome:
	if not is_in_bounds(coords):
		return Outcome.OUT_OF_BOUNDS
	if not is_floor_built(coords.y):
		return Outcome.FLOOR_LOCKED
	if is_empty(coords):
		return Outcome.ALREADY_EMPTY
	if _is_required_by_other(coords):
		return Outcome.REQUIRED_BY_OTHER
	return Outcome.OK


## 성공 시 빈터로 되돌린다. 환불액은 미리 get_demolish_refund 로 구한다.
func demolish_room(coords: Vector2i) -> Outcome:
	var outcome := check_demolish(coords)
	if outcome == Outcome.OK:
		_cells[_index(coords)] = _empty_room_id
	return outcome


# --- 증축 (층 추가) ---

func check_add_floor(money: int) -> Outcome:
	if built_floors >= floors:
		return Outcome.MAX_FLOORS_REACHED
	if money < get_next_floor_cost():
		return Outcome.INSUFFICIENT_FUNDS
	return Outcome.OK


func add_floor(money: int) -> Outcome:
	var outcome := check_add_floor(money)
	if outcome == Outcome.OK:
		for column in columns:
			_cells[_index(Vector2i(column, built_floors))] = _empty_room_id
		built_floors += 1
	return outcome


## 시작 배치 등, 규칙 검증 없이 한 층을 통째로 채운다. 알 수 없는 id 는 빈터로 둔다.
func apply_layout(floor: int, room_ids: Array[String]) -> void:
	if not is_floor_built(floor):
		return
	for column in columns:
		var room_id := room_ids[column] if column < room_ids.size() else _empty_room_id
		if not _catalog.has(room_id):
			room_id = _empty_room_id
		_cells[_index(Vector2i(column, floor))] = room_id


# --- 직렬화 ---

func to_dict() -> Dictionary:
	return {
		"floors": floors,
		"columns": columns,
		"built_floors": built_floors,
		"cells": _cells.duplicate(),
	}


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다.
func from_dict(data: Dictionary) -> bool:
	if int(data.get("floors", -1)) != floors or int(data.get("columns", -1)) != columns:
		return false
	var new_built := int(data.get("built_floors", 0))
	if new_built < 1 or new_built > floors:
		return false
	var raw_cells: Variant = data.get("cells")
	if not raw_cells is Array or (raw_cells as Array).size() != floors * columns:
		return false
	var new_cells: Array[String] = []
	for i in floors * columns:
		var room_id := str((raw_cells as Array)[i])
		var floor_index := i / columns
		if floor_index < new_built:
			if not _catalog.has(room_id):
				return false
		elif not room_id.is_empty():
			return false
		new_cells.append(room_id)
	built_floors = new_built
	_cells = new_cells
	return true


# --- 내부 ---

func _index(coords: Vector2i) -> int:
	return coords.y * columns + coords.x


func _is_required_by_other(coords: Vector2i) -> bool:
	var room_id := get_room_id(coords)
	if count_rooms(room_id, coords) > 0:
		return false  # 같은 방이 또 있으면 이 칸은 필수가 아니다
	for floor in built_floors:
		for column in columns:
			var other := Vector2i(column, floor)
			if other == coords:
				continue
			var other_room := get_room(other)
			if other_room != null and other_room.requires_room == room_id:
				return true
	return false
