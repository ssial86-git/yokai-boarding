class_name Inventory
extends RefCounted
## 아이템 수량 저장소. 순수 로직 — 시그널 발신은 소유자(GameState/DayCycle)가 한다.

var _counts: Dictionary = {}  # item_id -> int (항상 > 0)


func add(item_id: String, count: int) -> void:
	if count <= 0 or item_id.is_empty():
		return
	_counts[item_id] = get_count(item_id) + count


## 부족하면 아무것도 빼지 않고 false.
func remove(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	var current := get_count(item_id)
	if current < count:
		return false
	if current == count:
		_counts.erase(item_id)
	else:
		_counts[item_id] = current - count
	return true


func get_count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has(item_id: String, count: int = 1) -> bool:
	return get_count(item_id) >= count


func is_empty() -> bool:
	return _counts.is_empty()


## item_id -> count 복사본. 순서는 삽입 순.
func items() -> Dictionary:
	return _counts.duplicate()


func clear() -> void:
	_counts.clear()


func to_dict() -> Dictionary:
	return _counts.duplicate()


## 음수·0·비정수 값이 있으면 false 를 돌려주고 상태를 바꾸지 않는다.
func from_dict(data: Dictionary) -> bool:
	var parsed: Dictionary = {}
	for key: Variant in data:
		var value: Variant = data[key]
		if not (value is int or value is float):
			return false
		var count := int(value)
		if count < 0 or float(count) != float(value):
			return false
		if count > 0:
			parsed[str(key)] = count
	_counts = parsed
	return true
