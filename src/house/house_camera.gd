class_name HouseCamera
extends Camera2D
## 휠 줌(정수 배율) + 드래그 스크롤 + 클릭 판정. 드래그 임계값을 넘지 않은 좌클릭만 clicked 로 보낸다.
## 입력을 한곳에서 처리해 클릭/드래그 판정 순서가 노드 순서에 좌우되지 않게 한다.

signal clicked(world_pos: Vector2)
signal hovered(world_pos: Vector2)

## 카메라 중심이 머물 수 있는 월드 영역. HouseView.house_bounds() 에 여유를 더해 넣는다.
var bounds: Rect2 = Rect2()

var _zoom_min: int = 1
var _zoom_max: int = 3
var _zoom_step: int = 1
var _drag_threshold: float = 4.0
var _zoom_level: int = 1
var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_zoom_min = tuning.get_int("camera_zoom_min")
	_zoom_max = tuning.get_int("camera_zoom_max")
	_zoom_step = tuning.get_int("camera_zoom_step")
	_drag_threshold = tuning.get_float("camera_drag_threshold_px")
	position_smoothing_enabled = false
	set_zoom_level(_zoom_min)
	make_current()


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
		_dragging = true
	if _dragging:
		position -= event.relative / zoom
		clamp_to_bounds()
