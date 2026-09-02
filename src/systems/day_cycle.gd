class_name DayCycle
extends Node
## 하루 사이클의 시스템 측: 저녁 진입 시 정산(DaySettlement)을 실행해 인벤토리·컨디션에 반영하고,
## 방이 바뀌면 무효해진 배치를 휴식으로 되돌린다. 페이즈 진행 자체는 Clock 이 한다.


func _ready() -> void:
	Events.phase_changed.connect(_on_phase_changed)
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: prune_assignment())
	Events.floor_added.connect(func(_floor: int) -> void: prune_assignment())


func _on_phase_changed(phase: int, _day: int) -> void:
	if phase == Clock.Phase.EVENING:
		settle()


func settle() -> DaySettlement.Result:
	var params := DaySettlement.Params.from_tuning(DataRegistry.tuning)
	var result := DaySettlement.settle(
		GameState.room_grid, GameState.assignment, GameState.residents,
		DataRegistry.yokai, GameState.conditions, params,
	)
	var totals := result.totals()
	for item_id: String in totals:
		GameState.inventory.add(item_id, int(totals[item_id]))
		Events.item_added.emit(item_id, int(totals[item_id]))
	for yokai_id: String in result.conditions:
		GameState.conditions[yokai_id] = int(result.conditions[yokai_id])
		Events.condition_changed.emit(yokai_id, int(result.conditions[yokai_id]))
	Events.day_settled.emit({
		"day": GameState.day,
		"totals": totals,
		"noise_hits": result.noise_hits.duplicate(),
	})
	return result


func prune_assignment() -> void:
	for yokai_id in GameState.assignment.prune(GameState.room_grid, GameState.residents):
		Events.assignment_changed.emit(yokai_id, Assignment.REST)
