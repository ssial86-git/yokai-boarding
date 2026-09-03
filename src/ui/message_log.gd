class_name MessageLog
extends VBoxContainer
## 화면 왼쪽 아래 메시지 로그. 새 줄은 아래에 붙고, 일정 시간 뒤 사라진다. 줄 수 상한은 tuning.

var _max_lines: int = 4
var _fade_seconds: float = 4.0
## 한 줄의 최대 폭. 넘치면 줄바꿈 — 집 단면(x≈193) 위로 글자가 흘러가던 문제 (검증 에이전트 08_day2_morning)
var _line_width: float = 180.0
## 토스트 더미의 최대 높이. 넘치면 오래된 줄부터 지운다 — 위로 자라 시계 카드·안내 줄을 덮던 문제. main.gd 가 레이아웃 때 넣는다.
## 값이 바뀌면 이미 쌓인 줄도 바로 다듬는다 (첫 아침 토스트는 레이아웃보다 먼저 온다 — 검증 에이전트 02_morning_plain)
var max_height: float = INF:
	set(value):
		max_height = value
		_trim()


func _ready() -> void:
	_max_lines = DataRegistry.tuning.get_int("message_log_lines")
	_fade_seconds = DataRegistry.tuning.get_float("message_fade_seconds")
	_line_width = get_viewport_rect().size.x * DataRegistry.tuning.get_float("message_log_width_ratio", 0.29)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.message_posted.connect(post)


## 한 줄 = 칩 상자(토스트) 하나. 유사 게임 관행(스타듀밸리 HUD 메시지)대로 상자가 있어 월드 위에서도 읽힌다.
## 상자 폭은 글자 폭에 맞추되 _line_width 를 넘으면 줄바꿈한다.
func post(text: String) -> void:
	for line in text.split("\n", false):
		var box := PanelContainer.new()
		UiStyles.apply_chip(box)
		box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font := label.get_theme_font("font")
		var text_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		label.custom_minimum_size = Vector2(minf(text_width + 1.0, _line_width), 0)
		box.add_child(label)
		add_child(box)
		var tween := create_tween()
		tween.tween_interval(_fade_seconds)
		tween.tween_property(box, "modulate:a", 0.0, 0.5)
		tween.tween_callback(box.queue_free)
	_trim()


func _trim() -> void:
	while get_child_count() > _max_lines or (get_child_count() > 1 and get_combined_minimum_size().y > max_height):
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func line_count() -> int:
	return get_child_count()
