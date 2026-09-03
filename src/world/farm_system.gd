class_name FarmSystem
extends Node
## 텃밭의 노드 측: 플레이어 행동(괭이질·파종·물주기·수확)의 규칙 판단과 상태 반영, 하루 끝 성장,
## 텃밭(FIELD)에 배치된 요괴의 자동 물주기(효율 계수 — docs/01 v3 2.2 자동화 층). 순수 계산은 Farm 이 한다.

const FEATURE_FARM_12 := "farm_plots_12"
const TOOL_HOE := "hoe"

var _stamina_cost: float = 4.0
var _efficiency: float = 0.6


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_stamina_cost = tuning.get_float("stamina_farm_cost", _stamina_cost)
	_efficiency = tuning.get_float("automation_efficiency", _efficiency)
	Events.day_ended.connect(func(_day: int) -> void: advance_day())
	Events.timeband_changed.connect(func(band: int, _day: int) -> void:
		if band == Clock.Band.DAY:
			auto_water())
	Events.unlocked.connect(func(unlock_id: String) -> void:
		var unlock := DataRegistry.get_unlock(unlock_id)
		if unlock != null and unlock.unlock_type == "feature" and unlock.unlock_id == FEATURE_FARM_12:
			GameState.farm.expand(DataRegistry.tuning.get_int("farm_plots_max"))
			Events.farm_changed.emit(-1))
	Events.game_loaded.connect(func(_slot: int) -> void: Events.farm_changed.emit(-1))
	Events.weather_rolled.connect(func(weather_id: String, _yin: int) -> void: rain_water(weather_id))


func farm() -> Farm:
	return GameState.farm


## 씨앗이 있는 제철 작물 중 가장 많이 가진 것. 없으면 null.
func seed_choice() -> CropData:
	var best: CropData = null
	var best_count := 0
	for crop: CropData in DataRegistry.crops.values():
		if not Farm.in_season(crop, GameState.calendar.season_id):
			continue
		var count := GameState.inventory.get_count(crop.seed_item)
		if count > best_count or (count == best_count and count > 0 and crop.id < best.id):
			best = crop
			best_count = count
	return best


func prompt_for(index: int) -> String:
	var plot := farm().get_plot(index)
	if plot == null:
		return ""
	match plot.state:
		Farm.PlotState.EMPTY:
			return DataRegistry.text("prompt_till" if GameState.has_tool(TOOL_HOE) else "prompt_need_hoe")
		Farm.PlotState.TILLED:
			var crop := seed_choice()
			if crop == null:
				return DataRegistry.text("prompt_sow_none")
			return DataRegistry.text("prompt_sow", {
				"seed": DataRegistry.item_name(crop.seed_item), "count": GameState.inventory.get_count(crop.seed_item)})
		Farm.PlotState.GROWING:
			if plot.water >= Farm.FULL_WATER:
				var crop := DataRegistry.get_crop(plot.crop_id)
				return DataRegistry.text("prompt_watered", {
					"name": crop.name_ko if crop != null else plot.crop_id,
					"days": floori(plot.growth), "total": crop.grow_days if crop != null else 0})
			return DataRegistry.text("prompt_water")
		Farm.PlotState.READY:
			var crop := DataRegistry.get_crop(plot.crop_id)
			return DataRegistry.text("prompt_harvest", {"name": crop.name_ko if crop != null else plot.crop_id})
	return ""


func can_act(index: int) -> bool:
	var plot := farm().get_plot(index)
	if plot == null:
		return false
	match plot.state:
		Farm.PlotState.EMPTY:
			return GameState.has_tool(TOOL_HOE)
		Farm.PlotState.TILLED:
			return seed_choice() != null
		Farm.PlotState.GROWING:
			return plot.water < Farm.FULL_WATER
		Farm.PlotState.READY:
			return true
	return false


## 칸 상태에 맞는 한 가지 행동을 한다. 성공하면 true.
func act(index: int) -> bool:
	var plot := farm().get_plot(index)
	if plot == null or not can_act(index):
		return false
	var action := ""
	var crop_id := plot.crop_id
	match plot.state:
		Farm.PlotState.EMPTY:
			if farm().till(index) != Farm.Outcome.OK:
				return false
			action = "till"
			Events.message_posted.emit(DataRegistry.text("msg_tilled"))
		Farm.PlotState.TILLED:
			var crop := seed_choice()
			if farm().sow(index, crop, GameState.inventory, GameState.calendar.season_id) != Farm.Outcome.OK:
				return false
			action = "sow"
			crop_id = crop.id
			Events.item_removed.emit(crop.seed_item, 1)
			Events.message_posted.emit(DataRegistry.text("msg_sown", {"name": crop.name_ko}))
		Farm.PlotState.GROWING:
			if farm().water(index) != Farm.Outcome.OK:
				return false
			action = "water"
			Events.message_posted.emit(DataRegistry.text("msg_watered"))
		Farm.PlotState.READY:
			var result := farm().harvest(index, DataRegistry.crops, GameState.rng)
			if result.is_empty():
				return false
			action = "harvest"
			var item_id := str(result["item"])
			var count := int(result["count"])
			GameState.inventory.add(item_id, count)
			Events.item_added.emit(item_id, count)
			Events.message_posted.emit(DataRegistry.text("msg_harvested", {"name": DataRegistry.item_name(item_id), "count": count}))
	GameState.stamina.spend(_stamina_cost)
	Metrics.record("farm", {"action": action, "plot": index, "crop": crop_id})
	Events.activity_done.emit("farm.%s" % action, crop_id, 1)
	Events.farm_changed.emit(index)
	return true


## 하루 끝 성장. 음기 짙은 날(GameState.is_yin_high)은 마계 작물이 yin_growth_bonus 만큼 더 자란다. 다 자란 칸이 있으면 알린다.
func advance_day() -> void:
	var ripened := farm().advance_day(DataRegistry.crops, GameState.is_yin_high())
	if not ripened.is_empty():
		Events.message_posted.emit(DataRegistry.text("msg_crop_ready", {"count": ripened.size()}))
	Events.farm_changed.emit(-1)


## 비 오는 아침: weather.csv 의 crop_water_bonus 만큼 자라는 칸이 절로 젖는다. 물 준 칸 수를 돌려준다.
func rain_water(weather_id: String) -> int:
	var weather := DataRegistry.get_weather(weather_id)
	if weather == null or weather.crop_water_bonus <= 0.0:
		return 0
	var watered := farm().water_all(weather.crop_water_bonus)
	if watered > 0:
		Events.message_posted.emit(DataRegistry.text("msg_rain_watered", {"count": watered}))
		Events.farm_changed.emit(-1)
	return watered


## 텃밭(FIELD)에 배치된 요괴가 낮에 효율 계수만큼 물을 준다. 물 준 칸 수를 돌려준다.
func auto_water() -> int:
	var total := 0
	for yokai_id in GameState.assignment.workers_at(Assignment.FIELD):
		if not GameState.residents.has(yokai_id):
			continue
		var watered := farm().water_all(_efficiency)
		total += watered
		if watered > 0:
			Events.message_posted.emit(DataRegistry.text("msg_auto_watered", {
				"name": DataRegistry.yokai_name(yokai_id), "count": watered, "percent": roundi(_efficiency * 100.0)}))
			Metrics.record("farm", {"action": "auto_water", "plot": watered, "crop": yokai_id})
	if total > 0:
		Events.farm_changed.emit(-1)
	return total
