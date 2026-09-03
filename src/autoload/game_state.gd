extends Node
## 런타임 진행 상태의 단일 소유자. 규칙 계산은 src/core/ 순수 클래스가 하고
## 여기서는 상태를 들고 있다가 시그널로 알린다.

const START_LAYOUT_SEPARATOR := ","
const WEATHER_CLEAR := "clear"

var day: int = 1
var money: int = 0
var reputation: int = 0
## yokai_id -> affinity 값
var affinity: Dictionary = {}
## 입주 중인 하숙생 id 목록
var residents: Array[String] = []
## yokai_id -> 컨디션 (0..condition_max)
var conditions: Dictionary = {}
var inventory: Inventory = Inventory.new()
var assignment: Assignment = Assignment.new()
## 체류 중인 뜨내기 손님 레코드 (Intake.Result.guest 형식)
var guests: Array[Dictionary] = []
## 손님 명부: species_id -> 방문 횟수
var ledger: Dictionary = {}
## 서사 플래그: name -> true
var flags: Dictionary = {}
## 본 이벤트 id 목록 (once 판정)
var seen_events: Array[String] = []
## 심사 대기 중인 방문자 (VisitorRoll.Visitor.to_dict 형식). 없으면 빈 Dictionary.
var pending_visitor: Dictionary = {}
var weather: String = WEATHER_CLEAR
## 방문자·하숙비 추첨용 RNG. 상태를 세이브해 로드 후에도 같은 순서가 이어진다.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 하숙집 방 그리드. reset_new_game() 또는 from_dict() 전에는 null.
var room_grid: RoomGrid
## 플레이어가 있는 구역(regions.csv id)과 그 안의 위치 (세이브 v5). 새 게임은 tuning player_start_*.
var player_region: String = ""
var player_position: Vector2 = Vector2.ZERO
## 탐험지 상태: region_id -> {"visited": bool, "gather_taken": [point_id], "enemies_defeated": [enemy_id], "boss_defeated": bool}
## JSON 왕복이 값을 바꾸지 않도록 bool·문자열·문자열 목록만 넣는다 (정수는 float 으로 돌아온다).
var region_states: Dictionary = {}

const REGION_STATE_KEYS: Array[String] = ["visited", "gather_taken", "enemies_defeated", "boss_defeated"]


func reset_new_game() -> void:
	day = 1
	money = DataRegistry.tuning.get_int("start_money")
	reputation = 0
	affinity.clear()
	inventory = Inventory.new()
	assignment = Assignment.new()
	guests.clear()
	ledger.clear()
	flags.clear()
	seen_events.clear()
	pending_visitor.clear()
	weather = WEATHER_CLEAR
	_reset_player()
	region_states.clear()
	_reseed_rng()
	room_grid = new_room_grid()
	_apply_start_layout(room_grid)
	residents = DataRegistry.starting_yokai_ids()
	conditions.clear()
	for yokai_id in residents:
		conditions[yokai_id] = DataRegistry.tuning.get_int("condition_max")


func add_money(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)


func add_reputation(delta: int) -> void:
	if delta == 0:
		return
	reputation += delta
	Events.reputation_changed.emit(reputation)


func get_condition(yokai_id: String) -> int:
	return int(conditions.get(yokai_id, DataRegistry.tuning.get_int("condition_max")))


func add_affinity(yokai_id: String, delta: int) -> void:
	affinity[yokai_id] = int(affinity.get(yokai_id, 0)) + delta
	Events.affinity_changed.emit(yokai_id, int(affinity[yokai_id]))


## 심사를 통과한 하숙생 입주.
func add_resident(yokai_id: String) -> void:
	if residents.has(yokai_id):
		return
	residents.append(yokai_id)
	conditions[yokai_id] = DataRegistry.tuning.get_int("condition_max")
	if not affinity.has(yokai_id):
		affinity[yokai_id] = 0
	Events.yokai_arrived.emit(yokai_id)


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
		"conditions": conditions.duplicate(),
		"inventory": inventory.to_dict(),
		"assignment": assignment.to_dict(),
		"guests": guests.duplicate(true),
		"ledger": ledger.duplicate(),
		"flags": flags.duplicate(),
		"seen_events": seen_events.duplicate(),
		"pending_visitor": pending_visitor.duplicate(),
		"weather": weather,
		# JSON 은 64비트 정수를 double 로 바꿔 정밀도를 잃으므로 문자열로 보관
		"rng_state": str(rng.state),
		"room_grid": room_grid.to_dict() if room_grid != null else {},
		"player": {"region": player_region, "x": player_position.x, "y": player_position.y},
		"regions": region_states.duplicate(true),
	}


## 구역 상태. 없으면 기본값으로 만들어 돌려준다 (반환값은 region_states 안의 그 Dictionary 자체).
func region_state(region_id: String) -> Dictionary:
	if not region_states.has(region_id):
		region_states[region_id] = {"visited": false, "gather_taken": [], "enemies_defeated": [], "boss_defeated": false}
	return region_states[region_id]


