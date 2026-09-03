class_name WeatherRoll
extends RefCounted
## 아침 날씨·음기 추첨 순수 로직 (P2-S1). weather.csv 의 절기별 가중치로 날씨를 뽑고 그 날씨의 음기 범위(0~3) 안에서 지수를 뽑는다.
## 소절기 이벤트의 weather_override 가 있으면 추첨 없이 그 날씨. "비 오는 날 = 음기" 임시 규칙은 이 표로 대체됐다.

const REALM_MORTAL := "mortal"
const REALM_DEMON := "demon"
const SEASON_ANY := "any"
const YIN_MIN := 0
const YIN_MAX := 3


class Result:
	extends RefCounted
	var weather_id: String = ""
	var yin: int = 0


## 절기에 나올 수 있는 날씨 (season 이 any 이거나 일치, 가중치 양수), id 순.
static func eligible(catalog: Dictionary, season_id: String) -> Array[WeatherData]:
	var result: Array[WeatherData] = []
	for weather: WeatherData in catalog.values():
		if (weather.season == SEASON_ANY or weather.season == season_id) and weather.weight > 0:
			result.append(weather)
	result.sort_custom(func(a: WeatherData, b: WeatherData) -> bool: return a.id < b.id)
	return result


static func roll(catalog: Dictionary, season_id: String, rng: RandomNumberGenerator, override_id: String = "") -> Result:
	var result := Result.new()
	var chosen: WeatherData = null
	if not override_id.is_empty():
		chosen = catalog.get(override_id) as WeatherData
	if chosen == null:
		var candidates := eligible(catalog, season_id)
		if candidates.is_empty():
			return result
		var total := 0
		for weather in candidates:
			total += weather.weight
		var pick := rng.randi_range(1, total)
		chosen = candidates[candidates.size() - 1]
		for weather in candidates:
			pick -= weather.weight
			if pick <= 0:
				chosen = weather
				break
	result.weather_id = chosen.id
	var low := clampi(mini(chosen.yin_min, chosen.yin_max), YIN_MIN, YIN_MAX)
	var high := clampi(maxi(chosen.yin_min, chosen.yin_max), YIN_MIN, YIN_MAX)
	result.yin = low if low == high else rng.randi_range(low, high)
	return result


static func is_yin_high(yin: int, threshold: int) -> bool:
	return yin >= threshold


## 손님 종족 가중치 배율 {realm: multiplier}. 소절기 이벤트의 마계 손님 배율을 곱한다. 날씨가 없으면 1.0.
static func guest_multipliers(weather: WeatherData, event_demon_multiplier: float = 1.0) -> Dictionary:
	if weather == null:
		return {REALM_MORTAL: 1.0, REALM_DEMON: event_demon_multiplier}
	return {
		REALM_MORTAL: weather.mortal_guest_multiplier,
		REALM_DEMON: weather.demon_guest_multiplier * event_demon_multiplier,
	}
