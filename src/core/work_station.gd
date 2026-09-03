class_name WorkStation
extends RefCounted
## 실시간 작업대 순수 로직 (가마솥 요리·작업장 제작): 재료를 먼저 소모하고 초 단위로 익힌다. 한 작업대에 작업 하나.
## 시간을 흘리는 것은 StationSystem(노드)이고, 여기는 상태와 규칙만 갖는다.

enum Outcome { OK, BUSY, MISSING_INGREDIENTS, INVALID }

const KIND_COOK := "cook"
const KIND_CRAFT := "craft"
const COST_SEPARATOR := ":"

var job_kind: String = ""
var job_id: String = ""
var output_item: String = ""
var output_count: int = 0
var total_seconds: float = 0.0
var remaining_seconds: float = 0.0


func is_busy() -> bool:
	return not job_id.is_empty()


func progress() -> float:
	if total_seconds <= 0.0:
		return 1.0
	return clampf(1.0 - remaining_seconds / total_seconds, 0.0, 1.0)


## "item_id:n" -> [item_id, n]. 형식이 틀리면 빈 배열.
static func parse_cost(entry: String) -> Array:
	var parts := entry.split(COST_SEPARATOR)
	if parts.size() != 2 or parts[0].is_empty():
		return []
	return [parts[0], int(parts[1])]


static func has_ingredients(costs: Array, inventory: Inventory) -> bool:
	for entry: Variant in costs:
		var cost := parse_cost(str(entry))
		if cost.is_empty() or not inventory.has(cost[0], cost[1]):
			return false
	return true


## 재료를 소모하고 작업을 시작한다. seconds 가 0 이면 다음 tick 에 바로 끝난다.
func start(kind: String, id: String, costs: Array, seconds: float, item_id: String, count: int, inventory: Inventory) -> Outcome:
	if is_busy():
		return Outcome.BUSY
	if id.is_empty() or item_id.is_empty() or count <= 0:
		return Outcome.INVALID
	if not has_ingredients(costs, inventory):
		return Outcome.MISSING_INGREDIENTS
	for entry: Variant in costs:
		var cost := parse_cost(str(entry))
		inventory.remove(cost[0], cost[1])
	job_kind = kind
	job_id = id
	output_item = item_id
	output_count = count
	total_seconds = maxf(seconds, 0.0)
	remaining_seconds = total_seconds
	return Outcome.OK


## 시간을 흘린다. 이번 tick 에 끝났으면 true (산출물은 collect() 로 꺼낸다).
func tick(delta: float) -> bool:
	if not is_busy() or remaining_seconds <= 0.0:
		return false
	remaining_seconds = maxf(remaining_seconds - delta, 0.0)
	return remaining_seconds <= 0.0


func is_done() -> bool:
	return is_busy() and remaining_seconds <= 0.0


## 완성품 {"item": id, "count": n}. 아직이면 빈 Dictionary. 꺼내면 작업대가 빈다.
func collect() -> Dictionary:
	if not is_done():
		return {}
	var result := {"item": output_item, "count": output_count, "kind": job_kind, "id": job_id}
	clear()
	return result


func clear() -> void:
	job_kind = ""
	job_id = ""
	output_item = ""
	output_count = 0
	total_seconds = 0.0
	remaining_seconds = 0.0


func to_dict() -> Dictionary:
	return {
		"kind": job_kind, "id": job_id, "item": output_item, "count": output_count,
		"total": total_seconds, "remaining": remaining_seconds,
	}


func from_dict(data: Dictionary) -> bool:
	var id := str(data.get("id", ""))
	if id.is_empty():
		clear()
		return true
	var count: Variant = data.get("count", 0)
	if not (count is int or count is float):
		return false
	job_kind = str(data.get("kind", KIND_COOK))
	job_id = id
	output_item = str(data.get("item", ""))
	output_count = int(count)
	total_seconds = maxf(float(data.get("total", 0.0)), 0.0)
	remaining_seconds = clampf(float(data.get("remaining", 0.0)), 0.0, total_seconds)
	return true
