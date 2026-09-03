class_name StationSystem
extends Node
## 작업대의 노드 측 (P1-S3): 가마솥 요리·작업장 부적 제작·도구 벼리기·배식(동료 버프)·판매.
## 실시간으로 작업을 익히되 대화·심사 중(Clock hold)에는 멈춘다. 순수 계산은 WorkStation/Market.

const FEATURE_TIER_FORMAT := "recipes_tier%d"
const UNLOCK_TYPE_RECIPE := "recipe"
const BUFF_NONE := "none"
const TYPE_TALISMAN := "talisman"
const TYPE_TOOL := "tool"

var unlock_system: UnlockSystem

var _sell_ratio: float = 1.0


func _ready() -> void:
	_sell_ratio = DataRegistry.tuning.get_float("sell_price_ratio", _sell_ratio)
	Events.day_started.connect(func(_day: int) -> void: GameState.buffs.clear())


func _process(delta: float) -> void:
	if Clock.is_held():
		return
	tick_all(delta)


## 모든 작업대에 시간을 흘린다 (테스트·디버그도 이 함수를 부른다).
func tick_all(seconds: float) -> void:
	for station_id: String in GameState.stations:
		var station := GameState.station(station_id)
		if station.tick(seconds):
			_finish(station_id, station)


func _finish(station_id: String, station: WorkStation) -> void:
	var result := station.collect()
	if result.is_empty():
		return
	var item_id := str(result["item"])
	var count := int(result["count"])
	GameState.inventory.add(item_id, count)
	Events.item_added.emit(item_id, count)
	var name := DataRegistry.item_name(item_id)
	if str(result["kind"]) == WorkStation.KIND_COOK:
		Events.message_posted.emit(DataRegistry.text("msg_cook_done", {"name": name}))
		var recipe := DataRegistry.get_recipe(str(result["id"]))
		Metrics.record("cook", {"recipe": str(result["id"]), "seconds": recipe.cook_seconds if recipe != null else 0.0})
		Events.activity_done.emit("cook", str(result["id"]), count)
	else:
		Events.message_posted.emit(DataRegistry.text("msg_craft_done", {"name": name}))
		Metrics.record("craft", {"item": item_id, "count": count})
		Events.activity_done.emit("craft", item_id, count)
	Events.station_changed.emit(station_id)


# --- 요리 ---

## 티어 해금(feature recipes_tierN) + 개별 레시피 해금(unlock_type recipe, 가리키는 행이 없으면 열림).
func is_recipe_unlocked(recipe: RecipeData) -> bool:
	if unlock_system == null:
		return true
	return unlock_system.is_feature_open(FEATURE_TIER_FORMAT % recipe.tier) \
		and unlock_system.is_target_open(UNLOCK_TYPE_RECIPE, recipe.id)


func available_recipes() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe in DataRegistry.recipes_sorted():
		if is_recipe_unlocked(recipe):
			result.append(recipe)
	return result


func can_cook(recipe: RecipeData) -> bool:
	return recipe != null and is_recipe_unlocked(recipe) \
		and not GameState.station(GameState.STATION_KITCHEN).is_busy() \
		and WorkStation.has_ingredients(recipe.ingredients, GameState.inventory)


func start_cook(recipe_id: String) -> WorkStation.Outcome:
	var recipe := DataRegistry.get_recipe(recipe_id)
	if recipe == null or not is_recipe_unlocked(recipe):
		return WorkStation.Outcome.INVALID
	var outcome := GameState.station(GameState.STATION_KITCHEN).start(
		WorkStation.KIND_COOK, recipe.id, recipe.ingredients, recipe.cook_seconds,
		recipe.output_item, recipe.output_count, GameState.inventory)
	_report_start(outcome, "msg_cook_started", recipe.name_ko, recipe.cook_seconds, recipe.ingredients)
	if outcome == WorkStation.Outcome.OK:
		Events.station_changed.emit(GameState.STATION_KITCHEN)
	return outcome


# --- 제작·벼리기 ---

func is_talisman_unlocked(talisman_id: String) -> bool:
	return unlock_system == null or unlock_system.is_target_open(TYPE_TALISMAN, talisman_id)


func available_talismans() -> Array[TalismanData]:
	var result: Array[TalismanData] = []
	for talisman: TalismanData in DataRegistry.talismans.values():
		if is_talisman_unlocked(talisman.id):
			result.append(talisman)
	result.sort_custom(func(a: TalismanData, b: TalismanData) -> bool: return a.id < b.id)
	return result


func can_craft(talisman: TalismanData) -> bool:
	return talisman != null and is_talisman_unlocked(talisman.id) \
		and not GameState.station(GameState.STATION_WORKSHOP).is_busy() \
		and WorkStation.has_ingredients(talisman.craft_cost, GameState.inventory)


func start_craft(talisman_id: String) -> WorkStation.Outcome:
	var talisman := DataRegistry.get_talisman(talisman_id)
	if talisman == null or not is_talisman_unlocked(talisman_id):
		return WorkStation.Outcome.INVALID
	var outcome := GameState.station(GameState.STATION_WORKSHOP).start(
		WorkStation.KIND_CRAFT, talisman.id, talisman.craft_cost, talisman.craft_seconds,
		talisman.id, 1, GameState.inventory)
	_report_start(outcome, "msg_craft_started", talisman.name_ko, talisman.craft_seconds, talisman.craft_cost)
	if outcome == WorkStation.Outcome.OK:
		Events.station_changed.emit(GameState.STATION_WORKSHOP)
	return outcome