func set_player_location(region_id: String, position: Vector2) -> void:
	player_region = region_id
	player_position = position
	region_state(region_id)["visited"] = true


func _reset_player() -> void:
	var tuning := DataRegistry.tuning
	player_region = tuning.get_string("player_start_region")
	player_position = Vector2(tuning.get_float("player_start_x"), tuning.get_float("player_start_y"))


## 세이브의 구역 상태 하나를 검사·정규화한다. 형식이 틀리면 빈 Dictionary.
func _region_state_from(source: Variant) -> Dictionary:
	if not source is Dictionary:
		return {}
	var raw := source as Dictionary
	var gather: Array = []
	for entry: Variant in (raw.get("gather_taken", []) as Array):
		gather.append(str(entry))
	var defeated: Array = []
	for entry: Variant in (raw.get("enemies_defeated", []) as Array):
		defeated.append(str(entry))
	return {
		"visited": bool(raw.get("visited", false)),
		"gather_taken": gather,
		"enemies_defeated": defeated,
		"boss_defeated": bool(raw.get("boss_defeated", false)),
	}


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다.
## 빠진 키는 새 게임 기본값으로 채운다 (구버전 세이브 마이그레이션의 마지막 단계).
func from_dict(data: Dictionary) -> bool:
	var grid := new_room_grid()
	var grid_data: Variant = data.get("room_grid", {})
	if grid_data is Dictionary and not (grid_data as Dictionary).is_empty():
		if not grid.from_dict(grid_data as Dictionary):
			return false
	else:
		_apply_start_layout(grid)
	var new_inventory := Inventory.new()
	if not new_inventory.from_dict(data.get("inventory", {})):
		return false
	var new_assignment := Assignment.new()
	if not new_assignment.from_dict(data.get("assignment", {})):
		return false

	day = int(data.get("day", 1))
	money = int(data.get("money", 0))
	reputation = int(data.get("reputation", 0))
	affinity = _int_dict(data.get("affinity", {}))
	residents.clear()
	for entry: Variant in (data.get("residents", []) as Array):
		residents.append(str(entry))
	if not data.has("residents"):
		residents = DataRegistry.starting_yokai_ids()
	conditions = _int_dict(data.get("conditions", {}))
	for yokai_id in residents:
		if not conditions.has(yokai_id):
			conditions[yokai_id] = DataRegistry.tuning.get_int("condition_max")
	inventory = new_inventory
	assignment = new_assignment
	assignment.prune(grid, residents)
	guests.clear()
	for entry: Variant in (data.get("guests", []) as Array):
		if entry is Dictionary:
			guests.append(_int_dict_keep_strings(entry as Dictionary))
	ledger = _int_dict(data.get("ledger", {}))
	flags = (data.get("flags", {}) as Dictionary).duplicate()
	seen_events.clear()
	for entry: Variant in (data.get("seen_events", []) as Array):
		seen_events.append(str(entry))
	var raw_visitor: Dictionary = data.get("pending_visitor", {})
	# JSON 을 거친 float 값(omen) 을 int 로 되돌리기 위해 Visitor 로 한 번 감쌌다 푼다
	pending_visitor = VisitorRoll.Visitor.from_dict(raw_visitor).to_dict() if not raw_visitor.is_empty() else {}
	weather = str(data.get("weather", WEATHER_CLEAR))
	var player: Variant = data.get("player", {})
	if player is Dictionary and not (player as Dictionary).is_empty():
		var player_data := player as Dictionary
		player_region = str(player_data.get("region", ""))
		player_position = Vector2(float(player_data.get("x", 0.0)), float(player_data.get("y", 0.0)))
	else:
		_reset_player()
	region_states.clear()
	var regions: Variant = data.get("regions", {})
	if regions is Dictionary:
		for region_id: Variant in (regions as Dictionary):
			var state := _region_state_from((regions as Dictionary)[region_id])
			if not state.is_empty():
				region_states[str(region_id)] = state
	if data.has("rng_state"):
		rng.state = str(data["rng_state"]).to_int()
	else:
		_reseed_rng()
	room_grid = grid
	return true


## JSON 은 정수를 float 으로 돌려주므로 값을 int 로 되돌린다.
func _int_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[str(key)] = int(source[key])
	return result


func _int_dict_keep_strings(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		var value: Variant = source[key]
		result[str(key)] = int(value) if value is float else value
	return result


func _reseed_rng() -> void:
	var seed := DataRegistry.tuning.get_int("visitor_seed")
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed


func _apply_start_layout(grid: RoomGrid) -> void:
	var ids: Array[String] = []
	for part: String in DataRegistry.tuning.get_string("start_layout_floor0").split(START_LAYOUT_SEPARATOR):
		ids.append(part.strip_edges())
	grid.apply_layout(0, ids)
