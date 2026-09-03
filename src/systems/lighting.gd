class_name DayNightLighting
extends CanvasModulate
## 시간대에 따라 화면 전체 색조를 바꾼다. 색은 tuning.csv 의 light_color_<timeband> 키.

const COLOR_KEY_FORMAT := "light_color_%s"

var _transition_seconds: float = 1.0
var _tween: Tween


func _ready() -> void:
	_transition_seconds = DataRegistry.tuning.get_float("light_transition_seconds")
	color = _color_for_band(Clock.band)
	Events.timeband_changed.connect(_on_timeband_changed)


func _on_timeband_changed(band: int, _day: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", _color_for_band(band), _transition_seconds)


func _color_for_band(band: int) -> Color:
	return Color.html(DataRegistry.tuning.get_string(COLOR_KEY_FORMAT % DayTimeline.band_name(band), "ffffff"))
