class_name DayTimeline
extends RefCounted
## 실시간 하루의 순수 시간 계산 (docs/01 v3 6절 "분 단위 타임라인 + 시간대 트리거").
## 실초(elapsed_seconds)를 게임 시각(start_hour~end_hour)으로 펴고, 시각이 시간대 경계를 넘을 때를 알려준다.
## 시간대는 조명·이벤트 트리거일 뿐이며 하루를 끝내는 것은 취침(Clock)뿐이다.

enum Band { MORNING, DAY, EVENING, NIGHT }

const BAND_NAMES: Array[String] = ["morning", "day", "evening", "night"]
const MINUTES_PER_HOUR := 60.0
## seconds_for_hour(h) 를 되돌려 hour 로 만들 때 생기는 부동소수 오차 흡수 — 경계 초에 서 있으면 그 시간대다.
const HOUR_EPSILON := 0.000001

var day_length_seconds: float = 720.0
var start_hour: float = 6.0
var end_hour: float = 24.0
## index = Band. MORNING 은 항상 start_hour 에서 시작한다.
var band_start_hours: Array[float] = [6.0, 9.0, 17.0, 20.0]
var elapsed_seconds: float = 0.0


static func from_tuning(tuning: TuningData) -> DayTimeline:
	var timeline := DayTimeline.new()
	timeline.day_length_seconds = tuning.get_float("day_length_seconds", 720.0)
	timeline.start_hour = tuning.get_float("clock_start_hour", 6.0)
	timeline.end_hour = tuning.get_float("clock_end_hour", 24.0)
	timeline.band_start_hours = [
		timeline.start_hour,
		tuning.get_float("timeband_day_hour", 9.0),
		tuning.get_float("timeband_evening_hour", 17.0),
		tuning.get_float("timeband_night_hour", 20.0),
	]
	return timeline


static func band_name(band: int) -> String:
	return BAND_NAMES[clampi(band, 0, BAND_NAMES.size() - 1)]


## 이름이 시간대가 아니면 -1.
static func band_from_name(name: String) -> int:
	return BAND_NAMES.find(name.to_lower())


func reset() -> void:
	elapsed_seconds = 0.0


func progress() -> float:
	if day_length_seconds <= 0.0:
		return 1.0
	return clampf(elapsed_seconds / day_length_seconds, 0.0, 1.0)


func hour() -> float:
	return hour_at(elapsed_seconds)


func hour_at(seconds: float) -> float:
	if day_length_seconds <= 0.0:
		return end_hour
	var ratio := clampf(seconds / day_length_seconds, 0.0, 1.0)
	return start_hour + (end_hour - start_hour) * ratio


func seconds_for_hour(target_hour: float) -> float:
	var span := end_hour - start_hour
	if span <= 0.0:
		return 0.0
	return clampf((target_hour - start_hour) / span, 0.0, 1.0) * day_length_seconds


func seconds_for_band(band: int) -> float:
	return seconds_for_hour(band_start_hours[clampi(band, 0, band_start_hours.size() - 1)])


func band() -> int:
	return band_at(elapsed_seconds)


func band_at(seconds: float) -> int:
	var current_hour := hour_at(seconds)
	var result := Band.MORNING
	for index in range(1, band_start_hours.size()):
		if current_hour + HOUR_EPSILON >= band_start_hours[index]:
			result = index
	return result


func is_over() -> bool:
	return elapsed_seconds >= day_length_seconds


## 시간을 흘려보내고 그 사이 새로 들어선 시간대를 순서대로 돌려준다.
## delta 가 커도(테스트·건너뛰기) 시간대를 건너뛰지 않도록 경계마다 하나씩 담는다. 하루 끝을 넘지는 않는다.
func advance(delta: float) -> Array[int]:
	var crossed: Array[int] = []
	if delta <= 0.0:
		return crossed
	var before := band()
	elapsed_seconds = minf(elapsed_seconds + delta, day_length_seconds)
	var after := band()
	for band_index in range(before + 1, after + 1):
		crossed.append(band_index)
	return crossed


## "08:30" 형식. 24:00 은 그대로 24:00 으로 보여 하루의 끝임을 드러낸다.
func format_hour(value: float = -1.0) -> String:
	var current_hour := hour() if value < 0.0 else value
	var total_minutes := int(floor(current_hour * MINUTES_PER_HOUR + 0.0001))
	@warning_ignore("integer_division")
	var hours := total_minutes / int(MINUTES_PER_HOUR)
	var minutes := total_minutes % int(MINUTES_PER_HOUR)
	return "%02d:%02d" % [hours, minutes]
