class_name DropLayer
extends Control
## 월드 위에 깔린 투명 드롭 대상. 요괴 카드를 방 위에 놓으면 그 칸에 배치한다.
## 마우스 이벤트는 통과(PASS)시켜 카메라 클릭·드래그를 막지 않는다.

var controller: AssignmentController
var house_view: HouseView


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _notification(what: int) -> void:
	if house_view == null:
		return
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var data: Variant = get_viewport().gui_get_drag_data()
			if data is Dictionary and (data as Dictionary).has(YokaiCard.DRAG_KEY):
				house_view.set_drop_preview(str((data as Dictionary)[YokaiCard.DRAG_KEY]))
		NOTIFICATION_DRAG_END:
			house_view.set_drop_preview("")


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and (data as Dictionary).has(YokaiCard.DRAG_KEY)):
		return false
	var cell := house_view.world_to_cell(house_view.get_global_mouse_position())
	return controller.can_assign(str((data as Dictionary)[YokaiCard.DRAG_KEY]), cell) == AssignmentController.Outcome.OK


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var cell := house_view.world_to_cell(house_view.get_global_mouse_position())
	controller.try_assign(str((data as Dictionary)[YokaiCard.DRAG_KEY]), cell)
