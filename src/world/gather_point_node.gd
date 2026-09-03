class_name GatherPointNode
extends Interactable
## 채집 포인트 하나의 화면 표현 + 상호작용. 상태·규칙은 GatherSystem/GatherPoints 가 갖는다.
## 자리표시: 재료별 팔레트 색 원. 캐고 나면 흐린 X.

const TAKEN_ALPHA := 0.35

var region_id: String = ""
var index: int = 0

var _gather_system: GatherSystem
var _size: float = 12.0


func setup(region: String, point_index: int, gather_system: GatherSystem) -> void:
	region_id = region
	index = point_index
	_gather_system = gather_system
	_size = float(DataRegistry.tuning.get_int("gather_point_size_px"))
	set_box(Vector2(_size + 8.0, _size + 8.0), Vector2(0, -_size * 0.5))
	prompt_provider = func() -> String: return _gather_system.prompt_for(region_id, index)
	enabled_check = func() -> bool: return _gather_system.can_gather(region_id, index)
	action = func(_player: Node) -> void: _gather_system.gather(region_id, index)
	Events.gather_point_changed.connect(func(changed_region: String, changed: int) -> void:
		if changed_region == region_id and (changed == index or changed < 0):
			queue_redraw())


func _draw() -> void:
	var points := _gather_system.points_for(region_id)
	var material_id := points.material_at(index)
	if material_id.is_empty():
		return
	var color := _gather_system.material_color(material_id)
	var center := Vector2(0.0, -_size * 0.5)
	var outline := Color(0.1, 0.08, 0.12)
	if points.is_taken(index):
		# 캔 자리: 흐린 그루터기 + 진한 X (내일 다시 자란다는 표시)
		color.a = TAKEN_ALPHA
		draw_rect(Rect2(Vector2(-_size * 0.25, -_size * 0.4), Vector2(_size * 0.5, _size * 0.4)), color)
		var half := _size * 0.4
		draw_line(center + Vector2(-half, -half), center + Vector2(half, half), outline, 2.0)
		draw_line(center + Vector2(-half, half), center + Vector2(half, -half), outline, 2.0)
		return
	draw_circle(center, _size * 0.5, color)
	draw_arc(center, _size * 0.5, 0.0, TAU, 12, outline, 1.0)
