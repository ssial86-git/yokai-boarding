class_name DaySettlement
extends RefCounted
## 하루 정산 순수 로직: 시설 산출(특성 보너스·컨디션 반영)과 컨디션 변화(일·휴식·옆방 소음).
## 결과만 계산한다. 인벤토리 반영·시그널은 DayCycle 이 한다.


class Params:
	extends RefCounted
	var condition_max: int = 100
	var work_condition_cost: int = 30
	var rest_condition_gain: int = 40
	var noise_condition_penalty_per_level: int = 10
	var low_condition_threshold: int = 40
	var low_condition_multiplier: float = 0.5

	static func from_tuning(tuning: TuningData) -> Params:
		var params := Params.new()
		params.condition_max = tuning.get_int("condition_max", params.condition_max)
		params.work_condition_cost = tuning.get_int("work_condition_cost", params.work_condition_cost)
		params.rest_condition_gain = tuning.get_int("rest_condition_gain", params.rest_condition_gain)
		params.noise_condition_penalty_per_level = tuning.get_int(
			"noise_condition_penalty_per_level", params.noise_condition_penalty_per_level)
		params.low_condition_threshold = tuning.get_int("low_condition_threshold", params.low_condition_threshold)
		params.low_condition_multiplier = tuning.get_float("low_condition_multiplier", params.low_condition_multiplier)
		return params


class Output:
	extends RefCounted
	var yokai_id: String = ""
	var cell: Vector2i = Vector2i.ZERO
	var room_id: String = ""
	var item_id: String = ""
	var amount: int = 0
	var multiplier: float = 1.0
	var preferred: bool = false
	var low_condition: bool = false


class Result:
	extends RefCounted
	var outputs: Array[Output] = []
	var conditions: Dictionary = {}  # yokai_id -> 정산 후 컨디션
	var noise_hits: Dictionary = {}  # yokai_id -> 휴식 중 겪은 소음 레벨 (>0 만)

	func totals() -> Dictionary:
		var result: Dictionary = {}
		for output in outputs:
			result[output.item_id] = int(result.get(output.item_id, 0)) + output.amount
		return result


## 휴식 장소: 첫 객실(lodging). 없으면 대문간(gate), 그것도 없으면 (0,0).
static func rest_cell(grid: RoomGrid) -> Vector2i:
	var gate := Vector2i(-1, -1)
	for cell in grid.get_built_cells():
		var room := grid.get_room(cell)
		if room == null:
			continue
		if room.kind == "lodging":
			return cell
		if room.kind == "gate" and gate == Vector2i(-1, -1):
			gate = cell
	return gate if gate != Vector2i(-1, -1) else Vector2i(0, 0)


## cell 의 상하좌우 옆 칸에서 일하는 요괴 중 가장 큰 noise.
static func noise_at(grid: RoomGrid, assignment: Assignment, yokai_catalog: Dictionary, cell: Vector2i) -> int:
	var loudest := 0
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var side := cell + offset
		if not grid.is_in_bounds(side):
			continue
		for yokai_id in assignment.workers_at(side):
			var yokai := yokai_catalog.get(yokai_id) as YokaiData
			if yokai != null:
				loudest = maxi(loudest, yokai.noise)
	return loudest


static func multiplier_for(yokai: YokaiData, room: RoomData, condition: int, params: Params) -> float:
	var multiplier := 1.0
	if yokai.preferred_room == room.id:
		multiplier += yokai.work_bonus
	if condition < params.low_condition_threshold:
		multiplier *= params.low_condition_multiplier
	return multiplier


## 산출이 없는 방(output_item 없음)에서는 null.
static func output_for(yokai: YokaiData, cell: Vector2i, room: RoomData, condition: int, params: Params) -> Output:
	if room == null or room.output_item.is_empty() or room.output_amount <= 0:
		return null
	var output := Output.new()
	output.yokai_id = yokai.id
	output.cell = cell
	output.room_id = room.id
	output.item_id = room.output_item
	output.preferred = yokai.preferred_room == room.id
	output.low_condition = condition < params.low_condition_threshold
	output.multiplier = multiplier_for(yokai, room, condition, params)
	output.amount = int(floor(room.output_amount * output.multiplier + 0.5))
	return output


static func settle(
	grid: RoomGrid,
	assignment: Assignment,
	residents: Array[String],
	yokai_catalog: Dictionary,
	conditions: Dictionary,
	params: Params,
) -> Result:
	var result := Result.new()
	var home := rest_cell(grid)
	var home_room := grid.get_room(home)
	var home_noise := noise_at(grid, assignment, yokai_catalog, home) if home_room != null and home_room.quiet else 0
	for yokai_id in residents:
		var yokai := yokai_catalog.get(yokai_id) as YokaiData
		if yokai == null:
			continue
		var condition := int(conditions.get(yokai_id, params.condition_max))
		var cell := assignment.get_cell(yokai_id)
		var working := cell != Assignment.REST and grid.is_in_bounds(cell) and grid.is_floor_built(cell.y)
		if working:
			var output := output_for(yokai, cell, grid.get_room(cell), condition, params)
			if output != null:
				result.outputs.append(output)
			condition -= params.work_condition_cost
		else:
			condition += params.rest_condition_gain
			if home_noise > 0:
				condition -= home_noise * params.noise_condition_penalty_per_level
				result.noise_hits[yokai_id] = home_noise
		result.conditions[yokai_id] = clampi(condition, 0, params.condition_max)
	return result
