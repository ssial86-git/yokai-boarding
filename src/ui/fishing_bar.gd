class_name FishingBar
extends Control
## 낚시 타이밍 바 (P1-S3): 가로 막대 위 초록 성공 구간과 왕복하는 마커. FishingSystem 상태를 매 프레임 그린다.
## 관대한 판정이 목표이므로 구간 폭은 tuning fishing_window_ratio.

const BAR_SIZE := Vector2(200.0, 12.0)
const MARKER_WIDTH := 3.0
const BOTTOM_MARGIN_PX := 80.0

var fishing_system: FishingSystem

var _window_color: Color = Color.GREEN
var _marker_color: Color = Color.WHITE
var _track_color: Color = Color(0.1, 0.08, 0.12, 0.9)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tuning := DataRegistry.tuning
	_window_color = Color.html(tuning.get_string("drop_ok_color"))
	_marker_color = Color.html(tuning.get_string("crop_ready_color"))
	visible = false


func _process(_delta: float) -> void:
	var active := fishing_system != null and fishing_system.is_active()
	if active != visible:
		visible = active
	if visible:
		queue_redraw()


func _draw() -> void:
	var cast := fishing_system.cast if fishing_system != null else null
	if cast == null:
		return
	var view_size := get_viewport_rect().size
	var origin := Vector2((view_size.x - BAR_SIZE.x) * 0.5, view_size.y - BOTTOM_MARGIN_PX - BAR_SIZE.y).round()
	draw_rect(Rect2(origin, BAR_SIZE), _track_color)
	var window_x := origin.x + (cast.center - cast.half_width) * BAR_SIZE.x
	draw_rect(Rect2(Vector2(window_x, origin.y), Vector2(cast.half_width * 2.0 * BAR_SIZE.x, BAR_SIZE.y)), _window_color)
	var marker_x := origin.x + cast.marker() * BAR_SIZE.x - MARKER_WIDTH * 0.5
	draw_rect(Rect2(Vector2(marker_x, origin.y - 2.0), Vector2(MARKER_WIDTH, BAR_SIZE.y + 4.0)), _marker_color)
	draw_rect(Rect2(origin, BAR_SIZE), Color(1, 1, 1, 0.6), false, 1.0)
