class_name FestivalSystem
extends Node
## festivals.csv 의 런타임 측 (P2-S2 동지). 당일 아침: 알림 + 장식(festival_started). 저녁: 하숙비 정산 직후(rent_settled — 심사 추첨보다 앞)
## 팥죽을 나누고 채점·보상하며, 만점이면 그날 밤 희귀 손님을 예약한다(플래그에 종족 id). 순수 채점은 FestivalRules.

const FLAG_RARE_PENDING := "festival_rare_pending"

var goal_system: GoalSystem
## 오늘 집에 있었던 손님의 최대 수 (채점의 '손님' 항)
var _guests_seen_today: int = 0


func _ready() -> void:
	Events.day_started.connect(_on_day_started)
	Events.guests_changed.connect(func() -> void:
		_guests_seen_today = maxi(_guests_seen_today, GameState.guests.size()))
	Events.rent_settled.connect(func(_rent: Dictionary) -> void: score_today())


## 오늘의 명절. 없으면 null.
func today() -> FestivalData:
	var calendar := GameState.calendar
	for festival: FestivalData in DataRegistry.festivals.values():
		if FestivalRules.is_today(festival, calendar.season_id, calendar.day_of_season):
			return festival
	return null


func is_festival_today() -> bool:
	return today() != null


## 준비 목표 충족 수 / 전체 (완료 기록이 아니라 지금 상태).
func prep_progress(festival: FestivalData) -> Vector2i:
	var met := 0
	for goal_id in festival.goal_ids:
		if goal_system != null and goal_system.is_satisfied(goal_id):
			met += 1
	return Vector2i(met, festival.goal_ids.size())


func is_decorated(festival: FestivalData) -> bool:
	return goal_system != null and not festival.decor_goal.is_empty() and goal_system.is_satisfied(festival.decor_goal)


func _on_day_started(_day: int) -> void:
	_guests_seen_today = GameState.guests.size()
	var festival := today()
	if festival == null:
		return
	var prep := prep_progress(festival)
	Events.festival_started.emit(festival.id, is_decorated(festival))
	Events.message_posted.emit(DataRegistry.text("msg_festival_today", {"name": festival.name_ko, "met": prep.x, "total": prep.y}))
	Metrics.record("festival_started", {"festival": festival.id, "met": prep.x, "total": prep.y})


## 명절 당일 채점. 점수를 돌려주고, 명절이 아니거나 이미 채점했으면 -1.
func score_today() -> int:
	var festival := today()
	if festival == null or GameState.festival_results.has(festival.id):
		return -1
	var tally := FestivalRules.Tally.new()
	tally.goals_met = prep_progress(festival).x
	tally.guests = _guests_seen_today
	tally.dishes = _share_dishes(festival)
	var score := FestivalRules.score(festival, tally)
	var max_score := FestivalRules.max_score(festival)
	GameState.festival_results[festival.id] = score
	var reputation := festival.reward_reputation
	if FestivalRules.is_perfect(festival, score):
		reputation += festival.perfect_reward_reputation
		if not festival.rare_guest_species.is_empty():
			GameState.flags[FLAG_RARE_PENDING] = festival.rare_guest_species
	if festival.reward_money > 0:
		GameState.add_money(festival.reward_money)
	if reputation > 0:
		GameState.add_reputation(reputation)
	Events.message_posted.emit(DataRegistry.text("msg_festival_scored", {
		"name": festival.name_ko, "score": score, "max": max_score, "money": festival.reward_money, "reputation": reputation}))
	if FestivalRules.is_perfect(festival, score):
		Events.message_posted.emit(DataRegistry.text("msg_festival_perfect"))
	Metrics.record("festival_scored", {"festival": festival.id, "score": score, "max": max_score})
	Events.festival_scored.emit(festival.id, score, max_score)
	return score


## 창고의 명절 요리를 상한까지 나눈다(소모). 나눈 그릇 수.
func _share_dishes(festival: FestivalData) -> int:
	var recipe := DataRegistry.get_recipe(festival.dish_recipe)
	if recipe == null or festival.dish_target <= 0:
		return 0
	var count := mini(GameState.inventory.get_count(recipe.output_item), festival.dish_target)
	if count <= 0:
		return 0
	GameState.inventory.remove(recipe.output_item, count)
	Events.item_removed.emit(recipe.output_item, count)
	Events.message_posted.emit(DataRegistry.text("msg_festival_dishes", {"name": recipe.name_ko, "count": count}))
	return count
