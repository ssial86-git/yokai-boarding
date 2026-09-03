extends Node
## 내장 지표 (docs/08 7절 게이트 계측, docs/01 v3 2.2 "지표 킷 내장 전환").
## metrics_events.csv 에 정의된 이벤트만, 정의된 필드만 JSON Lines 로 user://metrics/session_<시각>.jsonl 에 남긴다.
## 한 줄: {"t": 세션 경과 초, "day", "timeband", "kind", "data"}. tools/playtest/summarize.py 가 읽는다.
## 개인정보 없음 — 게임 상태와 시각만. tuning metrics_enabled 로 끈다.
## headless(테스트·CI)에서는 파일을 열지 않되 open_session() 으로 강제할 수 있다 (스모크 테스트가 이 경로로 검증).

const LOG_DIR := "user://metrics"
const FILE_FORMAT := "session_%d.jsonl"
const CATEGORY_VERB := "verb"

var _file: FileAccess
var _started_msec: int = 0
## kind -> 세션 중 기록 횟수 (파일 유무와 무관. 테스트·디버그용)
var _counts: Dictionary = {}
## 오늘 쓴 동사 집합 (verb 카테고리 이벤트의 verb 필드 또는 kind). day_ended.activities 가 된다 — P1 게이트 "하루 4개 이상".
var _verbs_today: Dictionary = {}


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	_connect_events()
	if DataRegistry.tuning.get_bool("metrics_enabled", true) and DisplayServer.get_name() != "headless":
		open_session(LOG_DIR.path_join(FILE_FORMAT % Time.get_unix_time_from_system()))


func _exit_tree() -> void:
	close_session()


func is_open() -> bool:
	return _file != null


func count(kind: String) -> int:
	return int(_counts.get(kind, 0))


func activities_today() -> int:
	return _verbs_today.size()


## 파일을 열고 session_start 를 남긴다. 이미 열려 있으면 먼저 닫는다.
func open_session(path: String) -> Error:
	close_session()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("Metrics: 로그 파일을 열 수 없다 %s" % path)
		return FileAccess.get_open_error()
	record("session_start", {"version": ProjectSettings.get_setting("application/config/name", ""), "seed": GameState.rng.seed})
	return OK


func close_session() -> void:
	if _file == null:
		return
	record("session_end", {"money": GameState.money, "residents": GameState.residents.size()})
	_file.close()
	_file = null


## 정의(metrics_events.csv)에 없는 kind 나 필드는 기록하지 않고 오류를 낸다 — 지표 누락을 스키마 단계에서 잡기 위해.
func record(kind: String, data: Dictionary = {}) -> void:
	var definition := DataRegistry.get_metrics_event(kind)
	if definition == null:
		push_error("Metrics: metrics_events.csv 에 없는 이벤트 %s" % kind)
		return
	for key: Variant in data:
		if not definition.fields.has(str(key)):
			push_error("Metrics: 이벤트 %s 에 정의되지 않은 필드 %s" % [kind, key])
			return
	_counts[kind] = count(kind) + 1
	if definition.category == CATEGORY_VERB:
		_verbs_today[str(data.get("verb", kind))] = true
	if _file == null:
		return
	_file.store_line(JSON.stringify({
		"t": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"day": GameState.day,
		"timeband": Clock.band_name(),
		"kind": kind,
		"data": data,
	}))
	_file.flush()


func _connect_events() -> void:
	Events.day_started.connect(func(day: int) -> void:
		_verbs_today.clear()
		record("day_started", {"day": day, "beds_total": Lodging.total_beds(GameState.room_grid)}))
	Events.slept.connect(func(day: int, forced: bool) -> void:
		record("sleep", {"day": day, "hour": Clock.get_hour(), "forced": forced}))
	Events.day_ended.connect(func(day: int) -> void: record("day_ended", {"day": day, "activities": activities_today()}))
	Events.timeband_changed.connect(func(band: int, _day: int) -> void: record("timeband", {"timeband": DayTimeline.band_name(band)}))
	Events.assignment_changed.connect(func(yokai_id: String, cell: Vector2i) -> void:
		record("assignment", {"yokai": yokai_id, "cell": [cell.x, cell.y], "rest": cell == Assignment.REST}))
	Events.assignment_failed.connect(func(yokai_id: String, outcome: int) -> void:
		record("assign_failed", {"yokai": yokai_id, "outcome": AssignmentController.Outcome.keys()[outcome]}))
	Events.room_changed.connect(func(coords: Vector2i, room_id: String) -> void:
		record("room", {"cell": [coords.x, coords.y], "room": room_id, "money": GameState.money}))
	Events.floor_added.connect(func(floor: int) -> void: record("floor", {"floor": floor, "money": GameState.money}))
	Events.house_action_failed.connect(func(outcome: int) -> void:
		record("build_failed", {"outcome": RoomGrid.Outcome.keys()[outcome]}))
	Events.day_settled.connect(func(summary: Dictionary) -> void:
		record("settled", {"totals": summary.get("totals", {}), "rent_money": summary.get("rent", {}).get("money", 0), "money": GameState.money}))
	Events.visitor_knocked.connect(func(visitor: Dictionary) -> void:
		record("visitor", {"kind": visitor.get("kind", ""), "species": visitor.get("species_id", ""),
			"free_beds": Lodging.free_beds(GameState.room_grid, GameState.residents, GameState.guests)}))
	Events.intake_decided.connect(func(visitor: Dictionary, outcome: int) -> void:
		record("intake", {"kind": visitor.get("kind", ""), "species": visitor.get("species_id", ""),
			"outcome": Intake.Outcome.keys()[outcome]}))
	Events.dialogue_started.connect(func(event_id: String) -> void: record("dialogue", {"event": event_id}))
	Events.affinity_changed.connect(func(yokai_id: String, value: int) -> void:
		record("affinity", {"yokai": yokai_id, "value": value}))
	Events.yokai_arrived.connect(func(yokai_id: String) -> void: record("resident", {"yokai": yokai_id}))
	Events.game_saved.connect(func(slot: int) -> void: record("save", {"slot": slot}))
	Events.game_loaded.connect(func(slot: int) -> void: record("load", {"slot": slot}))
