class_name Calendar
extends RefCounted
## 절기 달력 순수 로직 (P2-S1): 4절기 × 28일. seasons.csv 카탈로그에서 길이·다음 절기를 읽고 하루가 끝날 때 날짜를 올린다.
## 소절기 이벤트(season_events.csv)의 활성 판정·배율도 여기서. 노드·씬 의존 없음.

const DEFAULT_LENGTH := 28

var season_id: String = ""
var day_of_season: int = 1
var _catalog: Dictionary = {}


static func start(catalog: Dictionary, start_id: String) -> Calendar:
	var calendar := Calendar.new()
	calendar._catalog = catalog
	calendar.season_id = start_id if catalog.has(start_id) else _first_id(catalog)
	calendar.day_of_season = 1
	return calendar


## 통산 일차에서 달력을 만든다 (세이브 v5 → v6 마이그레이션: 1일차 = 시작 절기 1일).
static func from_absolute_day(catalog: Dictionary, start_id: String, day: int) -> Calendar:
	var calendar := start(catalog, start_id)
	for _i in maxi(day - 1, 0):
		calendar.advance_day()
	return calendar


func season() -> SeasonData:
	return _catalog.get(season_id) as SeasonData


func season_name() -> String:
	var data := season()
	return data.name_ko if data != null else season_id


func length() -> int:
	var data := season()
	return data.length_days if data != null and data.length_days > 0 else DEFAULT_LENGTH


func days_left() -> int:
	return length() - day_of_season


## 하루를 넘긴다. 절기가 바뀌면 true.
func advance_day() -> bool:
	day_of_season += 1
	if day_of_season <= length():
		return false
	day_of_season = 1
	var data := season()
	if data != null and _catalog.has(data.next_id):
		season_id = data.next_id
	return true


## 이 절기의 소절기 이벤트를 시작 날, id 순으로.
func events_in_season(events_catalog: Dictionary) -> Array[SeasonEventData]:
	var result: Array[SeasonEventData] = []
	for event: SeasonEventData in events_catalog.values():
		if event.season == season_id:
			result.append(event)
	result.sort_custom(func(a: SeasonEventData, b: SeasonEventData) -> bool:
		if a.day_of_season != b.day_of_season:
			return a.day_of_season < b.day_of_season
		return a.id < b.id)
	return result


## 절기 안 날짜 day 에 진행 중인 이벤트. day 를 비우면(-1) 오늘.
func events_on(events_catalog: Dictionary, day: int = -1) -> Array[SeasonEventData]:
	var target := day_of_season if day < 0 else day
	var result: Array[SeasonEventData] = []
	for event in events_in_season(events_catalog):
		if target >= event.day_of_season and target < event.day_of_season + maxi(event.duration_days, 1):
			result.append(event)
	return result


## 오늘 시작하는 이벤트 (알림용).
func events_starting_today(events_catalog: Dictionary) -> Array[SeasonEventData]:
	var result: Array[SeasonEventData] = []
	for event in events_on(events_catalog):
		if event.day_of_season == day_of_season:
			result.append(event)
	return result


## 오늘 이벤트의 날씨 고정 id. 없으면 빈 문자열 (여럿이면 늦게 시작한 것).
func weather_override(events_catalog: Dictionary) -> String:
	var result := ""
	for event in events_on(events_catalog):
		if not event.weather_override.is_empty():
			result = event.weather_override
	return result


func demon_guest_multiplier(events_catalog: Dictionary) -> float:
	var result := 1.0
	for event in events_on(events_catalog):
		result *= event.demon_guest_multiplier
	return result


func gather_multiplier(events_catalog: Dictionary) -> float:
	var result := 1.0
	for event in events_on(events_catalog):
		result *= event.gather_multiplier
	return result


func to_dict() -> Dictionary:
	return {"season": season_id, "day_of_season": day_of_season}


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다. JSON 을 거친 float 날짜를 int 로 되돌린다.
func from_dict(data: Dictionary, catalog: Dictionary) -> bool:
	var id := str(data.get("season", ""))
	if not catalog.has(id):
		return false
	_catalog = catalog
	season_id = id
	day_of_season = clampi(int(data.get("day_of_season", 1)), 1, length())
	return true


static func _first_id(catalog: Dictionary) -> String:
	var best: SeasonData = null
	for data: SeasonData in catalog.values():
		if best == null or data.order < best.order:
			best = data
	return best.id if best != null else ""
