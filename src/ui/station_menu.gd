class_name StationMenu
extends ListMenu
## 방 앞에서 여는 작업 메뉴 (P1-S3): 주방 = 요리·배식, 작업장 = 부적 제작·도구 벼리기, 대문간 = 팔기.
## 규칙·상태는 StationSystem 이 갖고 여기서는 행만 그린다. 열려 있는 동안 작업대·창고가 바뀌면 다시 그린다.

enum Mode { COOK, CRAFT, SELL }

var station_system: StationSystem
## (coords: Vector2i) -> void. "개조" 줄이 건설 메뉴로 넘긴다. main.gd 가 넣는다.
var open_renovate: Callable

var mode: Mode = Mode.COOK
var _coords: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	super()
	Events.station_changed.connect(func(_id: String) -> void: _refresh_if_open())
	Events.item_added.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.item_removed.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.money_changed.connect(func(_amount: int) -> void: _refresh_if_open())
	Events.tool_changed.connect(func(_kind: String, _level: int) -> void: _refresh_if_open())


func open_cook(coords: Vector2i) -> void:
	_open(Mode.COOK, coords, "ui_cook_title")


func open_craft(coords: Vector2i) -> void:
	_open(Mode.CRAFT, coords, "ui_craft_title")


func open_sell(coords: Vector2i) -> void:
	_open(Mode.SELL, coords, "ui_sell_title")


func refresh() -> void:
	clear_rows()
	# '개조'는 목록이 길어도 보이도록 맨 위에 둔다 (건설 메뉴로 넘긴다)
	if _coords != Vector2i(-1, -1) and open_renovate.is_valid():
		add_row(DataRegistry.room_name(GameState.room_grid.get_room_id(_coords)), DataRegistry.text("ui_menu_renovate"),
			func() -> void:
				var coords := _coords
				close()
				open_renovate.call(coords))
	match mode:
		Mode.COOK:
			_build_cook()
		Mode.CRAFT:
			_build_craft()
		Mode.SELL:
			_build_sell()


func _open(new_mode: Mode, coords: Vector2i, title_key: String) -> void:
	mode = new_mode
	_coords = coords
	open_with_title(DataRegistry.text(title_key))
	refresh()


func _refresh_if_open() -> void:
	if visible:
		refresh()


func _build_cook() -> void:
	var kitchen := GameState.station(GameState.STATION_KITCHEN)
	if kitchen.is_busy():
		add_header(DataRegistry.text("ui_station_busy", {
			"name": DataRegistry.item_name(kitchen.output_item), "seconds": ceili(kitchen.remaining_seconds)}))
	else:
		add_header(DataRegistry.text("ui_station_idle"))
	for recipe in DataRegistry.recipes_sorted():
		if not station_system.is_recipe_unlocked(recipe):
			add_row(DataRegistry.text("ui_recipe_locked", {"name": recipe.name_ko, "tier": recipe.tier}))
			continue
		var text := DataRegistry.text("ui_recipe_row", {
			"name": recipe.name_ko, "ingredients": _cost_text(recipe.ingredients), "seconds": roundi(recipe.cook_seconds)})
		add_row(text, DataRegistry.text("ui_cook"), func() -> void: station_system.start_cook(recipe.id),
			station_system.can_cook(recipe))
	var dishes := station_system.servable_dishes()
	if dishes.is_empty() or GameState.residents.is_empty():
		return
	add_header(DataRegistry.text("ui_serve_header"))
	for dish_id in dishes:
		var recipe := DataRegistry.recipe_for_dish(dish_id)
		for yokai_id in GameState.residents:
			var text := DataRegistry.text("ui_serve_row", {
				"name": recipe.name_ko, "yokai": DataRegistry.yokai_name(yokai_id),
				"stat": DataRegistry.text("stat_%s" % recipe.buff_stat), "amount": recipe.buff_amount})
			add_row(text, DataRegistry.text("ui_cook"), func() -> void: station_system.serve(dish_id, yokai_id))


func _build_craft() -> void:
	var workshop := GameState.station(GameState.STATION_WORKSHOP)
	if workshop.is_busy():
		add_header(DataRegistry.text("ui_craft_busy", {
			"name": DataRegistry.item_name(workshop.output_item), "seconds": ceili(workshop.remaining_seconds)}))
	for talisman in station_system.available_talismans():
		var text := DataRegistry.text("ui_craft_row", {
			"name": talisman.name_ko, "cost": _cost_text(talisman.craft_cost), "seconds": roundi(talisman.craft_seconds)})
		add_row(text, DataRegistry.text("ui_craft"), func() -> void: station_system.start_craft(talisman.id),
			station_system.can_craft(talisman))
	for tool in station_system.available_upgrades():
		var text := DataRegistry.text("ui_upgrade_row", {"name": tool.name_ko, "cost": _cost_text(tool.upgrade_cost)})
		add_row(text, DataRegistry.text("ui_craft"), func() -> void: station_system.upgrade_tool(tool.id),
			station_system.can_upgrade(tool))


func _build_sell() -> void:
	var ids := station_system.sellable_ids()
	if ids.is_empty():
		add_header(DataRegistry.text("ui_nothing_to_sell"))
		return
	for item_id in ids:
		var count := GameState.inventory.get_count(item_id)
		var price := station_system.unit_price(item_id)
		var text := DataRegistry.text("ui_sell_row", {"name": DataRegistry.item_name(item_id), "count": count, "price": price})
		add_row(text, DataRegistry.text("ui_sell_all", {"name": DataRegistry.item_name(item_id), "total": price * count}),
			func() -> void: station_system.sell(item_id, GameState.inventory.get_count(item_id)))


func _cost_text(costs: Array) -> String:
	var parts: Array[String] = []
	for entry: Variant in costs:
		var cost := WorkStation.parse_cost(str(entry))
		if cost.is_empty():
			continue
		parts.append("%s %d" % [DataRegistry.item_name(cost[0]), cost[1]])
	return ", ".join(parts)
