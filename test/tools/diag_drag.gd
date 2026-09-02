extends SceneTree
## 개발용 진단: 창을 띄운 상태에서 카드 → 주방 드래그를 입력 이벤트로 재현하고 드롭 판정 상태를 출력한다.
## 사용: & $env:GODOT_BIN --path . -s res://test/tools/diag_drag.gd

const STEPS := 20


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var view: Node2D = main.get("house_view")
	var panel: Control = main.get("assignment_panel")
	var controller: Node = main.get("assignment_controller")
	var card: Control = panel.call("get_card", "y01_ttukttagi")
	var start: Vector2 = card.get_global_rect().get_center()
	var kitchen_world: Vector2 = view.to_global((view.call("cell_rect", Vector2i(2, 0)) as Rect2).get_center())
	var end: Vector2 = view.get_viewport().get_canvas_transform() * kitchen_world
	# Input.parse_input_event 의 좌표는 창(윈도우) 픽셀이므로 뷰포트 좌표에 스트레치 배율을 곱한다
	var window_scale: Vector2 = Vector2(root.get_window().size) / root.get_visible_rect().size
	start *= window_scale
	end *= window_scale
	print("[diag] card center=", start, " kitchen screen=", end, " window_scale=", window_scale)

	# 좌표계 확인: 뷰포트 좌표 / 창 좌표 중 어느 쪽에서 컨트롤이 잡히는가
	_motion(start / window_scale)
	await process_frame
	print("[diag] hover@viewport-coords=", root.get_viewport().gui_get_hovered_control())
	_motion(start)
	await process_frame
	print("[diag] hover@window-coords=", root.get_viewport().gui_get_hovered_control())
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	await process_frame
	for i in STEPS:
		var pos := start.lerp(end, float(i + 1) / STEPS)
		_motion(pos)
		await process_frame
	var vp := root.get_viewport()
	print("[diag] dragging=", vp.gui_is_dragging(), " data=", vp.gui_get_drag_data(),
		" hovered=", vp.gui_get_hovered_control(), " preview_id=", view.get("_drop_preview_id"))
	var shot_path := "user://diag_drag_mid.png"
	root.get_viewport().get_texture().get_image().save_png(shot_path)
	print("[diag] mid-drag screenshot -> ", ProjectSettings.globalize_path(shot_path))
	var cell: Vector2i = view.call("world_to_cell", view.get_global_mouse_position())
	print("[diag] mouse world=", view.get_global_mouse_position(), " cell=", cell,
		" can_assign=", controller.call("can_assign", "y01_ttukttagi", cell))
	_mouse(end, MOUSE_BUTTON_LEFT, false)
	for i in 3:
		await process_frame
	var game_state: Node = root.get_node("GameState")
	print("[diag] assignment after drop=", game_state.get("assignment").call("to_dict"))
	quit(0)


func _mouse(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


var _last_pos: Vector2 = Vector2.ZERO


func _motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos - _last_pos  # 드래그 시작 판정은 relative 누적(>10px)으로 한다
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_last_pos = pos
	Input.parse_input_event(event)
