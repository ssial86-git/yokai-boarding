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
## 절기 달력 (P2-S1). reset_new_game() 또는 from_dict() 전에는 빈 달력.
var calendar: Calendar = Calendar.new()
## 오늘의 음기 지수 0~3 (weather.csv 추첨). tuning yin_high_threshold 이상이면 '짙은 날'.
var yin: int = 0
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

const REGION_STATE_KEYS: Array[String] = ["visited", "gather_taken", "gather_materials", "enemies_defeated", "boss_defeated"]
const LIST_SEPARATOR := ";"
const COST_SEPARATOR := ":"

# --- P1-S2: 직접 조작 ---
var stamina: Stamina = Stamina.new()
var farm: Farm = Farm.new()
## 도구 갈래(hoe/axe/pickaxe/rod) -> 레벨. 없으면 그 갈래의 도구가 없다.
var tools: Dictionary = {}
## 열린 unlocks.csv id -> 열린 날
var unlocked: Dictionary = {}

# --- P1-S3: 요리·제작·버프 ---
const STATION_KITCHEN := "kitchen"
const STATION_WORKSHOP := "workshop"
const STATION_IDS: Array[String] = [STATION_KITCHEN, STATION_WORKSHOP]
## 작업대 id -> WorkStation (가마솥·작업장, 각각 작업 하나)
var stations: Dictionary = {}
## 오늘의 배식 버프: yokai_id -> {stat: amount}. 하루 시작에 비운다
var buffs: Dictionary = {}

# --- P2-S2: 목표·명절 ---
## 활동 카운터: "gather" / "cook.r_patjuk" 같은 키 -> 누계 (goals.csv 의 count: 절이 읽는다)
var counters: Dictionary = {}
## 완료한 목표 goal_id -> 완료한 날
var goals_done: Dictionary = {}
## 명절 채점 결과 festival_id -> 점수
var festival_results: Dictionary = {}


func reset_new_game() -> void:
	day = 1
	money = DataRegistry.tuning.get_int("start_money")
	reputation = 0
	affinity.clear()
	inventory = Inventory.new()
	assignment = Assignment.new()
	assignment.field_capacity = DataRegistry.tuning.get_int("field_workers_max")
	assignment.party_capacity = DataRegistry.tuning.get_int("party_max")
	guests.clear()
	ledger.clear()
	flags.clear()
	seen_events.clear()
	pending_visitor.clear()
	weather = WEATHER_CLEAR
	yin = 0
	calendar = Calendar.start(DataRegistry.seasons, DataRegistry.tuning.get_string("season_start_id"))
	_reset_player()
	region_states.clear()
	stamina = Stamina.new(Stamina.Params.from_tuning(DataRegistry.tuning))
	farm = Farm.new(DataRegistry.tuning.get_int("farm_plots_initial"))
	tools = _parse_levels(DataRegistry.tuning.get_string("start_tools"))
	unlocked.clear()
	_reset_stations()
	buffs.clear()
	counters.clear()
	goals_done.clear()
	festival_results.clear()
	var start_items := _parse_levels(DataRegistry.tuning.get_string("start_items"))
	for item_id: String in start_items:
		inventory.add(item_id, int(start_items[item_id]))
	_reseed_rng()
	room_grid = new_room_grid()
	_apply_start_layout(room_grid)
	residents = DataRegistry.starting_yokai_ids()
	conditions.clear()
	for yokai_id in residents:
		conditions[yokai_id] = DataRegistry.tuning.get_int("condition_max")


## 하루를 넘긴다 (취침 — Clock.sleep 만 부른다). 절기의 마지막 날을 넘기면 season_changed.
func advance_day() -> void:
	day += 1
	if calendar.advance_day():
		Events.season_changed.emit(calendar.season_id)


## 오늘이 음기 짙은 날인가 (마계 작물 가속·마계 손님↑·음기 조건 재료).
func is_yin_high() -> bool:
	return WeatherRoll.is_yin_high(yin, DataRegistry.tuning.get_int("yin_high_threshold"))


## 활동 카운터를 올리고 누계를 돌려준다 (GoalSystem 이 activity_done 마다 부른다).
func bump_counter(key: String, amount: int = 1) -> int:
	counters[key] = int(counters.get(key, 0)) + amount
	return int(counters[key])


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
		"yin": yin,
		"calendar": calendar.to_dict(),
		# JSON 은 64비트 정수를 double 로 바꿔 정밀도를 잃으므로 문자열로 보관
		"rng_state": str(rng.state),
		"room_grid": room_grid.to_dict() if room_grid != null else {},
		"player": {"region": player_region, "x": player_position.x, "y": player_position.y},
		"regions": region_states.duplicate(true),
		"stamina": stamina.to_dict(),
		"farm": farm.to_dict(),
		"tools": tools.duplicate(),
		"unlocked": unlocked.duplicate(),
		"stations": _stations_to_dict(),
		"buffs": buffs.duplicate(true),
		"counters": counters.duplicate(),
		"goals_done": goals_done.duplicate(),
		"festival_results": festival_results.duplicate(),
	}


func station(station_id: String) -> WorkStation:
	if not stations.has(station_id):
		stations[station_id] = WorkStation.new()
	return stations[station_id]