## 지금 들고 있는 도구의 바로 다음 레벨 중 해금된 것.
func available_upgrades() -> Array[ToolData]:
	var result: Array[ToolData] = []
	for tool: ToolData in DataRegistry.tools.values():
		if tool.upgrade_from.is_empty():
			continue
		var current := DataRegistry.get_tool(tool.upgrade_from)
		if current == null or int(GameState.tools.get(tool.kind, 0)) != current.level:
			continue
		if unlock_system != null and not unlock_system.is_target_open(TYPE_TOOL, tool.id):
			continue
		result.append(tool)
	result.sort_custom(func(a: ToolData, b: ToolData) -> bool: return a.id < b.id)
	return result


func can_upgrade(tool: ToolData) -> bool:
	return tool != null and available_upgrades().has(tool) and WorkStation.has_ingredients(tool.upgrade_cost, GameState.inventory)


## 재료를 내고 도구 레벨을 올린다 (즉시).
func upgrade_tool(tool_id: String) -> bool:
	var tool := DataRegistry.get_tool(tool_id)
	if not can_upgrade(tool):
		Events.message_posted.emit(DataRegistry.text("msg_missing_ingredients"))
		return false
	for entry: Variant in tool.upgrade_cost:
		var cost := WorkStation.parse_cost(str(entry))
		GameState.inventory.remove(cost[0], cost[1])
		Events.item_removed.emit(cost[0], cost[1])
	GameState.set_tool_level(tool.kind, tool.level)
	Events.message_posted.emit(DataRegistry.text("msg_tool_upgraded", {
		"tool": DataRegistry.text("tool_%s" % tool.kind), "level": tool.level}))
	Metrics.record("upgrade", {"tool": tool.id, "level": tool.level})
	Events.activity_done.emit("upgrade", tool.id, 1)
	return true


# --- 배식 (동료 버프) ---

## 창고에 있는 요리 중 버프가 있는 것 (item id).
func servable_dishes() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in GameState.inventory.items():
		var recipe := DataRegistry.recipe_for_dish(item_id)
		if recipe != null and recipe.buff_stat != BUFF_NONE:
			result.append(item_id)
	result.sort()
	return result


func serve(dish_item_id: String, yokai_id: String) -> bool:
	var recipe := DataRegistry.recipe_for_dish(dish_item_id)
	if recipe == null or recipe.buff_stat == BUFF_NONE or not GameState.residents.has(yokai_id):
		return false
	if not GameState.inventory.remove(dish_item_id, 1):
		return false
	Events.item_removed.emit(dish_item_id, 1)
	# 요리 가호 (P2-S3): 기본 + 시너지(먹는 하숙생·버프 능력치)
	var amount := recipe.buff_amount + BlessingSystem.dish_bonus(BlessingRules.blessing_of(dish_item_id), recipe, yokai_id)
	GameState.add_buff(yokai_id, recipe.buff_stat, amount)
	GameState.stamina.spend(DataRegistry.tuning.get_float("serve_stamina_cost", 0.0))
	Events.message_posted.emit(DataRegistry.text("msg_served", {
		"yokai": DataRegistry.yokai_name(yokai_id), "name": DataRegistry.item_name(dish_item_id),
		"stat": DataRegistry.text("stat_%s" % recipe.buff_stat), "amount": amount}))
	Metrics.record("serve", {"recipe": recipe.id, "yokai": yokai_id, "stat": recipe.buff_stat})
	Events.activity_done.emit("serve", recipe.id, 1)
	return true


# --- 판매 ---

func unit_price(item_id: String) -> int:
	return Market.unit_price(DataRegistry.get_item(item_id), _sell_ratio)


func sellable_ids() -> Array[String]:
	return Market.sellable_ids(GameState.inventory, DataRegistry.items)


func sell(item_id: String, count: int) -> int:
	var money := Market.sell(GameState.inventory, DataRegistry.items, item_id, count, _sell_ratio)
	if money <= 0:
		return 0
	Events.item_removed.emit(item_id, count)
	GameState.add_money(money)
	Events.message_posted.emit(DataRegistry.text("msg_sold", {
		"name": DataRegistry.item_name(item_id), "count": count, "money": money}))
	Metrics.record("sell", {"item": item_id, "count": count, "money": money})
	Events.activity_done.emit("sell", item_id, count)
	return money


func _report_start(outcome: WorkStation.Outcome, key: String, name: String, seconds: float, costs: Array) -> void:
	match outcome:
		WorkStation.Outcome.OK:
			Events.message_posted.emit(DataRegistry.text(key, {"name": name, "seconds": roundi(seconds)}))
			for entry: Variant in costs:
				var cost := WorkStation.parse_cost(str(entry))
				Events.item_removed.emit(cost[0], cost[1])
		WorkStation.Outcome.BUSY:
			Events.message_posted.emit(DataRegistry.text("msg_station_busy"))
		WorkStation.Outcome.MISSING_INGREDIENTS:
			Events.message_posted.emit(DataRegistry.text("msg_missing_ingredients"))
		_:
			pass
