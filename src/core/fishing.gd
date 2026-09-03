class_name Fishing
extends RefCounted
## 개울 낚시 순수 로직 (docs/01 v3 2.1): 타이밍 바 미니게임. 마커가 0~1 을 왕복하고 초록 구간 안에서 E 를 누르면 성공.
## 판정은 관대하게(window_ratio) — 손맛 튜닝 대상이 아니다. 어종 추첨은 구역·시간대·낚싯대 레벨로 거른 뒤 가중치.

const KIND_JUNK := "junk"
const TIMEBAND_ANY := "any"


class Cast:
	extends RefCounted
	## 성공 구간 가운데 (0~1)
	var center: float = 0.5
	## 성공 구간 반폭
	var half_width: float = 0.175
	var cycles_per_second: float = 0.8
	var elapsed: float = 0.0

	## 마커 위치 0~1 (사인 왕복)
	func marker() -> float:
		return 0.5 + 0.5 * sin(TAU * cycles_per_second * elapsed)

	func is_hit() -> bool:
		return absf(marker() - center) <= half_width + 0.0001

	func advance(delta: float) -> void:
		elapsed += maxf(delta, 0.0)


static func new_cast(rng: RandomNumberGenerator, window_ratio: float, cycles_per_second: float) -> Cast:
	var cast := Cast.new()
	cast.half_width = clampf(window_ratio, 0.05, 1.0) * 0.5
	cast.center = rng.randf_range(cast.half_width, 1.0 - cast.half_width)
	cast.cycles_per_second = maxf(cycles_per_second, 0.01)
	return cast


## 이 구역·시간대·낚싯대로 낚을 수 있는 어종(고물 포함).
static func candidates(fish_catalog: Dictionary, region_id: String, timeband: String, rod_level: int, include_junk: bool = true) -> Array[FishData]:
	var result: Array[FishData] = []
	for fish: FishData in fish_catalog.values():
		if fish.region_id != region_id:
			continue
		if fish.timeband != TIMEBAND_ANY and fish.timeband != timeband:
			continue
		if fish.min_rod_level > rod_level:
			continue
		if not include_junk and fish.kind == KIND_JUNK:
			continue
		result.append(fish)
	result.sort_custom(func(a: FishData, b: FishData) -> bool: return a.id < b.id)
	return result


## 가중치 추첨. 후보가 없으면 null.
static func roll(pool: Array[FishData], rng: RandomNumberGenerator) -> FishData:
	var total := 0
	for fish in pool:
		total += maxi(fish.weight, 0)
	if total <= 0:
		return null
	var pick := rng.randi_range(1, total)
	for fish in pool:
		pick -= maxi(fish.weight, 0)
		if pick <= 0:
			return fish
	return pool[pool.size() - 1]


## 고물만 (놓쳤을 때 위로용).
static func junk_only(pool: Array[FishData]) -> Array[FishData]:
	var result: Array[FishData] = []
	for fish in pool:
		if fish.kind == KIND_JUNK:
			result.append(fish)
	return result
