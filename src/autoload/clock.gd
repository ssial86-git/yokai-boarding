extends Node
## 실시간 하루 (docs/08 재미 원칙 2). 하루 길이·시각 경계는 tuning.csv(day_length_seconds, clock_*_hour, timeband_*_hour).
## 시간대(아침/낮/저녁/밤)는 timeband_changed 로 알리는 트리거일 뿐이고, 하루를 끝내는 강제 컷은 취침(sleep)뿐이다.
## 대화·심사가 열려 있는 동안은 hold() 로 시간을 멈춘다 — 플레이어가 읽는 동안 하루가 새지 않도록.

enum Band { MORNING, DAY, EVENING, NIGHT }

const HOLD_DIALOGUE := &"dialogue"
const HOLD_INTAKE := &"intake"

var timeline: DayTimeline = DayTimeline.new()
var running: bool = false
## 현재 시간대 (Band). 시각에서 계산되므로 직접 바꿀 수 없다 — 바꾸려면 advance_to_band / restore.
var band: int:
	get:
		return timeline.band()
var _holds: Dictionary = {}


func _ready() -> void:
	timeline = DayTimeline.from_tuning(DataRegistry.tuning)
	Events.dialogue_started.connect(func(_event_id: String) -> void: hold(HOLD_DIALOGUE))
	Events.dialogue_finished.connect(func(_event_id: String) -> void: release(HOLD_DIALOGUE))
	Events.visitor_knocked.connect(func(visitor: Dictionary) -> void:
		if not visitor.is_empty():
			hold(HOLD_INTAKE))
	Events.intake_decided.connect(func(_visitor: Dictionary, _outcome: int) -> void: release(HOLD_INTAKE))


func _process(delta: float) -> void:
	if not running or is_held():
		return
	_tick(delta)


func band_name() -> String:
	return DayTimeline.band_name(band)


func get_hour() -> float:
	return timeline.hour()


func format_hour() -> String:
	return timeline.format_hour()


func get_day_progress() -> float:
	return timeline.progress()


func elapsed_seconds() -> float:
	return timeline.elapsed_seconds


func start_day() -> void:
	timeline.reset()
	running = true
	Events.day_started.emit(GameState.day)
	Events.timeband_changed.emit(band, GameState.day)


## 취침 = 하루의 유일한 강제 컷. forced 는 시계가 다 흘러 자동으로 잠든 경우.
func sleep(forced: bool = false) -> void:
	running = false
	Events.slept.emit(GameState.day, forced)
	Events.day_ended.emit(GameState.day)
	GameState.day += 1
	start_day()


func can_sleep() -> bool:
	return get_hour() >= DataRegistry.tuning.get_float("sleep_earliest_hour", 0.0)


## 시간을 멈추는 이유를 쌓는다. 같은 이유는 한 번만 센다.
func hold(reason: StringName) -> void:
	_holds[reason] = true


func release(reason: StringName) -> void:
	_holds.erase(reason)


func is_held() -> bool:
	return not _holds.is_empty()


## 테스트·디버그용 — hold 를 무시하고 시간을 건너뛴다. 하루 끝에 닿으면 강제 취침.
func advance_seconds(seconds: float) -> void:
	_tick(seconds)


## 목표 시간대의 시작 시각까지 건너뛴다. 이미 지났으면 아무것도 하지 않는다.
func advance_to_band(target: int) -> void:
	var goal := timeline.seconds_for_band(target)
	if goal > timeline.elapsed_seconds:
		advance_seconds(goal - timeline.elapsed_seconds)


## 세이브 복원. 시각을 되돌린 뒤 시간대를 한 번 알려 조명·등불이 맞춰지게 한다.
func restore(elapsed: float) -> void:
	timeline.elapsed_seconds = clampf(elapsed, 0.0, timeline.day_length_seconds)
	running = true
	Events.timeband_changed.emit(band, GameState.day)


func _tick(delta: float) -> void:
	for crossed in timeline.advance(delta):
		Events.timeband_changed.emit(crossed, GameState.day)
	if timeline.is_over():
		sleep(true)
