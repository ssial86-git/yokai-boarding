class_name HouseCamera
extends Camera2D
## 플레이어 추적(감쇠) + 휠 줌(정수 배율) + 클릭 판정. 드래그 임계값을 넘지 않은 좌클릭만 clicked 로 보낸다.
## P1-S2 부터 카메라는 플레이어를 따라가므로 드래그 스크롤은 없다. 경계는 RegionManager 가 구역마다 넣는다.

signal clicked(world_pos: Vector2)
signal hovered(world_pos: Vector2)

## 카메라 중심이 머물 수 있는 월드 영역. 구역 bounds 에 여유를 더해 넣는다.
var bounds: Rect2 = Rect2()
## 따라갈 대상 (플레이어). null 이면 제자리.
var follow: Node2D

var _zoom_min: int = 1
var _zoom_max: int = 3
var _zoom_step: int = 1
var _drag_threshold: float = 4.0
var _zoom_level: int = 1
var _smoothing: float = 8.0
var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_zoom_min = tuning.get_int("camera_zoom_min")
	_zoom_max = tuning.get_int("camera_zoom_max")
	_zoom_step = tuning.get_int("camera_zoom_step")
	_drag_threshold = tuning.get_float("camera_drag_threshold_px")
	_smoothing = tuning.get_float("camera_follow_smoothing", _smoothing)
	position_smoothing_enabled = false
	set_zoom_level(_zoom_min)
	make_current()


func _process(delta: float) -> void:
	if follow == null:
		return
	var goal := _follow_goal()
	position = position.lerp(goal, clampf(_smoothing * delta, 0.0, 1.0)).round()


## 구역 전환 직후 감쇠 없이 바로 붙는다.
func snap_to_follow() -> void:
	if follow != null:
		position = _follow_goal()


func _follow_goal() -> Vector2:
	var goal := follow.global_position
	if bounds.size == Vector2.ZERO:
		return goal
	return CameraBounds.clamp_center(goal, bounds, get_viewport_rect().size, zoom.x)


func set_zoom_level(level: int) -> void:
	_zoom_level = clampi(level, _zoom_min, _zoom_max)
	zoom = Vector2.ONE * float(_zoom_level)
	clamp_to_bounds()


func get_zoom_level() -> int:
	return _zoom_level


func clamp_to_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	position = CameraBounds.clamp_center(position, bounds, get_viewport_rect().size, zoom.x).round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_motion(event as InputEventMouseMotion)


func _handle_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				set_zoom_level(_zoom_level + _zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				set_zoom_level(_zoom_level - _zoom_step)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_pressing = true
				_dragging = false
				_press_pos = event.position
			else:
				if _pressing and not _dragging and event.button_index == MOUSE_BUTTON_LEFT:
					clicked.emit(get_global_mouse_position())
				_pressing = false
				_dragging = false


func _handle_motion(event: InputEventMouseMotion) -> void:
	hovered.emit(get_global_mouse_position())
	if not _pressing:
		return
	if not _dragging and (event.position - _press_pos).length() > _drag_threshold:
		_dragging = true  # 드래그로 판정된 클릭은 무시할 뿐, 카메라는 플레이어를 따른다
