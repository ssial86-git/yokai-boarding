class_name PlaytestLog
extends Node
## 플레이테스트 지표 로그 (M5): 주요 Events 를 JSON Lines 로 user://playtest/session_<시각>.jsonl 에 남긴다.
## tools/playtest/summarize.py 가 이 파일들을 읽어 Go/No-Go 표(docs/01 6절)를 만든다.
## 개인정보 없음 — 게임 상태와 시각만 기록. tuning.playtest_log_enabled 로 끈다.

const LOG_DIR := "user://playtest"
const FILE_FORMAT := "session_%d.jsonl"

var _file: FileAccess
var _started_msec: int = 0


func _ready() -> void:
	# headless(테스트·CI)에서는 세션 파일을 남기지 않는다 — 실제 플레이 로그만 집계 대상이다
	if not DataRegistry.tuning.get_bool("playtest_log_enabled", true) or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	_started_msec = Time.get_ticks_msec()
	_file = FileAccess.open(LOG_DIR.path_join(FILE_FORMAT % Time.get_unix_time_from_system()), FileAccess.WRITE)
	if _file == null:
		push_warning("PlaytestLog: 로그 파일을 열 수 없다 %s" % LOG_DIR)
		return
	record("session_start", {"version": ProjectSettings.get_setting("application/config/name", ""), "seed": GameState.rng.seed})
	Events.day_started.connect(func(day: int) -> void: record("day_started", {"beds_total": Lodging.total_beds(GameState.room_grid)}))
	Events.phase_changed.connect(func(phase: int, _day: int) -> void: record("phase", {"phase": _phase_name(phase)}))
	Events.assignment_changed.connect(func(yokai_id: String, cell: Vector2i) -> void:
		record("assignment", {"yokai": yokai_id, "cell": [cell.x, cell.y], "rest": cell == Assignment.REST}))
	Events.room_changed.connect(func(coords: Vector2i, room_id: String) -> void:
		record("room", {"cell": [coords.x, coords.y], "room": room_id, "money": GameState.money}))
	Events.floor_added.connect(func(floor: int) -> void: record("floor", {"floor": floor, "money": GameState.money}))
	Events.house_action_failed.connect(func(outcome: int) -> void:
		record("build_failed", {"outcome": RoomGrid.Outcome.keys()[outcome]}))
	Events.assignment_failed.connect(func(yokai_id: String, outcome: int) -> void:
		record("assign_failed", {"yokai": yokai_id, "outcome": AssignmentController.Outcome.keys()[outcome]}))
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


func record(kind: String, data: Dictionary = {}) -> void:
	if _file == null:
		return
	var line := {
		"t": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"day": GameState.day,
		"phase": _phase_name(Clock.phase),
		"kind": kind,
		"data": data,
	}
	_file.store_line(JSON.stringify(line))
	_file.flush()


func _exit_tree() -> void:
	if _file != null:
		record("session_end", {"money": GameState.money, "residents": GameState.residents.size()})
		_file.close()


func _phase_name(phase: int) -> String:
	return (Clock.Phase.keys()[phase] as String).to_lower()
