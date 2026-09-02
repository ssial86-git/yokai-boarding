extends Node
## 런타임 진행 상태의 단일 소유자. 규칙 계산은 src/core/ 순수 클래스가 하고
## 여기서는 상태를 들고 있다가 시그널로 알린다.

const START_LAYOUT_SEPARATOR := ","

var day: int = 1
var money: int = 0
var reputation: int = 0
## yokai_id -> affinity 값
var affinity: Dictionary = {}
## 입주 중인 하숙생 id 목록
var residents: Array[String] = []
## 하숙집 방 그리드. reset_new_game() 또는 from_dict() 전에는 null.
var room_grid: RoomGrid


func reset_new_game() -> void:
	day = 1
	money = DataRegistry.tuning.get_int("start_money")
	reputation = 0
	affinity.clear()
	residents.clear()
	room_grid = new_room_grid()
	_apply_start_layout(room_grid)


func add_money(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)


## DataRegistry 의 방 카탈로그·tuning 으로 빈 그리드를 만든다.
func new_room_grid() -> RoomGrid:
	var tuning := DataRegistry.tuning
	var grid := RoomGrid.new(DataRegistry.rooms, tuning.get_int("grid_floors"), tuning.get_int("grid_columns"))
	grid.configure_costs(
		tuning.get_int("floor_build_cost"),
		tuning.get_float("floor_build_cost_growth"),
		tuning.get_float("demolish_refund_ratio"),
	)
	return grid


func to_dict() -> Dictionary:
	return {
		"day": day,
		"money": money,
		"reputation": reputation,
		"affinity": affinity.duplicate(),
		"residents": residents.duplicate(),
		"room_grid": room_grid.to_dict() if room_grid != null else {},
	}


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다.
func from_dict(data: Dictionary) -> bool:
	var grid := new_room_grid()
	var grid_data: Variant = data.get("room_grid", {})
	if grid_data is Dictionary and not (grid_data as Dictionary).is_empty():
		if not grid.from_dict(grid_data as Dictionary):
			return false
	else:
		_apply_start_layout(grid)  # 그리드가 없는 구버전 세이브는 새 집으로 시작
	day = int(data.get("day", 1))
	money = int(data.get("money", 0))
	reputation = int(data.get("reputation", 0))
	affinity.clear()
	for yokai_id: Variant in (data.get("affinity", {}) as Dictionary):
		# JSON 은 정수를 float 으로 돌려주므로 호감도는 int 로 되돌린다
		affinity[str(yokai_id)] = int((data["affinity"] as Dictionary)[yokai_id])
	residents.clear()
	for entry: Variant in (data.get("residents", []) as Array):
		residents.append(str(entry))
	room_grid = grid
	return true


func _apply_start_layout(grid: RoomGrid) -> void:
	var ids: Array[String] = []
	for part: String in DataRegistry.tuning.get_string("start_layout_floor0").split(START_LAYOUT_SEPARATOR):
		ids.append(part.strip_edges())
	grid.apply_layout(0, ids)