## 배식 버프를 더한 오늘의 능력치. stat 은 yokai.csv 의 stat_<name> 이름 (strength/skill/sight/courage).
func stat_of(yokai_id: String, stat: String) -> int:
	var yokai := DataRegistry.get_yokai(yokai_id)
	var base := int(yokai.get("stat_%s" % stat)) if yokai != null else 0
	var bonus := int((buffs.get(yokai_id, {}) as Dictionary).get(stat, 0))
	return base + bonus


func add_buff(yokai_id: String, stat: String, amount: int) -> void:
	var own: Dictionary = buffs.get(yokai_id, {})
	own[stat] = int(own.get(stat, 0)) + amount
	buffs[yokai_id] = own
	Events.buff_applied.emit(yokai_id, stat, int(own[stat]))


func _reset_stations() -> void:
	stations.clear()
	for station_id in STATION_IDS:
		stations[station_id] = WorkStation.new()


func _stations_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for station_id: String in stations:
		result[station_id] = (stations[station_id] as WorkStation).to_dict()
	return result


## 도구 갈래를 level 로 올린다 (내리지는 않는다). 올랐으면 true.
func set_tool_level(kind: String, level: int) -> bool:
	if int(tools.get(kind, 0)) >= level:
		return false
	tools[kind] = level
	Events.tool_changed.emit(kind, level)
	return true


func has_tool(kind: String, level: int = 1) -> bool:
	return int(tools.get(kind, 0)) >= level


## "a:1;b:3" -> {"a": 1, "b": 3}. tuning 의 start_tools / start_items 형식.
func _parse_levels(text: String) -> Dictionary:
	var result: Dictionary = {}
	for part in text.split(LIST_SEPARATOR, false):
		var pieces := part.strip_edges().split(COST_SEPARATOR)
		if pieces.size() == 2 and not pieces[0].is_empty():
			result[pieces[0]] = int(pieces[1])
	return result


## 구역 상태. 없으면 기본값으로 만들어 돌려준다 (반환값은 region_states 안의 그 Dictionary 자체).
func region_state(region_id: String) -> Dictionary:
	if not region_states.has(region_id):
		region_states[region_id] = {
			"visited": false, "gather_taken": [], "gather_materials": [], "enemies_defeated": [], "boss_defeated": false,
		}
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
	var materials: Array = []
	for entry: Variant in (raw.get("gather_materials", []) as Array):
		materials.append(str(entry))
	var defeated: Array = []
	for entry: Variant in (raw.get("enemies_defeated", []) as Array):
		defeated.append(str(entry))
	return {
		"visited": bool(raw.get("visited", false)),
		"gather_taken": gather,
		"gather_materials": materials,
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
	new_assignment.field_capacity = DataRegistry.tuning.get_int("field_workers_max")
	new_assignment.party_capacity = DataRegistry.tuning.get_int("party_max")
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
	yin = clampi(int(data.get("yin", 0)), WeatherRoll.YIN_MIN, WeatherRoll.YIN_MAX)
	var new_calendar := Calendar.new()
	var calendar_data: Variant = data.get("calendar", {})
	if calendar_data is Dictionary and not (calendar_data as Dictionary).is_empty():
		if not new_calendar.from_dict(calendar_data as Dictionary, DataRegistry.seasons):
			return false
	else:
		# v5 이전 세이브: 통산 일차에서 절기·날짜를 계산한다 (1일차 = 시작 절기 1일)
		new_calendar = Calendar.from_absolute_day(DataRegistry.seasons, DataRegistry.tuning.get_string("season_start_id"), day)
	calendar = new_calendar
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
	stamina = Stamina.new(Stamina.Params.from_tuning(DataRegistry.tuning))
	var stamina_data: Variant = data.get("stamina", {})
	if stamina_data is Dictionary and not (stamina_data as Dictionary).is_empty():
		if not stamina.from_dict(stamina_data as Dictionary):
			return false
	farm = Farm.new(DataRegistry.tuning.get_int("farm_plots_initial"))
	var farm_data: Variant = data.get("farm", {})
	if farm_data is Dictionary and not (farm_data as Dictionary).is_empty():
		if not farm.from_dict(farm_data as Dictionary):
			return false
		farm.expand(DataRegistry.tuning.get_int("farm_plots_initial"))
	tools = _int_dict(data.get("tools", {})) if data.has("tools") \
		else _parse_levels(DataRegistry.tuning.get_string("start_tools"))
	unlocked = _int_dict(data.get("unlocked", {}))
	_reset_stations()
	var stations_data: Variant = data.get("stations", {})
	if stations_data is Dictionary:
		for station_id: Variant in (stations_data as Dictionary):
			var raw: Variant = (stations_data as Dictionary)[station_id]
			if raw is Dictionary and not station(str(station_id)).from_dict(raw as Dictionary):
				return false
	buffs.clear()
	var buffs_data: Variant = data.get("buffs", {})
	if buffs_data is Dictionary:
		for yokai_id: Variant in (buffs_data as Dictionary):
			var raw: Variant = (buffs_data as Dictionary)[yokai_id]
			if raw is Dictionary:
				buffs[str(yokai_id)] = _int_dict(raw as Dictionary)
	counters = _int_dict(data.get("counters", {}))
	goals_done = _int_dict(data.get("goals_done", {}))
	festival_results = _int_dict(data.get("festival_results", {}))
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
