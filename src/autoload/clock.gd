extends Node
## 하루 페이즈 진행. 페이즈 길이는 tuning.csv 의 phase_*_seconds 로 정한다.
## 길이가 0 이하이면 자동 진행하지 않고 advance_phase() 호출(플레이어 결정)을 기다린다.

enum Phase { MORNING, DAY, EVENING, NIGHT }

const PHASE_TUNING_KEYS: Dictionary = {
	Phase.MORNING: "phase_morning_seconds",
	Phase.DAY: "phase_day_seconds",
	Phase.EVENING: "phase_evening_seconds",
	Phase.NIGHT: "phase_night_seconds",
}

var phase: Phase = Phase.MORNING
var elapsed_in_phase: float = 0.0
var running: bool = false


func _process(delta: float) -> void:
	if not running:
		return
	var length := get_phase_length(phase)
	if length <= 0.0:
		return
	elapsed_in_phase += delta
	if elapsed_in_phase >= length:
		advance_phase()


func start_day() -> void:
	phase = Phase.MORNING
	elapsed_in_phase = 0.0
	running = true
	Events.day_started.emit(GameState.day)
	Events.phase_changed.emit(phase, GameState.day)


func advance_phase() -> void:
	elapsed_in_phase = 0.0
	if phase == Phase.NIGHT:
		_end_day()
		return
	phase = (phase + 1) as Phase
	Events.phase_changed.emit(phase, GameState.day)


func get_phase_length(target: Phase) -> float:
	return DataRegistry.tuning.get_float(PHASE_TUNING_KEYS[target])


func get_phase_progress() -> float:
	var length := get_phase_length(phase)
	if length <= 0.0:
		return 0.0
	return clampf(elapsed_in_phase / length, 0.0, 1.0)


func _end_day() -> void:
	running = false
	Events.day_ended.emit(GameState.day)
	GameState.day += 1
	start_day()
