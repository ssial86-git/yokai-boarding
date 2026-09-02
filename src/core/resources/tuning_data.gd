class_name TuningData
extends Resource
## 밸런스 상수 테이블. data/csv/tuning.csv 전체 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

## key -> int | float | bool | String (tuning.csv 의 type 컬럼대로 변환됨)
@export var values: Dictionary = {}


func has_key(key: String) -> bool:
	return values.has(key)


func get_int(key: String, default: int = 0) -> int:
	return int(values.get(key, default))


func get_float(key: String, default: float = 0.0) -> float:
	return float(values.get(key, default))


func get_bool(key: String, default: bool = false) -> bool:
	return bool(values.get(key, default))


func get_string(key: String, default: String = "") -> String:
	return str(values.get(key, default))
