class_name DayCycle
extends Node
## 하루 사이클의 시스템 측: 아침 날씨, 저녁 진입 시 정산(시설 산출 → 하숙비 → 손님 체크아웃 → 컨디션),
## 방이 바뀌면 무효해진 배치 정리. 시간은 Clock 이 흘리고 여기서는 시간대 트리거만 받는다.

const RAIN := "rain"


func _ready() -> void:
	Events.timeband_changed.connect(_on_timeband_changed)
	Events.day_started.connect(_on_day_started)
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: prune_assignment())
	Events.floor_added.connect(func(_floor: int) -> void: prune_assignment())


func _on_day_started(_day: int) -> void:
	roll_weather()


func _on_timeband_changed(band: int, _day: int) -> void:
	if band == Clock.Band.EVENING:
		settle()


func roll_weather() -> void:
	var rain_chance := DataRegistry.tuning.get_float("rain_chance")
	GameState.weather = RAIN if GameState.rng.randf() < rain_chance else GameState.WEATHER_CLEAR
	Events.weather_changed.emit(GameState.weather)


func settle() -> DaySettlement.Result:
	var params := DaySettlement.Params.from_tuning(DataRegistry.tuning)
	var result := DaySettlement.settle(
		GameState.room_grid, GameState.assignment, GameState.residents,
		DataRegistry.yokai, GameState.conditions, params,
	)
	var totals := result.totals()
	for item_id: String in totals:
		GameState.inventory.add(item_id, int(totals[item_id]))
		Events.item_added.emit(item_id, int(totals[item_id]))
	for yokai_id: String in result.conditions:
		GameState.conditions[yokai_id] = int(result.conditions[yokai_id])

	var rent := settle_rent(params.condition_max)
	for yokai_id: String in GameState.conditions:
		Events.condition_changed.emit(yokai_id, int(GameState.conditions[yokai_id]))
	Events.day_settled.emit({
		"day": GameState.day,
		"totals": totals,
		"noise_hits": result.noise_hits.duplicate(),
		"rent": rent,
	})
	return result


## 하숙생 하숙비 + 떠나는 손님 숙박비. 반영 후 요약 Dictionary 를 돌려주고 rent_settled 를 쏜다.
func settle_rent(condition_max: int) -> Dictionary:
	var day := GameState.day
	var residents := Rent.settle_residents(GameState.residents, DataRegistry.yokai, DataRegistry.items, day, GameState.rng)
	var guests := Rent.settle_guests(GameState.guests, DataRegistry.guest_species, DataRegistry.visitors, day)
	# 손님 만족 (P1-S3 요리 3중 용도): 떠나는 손님이 좋아하는 요리가 창고에 있으면 먹고 돈을 더 낸다
	var dish_bonus := 0
	var dish_texts: Array[String] = []
	var bonus_each := DataRegistry.tuning.get_int("guest_dish_bonus_money")
	for guest in guests.departed:
		var species := DataRegistry.get_guest_species(str(guest.get("species_id", "")))
		var recipe := DataRegistry.get_recipe(species.liked_recipe) if species != null else null
		if recipe == null or not GameState.inventory.remove(recipe.output_item, 1):
			continue
		Events.item_removed.emit(recipe.output_item, 1)
		dish_bonus += bonus_each
		dish_texts.append(DataRegistry.text("msg_guest_liked_dish", {
			"guest": species.name_ko, "dish": recipe.name_ko, "money": bonus_each}))
	var money := residents.money + guests.money + dish_bonus - guests.mishap_money
	var items: Dictionary = residents.items.duplicate()
	for item_id: String in guests.items:
		items[item_id] = int(items.get(item_id, 0)) + int(guests.items[item_id])
	var bonus := residents.condition_bonus + guests.condition_bonus

	if money != 0:
		GameState.add_money(money)
	for item_id: String in items:
		GameState.inventory.add(item_id, int(items[item_id]))
		Events.item_added.emit(item_id, int(items[item_id]))
	if bonus > 0:
		for yokai_id in GameState.residents:
			GameState.conditions[yokai_id] = mini(GameState.get_condition(yokai_id) + bonus, condition_max)
	for guest in guests.departed:
		GameState.guests.erase(guest)
	if not guests.departed.is_empty():
		Events.guests_changed.emit()

	var summary := {
		"money": residents.money + guests.money + dish_bonus,
		"dish_bonus": dish_bonus,
		"dish_texts": dish_texts,
		"items": items,
		"condition_bonus": bonus,
		"mishap_money": guests.mishap_money,
		"mishap_texts": guests.mishap_texts.duplicate(),
		"departed": guests.departed.duplicate(),
		"payments": residents.payments + guests.payments,
	}
	Events.rent_settled.emit(summary)
	return summary


func prune_assignment() -> void:
	for yokai_id in GameState.assignment.prune(GameState.room_grid, GameState.residents):
		Events.assignment_changed.emit(yokai_id, Assignment.REST)
