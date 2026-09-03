class_name TestGoalRules
extends GdUnitTestSuite
## 목표 조건 문법(정량·불리언 절), 진행도, 날 창, 새 완료 판정, 층위 정렬 + 명절 채점 (P2-S2).


func _goal(id: String, tier: String, condition: String, day_min: int = 1, day_max: int = 0) -> GoalData:
	var goal := GoalData.new()
	goal.id = id
	goal.tier = tier
	goal.name_ko = id
	goal.condition = condition
	goal.day_min = day_min
	goal.day_max = day_max
	return goal


func _ctx() -> GoalRules.Context:
	var ctx := GoalRules.Context.new()
	ctx.day = 5
	ctx.inventory.add("dish_patjuk", 2)
	ctx.counters = {"gather": 7, "cook.r_patjuk": 1, "farm.till": 3}
	ctx.ledger = {"g_a": 3, "g_b": 1}
	ctx.affinity = {"y01": 2}
	ctx.residents = ["y01"]
	ctx.unlocked = {"u_hoe": 1}
	ctx.flags = {"clue": true}
	ctx.money = 500
	ctx.reputation = 4
	ctx.festival_results = {"f_dongji": 9}
	ctx.beds = 4
	return ctx


func test_parse_clause_forms() -> void:
	var a := GoalRules.parse_clause("count:cook.r_patjuk>=1")
	assert_str(a.name).is_equal("count")
	assert_str(a.target).is_equal("cook.r_patjuk")
	assert_int(a.amount).is_equal(1)
	assert_bool(a.quantitative).is_true()
	var b := GoalRules.parse_clause("ledger>=5")
	assert_str(b.name).is_equal("ledger")
	assert_str(b.target).is_equal("")
	assert_int(b.amount).is_equal(5)
	var c := GoalRules.parse_clause("resident:y01")
	assert_str(c.name).is_equal("resident")
	assert_str(c.target).is_equal("y01")
	assert_bool(c.quantitative).is_false()
	assert_int(c.amount).is_equal(GoalRules.BOOL_TARGET)


func test_current_values_and_condition() -> void:
	var ctx := _ctx()
	assert_bool(GoalRules.condition_holds("count:gather>=5", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("count:gather>=8", ctx)).is_false()
	assert_bool(GoalRules.condition_holds("ledger>=4", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("species>=2;item:dish_patjuk>=2", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("species>=3", ctx)).is_false()
	assert_bool(GoalRules.condition_holds("resident:y01;unlock:u_hoe;flag:clue", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("resident:y02", ctx)).is_false()
	assert_bool(GoalRules.condition_holds("money>=500;reputation>=4;beds>=4", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("festival:f_dongji>=11", ctx)).is_false()
	assert_bool(GoalRules.condition_holds("affinity:y01>=2", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("rooms:guest_room>=1", ctx)).is_false()  # 그리드 없음 → 0
	assert_bool(GoalRules.condition_holds("nonsense:x>=1", ctx)).is_false()
	assert_bool(GoalRules.condition_holds("", ctx)).is_true()


func test_progress_reports_first_quantitative_clause_or_met_count() -> void:
	var ctx := _ctx()
	assert_that(GoalRules.progress("count:gather>=10", ctx)).is_equal(Vector2i(7, 10))
	assert_that(GoalRules.progress("count:gather>=5", ctx)).is_equal(Vector2i(5, 5))  # 목표 넘어도 목표에서 멈춤
	assert_that(GoalRules.progress("resident:y01;unlock:u_axe;flag:clue", ctx)).is_equal(Vector2i(2, 3))
	assert_that(GoalRules.progress("resident:y01;item:dish_patjuk>=3", ctx)).is_equal(Vector2i(2, 3))


func test_window_active_and_newly_completed_sorted_by_tier() -> void:
	var goals := {
		"g_long": _goal("g_long", "long", "affinity:y01>=2"),
		"g_today_late": _goal("g_today_late", "today", "count:gather>=1", 6, 8),
		"g_today": _goal("g_today", "today", "count:farm.till>=3", 1, 5),
		"g_season": _goal("g_season", "season", "item:dish_patjuk>=2", 1, 28),
		"g_expired": _goal("g_expired", "today", "count:gather>=1", 1, 4),
		"g_open": _goal("g_open", "season", "item:dish_patjuk>=3", 1, 28),
	}
	var ctx := _ctx()
	assert_bool(GoalRules.in_window(goals["g_today"], 5)).is_true()
	assert_bool(GoalRules.in_window(goals["g_today"], 6)).is_false()
	assert_bool(GoalRules.in_window(goals["g_long"], 999)).is_true()
	var done := {"g_season": 3}
	var fresh := GoalRules.newly_completed(goals, ctx, done)
	var ids: Array[String] = []
	for goal in fresh:
		ids.append(goal.id)
	# 만료(g_expired)·창 이전(g_today_late)·이미 완료(g_season)·미충족(g_open) 제외, 오늘 → 장기 순
	assert_array(ids).contains_exactly(["g_today", "g_long"])
	var visible := GoalRules.visible(goals, 5, ["today", "season"])
	var visible_ids: Array[String] = []
	for goal in visible:
		visible_ids.append(goal.id)
	assert_array(visible_ids).contains_exactly(["g_today", "g_open", "g_season"])


func test_festival_score_and_perfect() -> void:
	var festival := FestivalData.new()
	festival.id = "f_dongji"
	festival.goal_ids = ["a", "b", "c"]
	festival.score_per_goal = 2
	festival.guest_target = 2
	festival.score_per_guest = 1
	festival.dish_target = 3
	festival.score_per_dish = 1
	assert_int(FestivalRules.max_score(festival)).is_equal(11)
	var tally := FestivalRules.Tally.new()
	tally.goals_met = 2
	tally.guests = 5  # 상한 2
	tally.dishes = 1
	assert_int(FestivalRules.score(festival, tally)).is_equal(4 + 2 + 1)
	assert_bool(FestivalRules.is_perfect(festival, 7)).is_false()
	tally.goals_met = 3
	tally.dishes = 3
	assert_int(FestivalRules.score(festival, tally)).is_equal(11)
	assert_bool(FestivalRules.is_perfect(festival, 11)).is_true()
	festival.season = "spring"
	festival.day_of_season = 28
	assert_bool(FestivalRules.is_today(festival, "spring", 28)).is_true()
	assert_bool(FestivalRules.is_today(festival, "summer", 28)).is_false()
	assert_bool(FestivalRules.is_today(festival, "spring", 27)).is_false()
