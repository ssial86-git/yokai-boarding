class_name Farm
extends RefCounted
## 텃밭 순수 로직: 괭이질 → 파종 → 물주기 → 수확, 하루 끝 성장. 노드·씬 의존 없음.
## 성장은 '물을 준 비율 × (1 + 음기 보너스)' 만큼 하루씩 쌓인다 — 요괴가 효율 0.6 으로 물을 주면 하루에 0.6일 자란다 (위임의 트레이드오프).

enum PlotState { EMPTY, TILLED, GROWING, READY }
enum Outcome { OK, OUT_OF_RANGE, NOT_EMPTY, NOT_TILLED, NO_SEED, UNKNOWN_CROP, NOT_GROWING, NOT_READY, OUT_OF_SEASON }

const FULL_WATER := 1.0
const SEASON_ANY := "any"


class Plot:
	extends RefCounted
	var state: PlotState = PlotState.EMPTY
	var crop_id: String = ""
	## 자란 날 수 (물 비율 × 보너스가 누적되므로 실수)
	var growth: float = 0.0
	## 오늘 준 물의 양 (1.0 = 하루치)
	var water: float = 0.0

	func to_dict() -> Dictionary:
		return {"state": state, "crop_id": crop_id, "growth": growth, "water": water}

	static func from_dict(data: Dictionary) -> Plot:
		var plot := Plot.new()
		plot.state = clampi(int(data.get("state", PlotState.EMPTY)), PlotState.EMPTY, PlotState.READY) as PlotState
		plot.crop_id = str(data.get("crop_id", ""))
		plot.growth = maxf(float(data.get("growth", 0.0)), 0.0)
		plot.water = clampf(float(data.get("water", 0.0)), 0.0, FULL_WATER)
		return plot


var plots: Array[Plot] = []


func _init(plot_count: int = 0) -> void:
	expand(plot_count)


func size() -> int:
	return plots.size()


## 칸 수를 count 까지 늘린다 (줄이지는 않는다).
func expand(count: int) -> void:
	while plots.size() < count:
		plots.append(Plot.new())


func get_plot(index: int) -> Plot:
	return plots[index] if index >= 0 and index < plots.size() else null


func till(index: int) -> Outcome:
	var plot := get_plot(index)
	if plot == null:
		return Outcome.OUT_OF_RANGE
	if plot.state != PlotState.EMPTY:
		return Outcome.NOT_EMPTY
	plot.state = PlotState.TILLED
	return Outcome.OK


## 씨앗(crop.seed_item)을 인벤토리에서 하나 쓴다. season_key(절기 id)를 주면 제철이 아닌 작물은 심지 못한다 (P2-S1).
func sow(index: int, crop: CropData, inventory: Inventory, season_key: String = "") -> Outcome:
	var plot := get_plot(index)
	if plot == null:
		return Outcome.OUT_OF_RANGE
	if crop == null:
		return Outcome.UNKNOWN_CROP
	if plot.state != PlotState.TILLED:
		return Outcome.NOT_TILLED
	if not in_season(crop, season_key):
		return Outcome.OUT_OF_SEASON
	if not inventory.remove(crop.seed_item, 1):
		return Outcome.NO_SEED
	plot.state = PlotState.GROWING
	plot.crop_id = crop.id
	plot.growth = 0.0
	plot.water = 0.0
	return Outcome.OK


## 제철 판정. season_key 가 비면 계절 제한 없음.
static func in_season(crop: CropData, season_key: String) -> bool:
	return season_key.is_empty() or crop.season == SEASON_ANY or crop.season == season_key


## amount 1.0 = 플레이어 한 번. 요괴 자동 물주기는 효율 계수만큼.
func water(index: int, amount: float = FULL_WATER) -> Outcome:
	var plot := get_plot(index)
	if plot == null:
		return Outcome.OUT_OF_RANGE
	if plot.state != PlotState.GROWING:
		return Outcome.NOT_GROWING
	plot.water = minf(plot.water + amount, FULL_WATER)
	return Outcome.OK


## 자라는 칸 전부에 물을 준다. 물을 준 칸 수를 돌려준다 (자동화 층).
func water_all(amount: float) -> int:
	var watered := 0
	for index in plots.size():
		if water(index, amount) == Outcome.OK:
			watered += 1
	return watered


## 수확물 {"item": id, "count": n}. 실패하면 빈 Dictionary. 수확한 칸은 갈아 둔 상태로 남는다.
func harvest(index: int, crop_catalog: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var plot := get_plot(index)
	if plot == null or plot.state != PlotState.READY:
		return {}
	var crop := crop_catalog.get(plot.crop_id) as CropData
	if crop == null:
		return {}
	var count := rng.randi_range(mini(crop.yield_min, crop.yield_max), maxi(crop.yield_min, crop.yield_max))
	plot.state = PlotState.TILLED
	plot.crop_id = ""
	plot.growth = 0.0
	plot.water = 0.0
	return {"item": crop.harvest_item, "count": maxi(count, 1)}


## 하루 끝: 물 비율만큼 자라고 물은 마른다. 다 자란 칸 index 목록을 돌려준다.
func advance_day(crop_catalog: Dictionary, yin_high: bool = false) -> Array[int]:
	var ripened: Array[int] = []
	for index in plots.size():
		var plot := plots[index]
		if plot.state != PlotState.GROWING:
			continue
		var crop := crop_catalog.get(plot.crop_id) as CropData
		if crop == null:
			continue
		var needed := float(crop.water_per_day)
		var ratio := 1.0 if needed <= 0.0 else clampf(plot.water / needed, 0.0, 1.0)
		var bonus := crop.yin_growth_bonus if yin_high else 0.0
		plot.growth += ratio * (1.0 + bonus)
		plot.water = 0.0
		if plot.growth + 0.0001 >= float(crop.grow_days):
			plot.state = PlotState.READY
			ripened.append(index)
	return ripened


func count_state(state: PlotState) -> int:
	var count := 0
	for plot in plots:
		if plot.state == state:
			count += 1
	return count


func to_dict() -> Dictionary:
	var result: Array = []
	for plot in plots:
		result.append(plot.to_dict())
	return {"plots": result}


## 형식이 맞지 않으면 false 를 돌려주고 상태를 바꾸지 않는다.
func from_dict(data: Dictionary) -> bool:
	var raw: Variant = data.get("plots", [])
	if not raw is Array:
		return false
	var parsed: Array[Plot] = []
	for entry: Variant in (raw as Array):
		if not entry is Dictionary:
			return false
		parsed.append(Plot.from_dict(entry as Dictionary))
	plots = parsed
	return true
