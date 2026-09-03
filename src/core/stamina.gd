class_name Stamina
extends RefCounted
## 스태미너 예산 (docs/08 재미 원칙 2). 0 이 되어도 행동을 막지 않고 느려질 뿐이다 (docs/01 v3 2.1: 강제 기절 없음).
## 수치는 전부 tuning(stamina_*). 순수 로직 — 소모·회복 규칙만 갖는다.


class Params:
	extends RefCounted
	var max_value: float = 100.0
	var run_drain_per_second: float = 8.0
	var regen_per_second: float = 4.0
	## 0 일 때 이동·작업 속도 배율
	var exhausted_multiplier: float = 0.5
	var low_threshold: float = 20.0

	static func from_tuning(tuning: TuningData) -> Params:
		var params := Params.new()
		params.max_value = tuning.get_float("stamina_max", params.max_value)
		params.run_drain_per_second = tuning.get_float("stamina_run_drain_per_second", params.run_drain_per_second)
		params.regen_per_second = tuning.get_float("stamina_regen_per_second", params.regen_per_second)
		params.exhausted_multiplier = tuning.get_float("stamina_exhausted_multiplier", params.exhausted_multiplier)
		params.low_threshold = tuning.get_float("stamina_low_threshold", params.low_threshold)
		return params


var params: Params
var value: float


func _init(initial_params: Params = Params.new()) -> void:
	params = initial_params
	value = params.max_value


## 행동 비용. 모자라도 0 까지 깎고 false 를 돌려준다 — 행동 자체는 호출자가 허용한다.
func spend(cost: float) -> bool:
	var enough := value >= cost
	value = maxf(value - cost, 0.0)
	return enough


func drain(seconds: float) -> void:
	value = maxf(value - params.run_drain_per_second * seconds, 0.0)


func regen(seconds: float) -> void:
	value = minf(value + params.regen_per_second * seconds, params.max_value)


func restore_full() -> void:
	value = params.max_value


func is_exhausted() -> bool:
	return value <= 0.0


func is_low() -> bool:
	return value <= params.low_threshold


func ratio() -> float:
	return clampf(value / params.max_value, 0.0, 1.0) if params.max_value > 0.0 else 0.0


func speed_multiplier() -> float:
	return params.exhausted_multiplier if is_exhausted() else 1.0


func to_dict() -> Dictionary:
	return {"value": value}


func from_dict(data: Dictionary) -> bool:
	if not data.has("value"):
		return false
	var raw: Variant = data["value"]
	if not (raw is float or raw is int):
		return false
	value = clampf(float(raw), 0.0, params.max_value)
	return true
