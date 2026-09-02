class_name DayNightLighting
extends CanvasModulate
## 하루 페이즈에 따라 화면 전체 색조를 바꾼다. 색은 tuning.csv 의 light_color_<phase> 키.

const COLOR_KEY_FORMAT := "light_color_%s"

var _transition_seconds: float = 1.0
var _tween: Tween


func _ready() -> void:
	_transition_seconds = DataRegistry.tuning.get_float("light_transition_seconds")
	color = _color_for_phase(Clock.phase)
	Events.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int, _day: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", _color_for_phase(phase), _transition_seconds)


func _color_for_phase(phase: int) -> Color:
	var phase_name: String = Clock.Phase.keys()[phase].to_lower()
	return Color.html(DataRegistry.tuning.get_string(COLOR_KEY_FORMAT % phase_name, "ffffff"))
