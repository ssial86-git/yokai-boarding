class_name MessageLog
extends VBoxContainer
## 화면 왼쪽 아래 메시지 로그. 새 줄은 아래에 붙고, 일정 시간 뒤 사라진다. 줄 수 상한은 tuning.

var _max_lines: int = 4
var _fade_seconds: float = 4.0


func _ready() -> void:
	_max_lines = DataRegistry.tuning.get_int("message_log_lines")
	_fade_seconds = DataRegistry.tuning.get_float("message_fade_seconds")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.message_posted.connect(post)


func post(text: String) -> void:
	for line in text.split("\n", false):
		var label := Label.new()
		label.text = line
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		var tween := create_tween()
		tween.tween_interval(_fade_seconds)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)
	while get_child_count() > _max_lines:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func line_count() -> int:
	return get_child_count()
