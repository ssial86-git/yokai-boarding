class_name TestFestivalFlow
extends GdUnitTestSuite
## P2-S2 통합: 활동 → 카운터 → 목표 완료·보상, 할 일 요약, 동지 당일(봄 28일) 아침 장식 → 저녁 정산 채점 → 만점 보상·희귀 손님 예약 → 심사 카드.

var _day_cycle: DayCycle
var _goal_system: GoalSystem
var _festival_system: FestivalSystem
var _intake_system: IntakeSystem


func before_test() -> void:
	GameState.reset_new_game()
	_day_cycle = auto_free(DayCycle.new())
	add_child(_day_cycle)
	_intake_system = auto_free(IntakeSystem.new())
	add_child(_intake_system)
	_goal_system = auto_free(GoalSystem.new())
	add_child(_goal_system)
	_festival_system = auto_free(FestivalSystem.new())
	_festival_system.goal_system = _goal_system
	add_child(_festival_system)


func after_test() -> void:
	Clock.running = false


func test_activity_counters_complete_goals_with_rewards() -> void:
	var money := GameState.money
	var completed: Array[String] = []
	var on_goal := func(goal_id: String) -> void: completed.append(goal_id)
	Events.goal_completed.connect(on_goal)
	Events.activity_done.emit("farm.till", "", 2)
	assert_int(int(GameState.counters["farm.till"])).is_equal(2)
	assert_bool(_goal_system.is_done("g_t_till")).is_false()
	assert_that(_goal_system.progress(DataRegistry.get_goal("g_t_till"))).is_equal(Vector2i(2, 3))
	Events.activity_done.emit("farm.till", "", 1)
	Events.goal_completed.disconnect(on_goal)
	assert_array(completed).contains_exactly(["g_t_till"])
	assert_bool(_goal_system.is_done("g_t_till")).is_true()
	assert_int(GameState.money).is_equal(money + DataRegistry.get_goal("g_t_till").reward_money)
	assert_int(int(GameState.goals_done["g_t_till"])).is_equal(GameState.day)
	# 상세 키도 함께 쌓인다 (cook.r_patjuk 같은 조건용)
	Events.activity_done.emit("cook", "r_patjuk", 1)
	assert_int(int(GameState.counters["cook"])).is_equal(1)
	assert_int(int(GameState.counters["cook.r_patjuk"])).is_equal(1)
	# 요약: 1일차 창 안의 오늘·절기 목표 중 완료 1
	var summary := _goal_system.summary()
	assert_int(summary.x).is_equal(1)
	assert_int(summary.y).is_greater_equal(3)
	# 창에 들어서면 이미 쌓인 누계로도 완료된다; 만료된 창의 목표는 완료되지 않는다
	assert_bool(_goal_system.is_done("g_t_cook_first")).is_false()  # 1일차: 2~5일 창 이전
	GameState.day = 4
	Events.activity_done.emit("gather", "m_namul", 5)
	assert_bool(_goal_system.is_done("g_t_gather")).is_true()  # 2~4일 창 안
	assert_bool(_goal_system.is_done("g_t_cook_first")).is_true()  # 4일차에 창 안 + cook 누계 1
	GameState.day = 9
	Events.activity_done.emit("fish", "f_minnow", 2)
	assert_bool(_goal_system.is_done("g_t_fish")).is_false()  # 4~8일 창 밖


func test_dongji_day_scores_perfect_and_books_rare_guest() -> void:
	# 봄 28일로 이동, 준비 목표 3개를 채운다: 팥죽 3, 손님 누계 5, 객실 2
	GameState.day = 28
	assert_bool(GameState.calendar.from_dict({"season": "spring", "day_of_season": 28}, DataRegistry.seasons)).is_true()
	GameState.money = 5000
	assert_int(GameState.room_grid.place_room(Vector2i(3, 0), "guest_room", GameState.money)).is_equal(RoomGrid.Outcome.OK)
	assert_int(GameState.room_grid.count_rooms("guest_room")).is_greater_equal(2)
	GameState.ledger["g_mongdanggwi"] = 3
	GameState.ledger["g_ibulnang"] = 2
	GameState.inventory.add("dish_patjuk", 4)
	for i in 2:
		GameState.guests.append({"species_id": "g_mongdanggwi", "visitor_id": "v_guest", "arrived_day": 27, "depart_day": 30, "omen": 0})
	Events.guests_changed.emit()
	assert_bool(_festival_system.is_festival_today()).is_true()
	var dongji := _festival_system.today()
	assert_that(_festival_system.prep_progress(dongji)).is_equal(Vector2i(3, 3))

	var started := {"id": "", "decorated": false}
	var on_started := func(festival_id: String, decorated: bool) -> void:
		started["id"] = festival_id
		started["decorated"] = decorated
	Events.festival_started.connect(on_started)
	Clock.start_day()
	Events.festival_started.disconnect(on_started)
	assert_str(str(started["id"])).is_equal("f_dongji")
	assert_bool(bool(started["decorated"])).is_true()

	var money := GameState.money
	var reputation := GameState.reputation
	Clock.advance_to_band(Clock.Band.EVENING)  # 정산 → rent_settled(채점) → day_settled(심사 추첨)
	assert_int(int(GameState.festival_results["f_dongji"])).is_equal(FestivalRules.max_score(dongji))
	assert_int(GameState.inventory.get_count("dish_patjuk")).is_equal(1)  # 3그릇을 나눴다
	assert_int(GameState.money).is_greater_equal(money + dongji.reward_money)
	assert_int(GameState.reputation).is_greater_equal(reputation + dongji.reward_reputation + dongji.perfect_reward_reputation)
	# 만점 → 그날 밤 희귀 손님(금주리)이 심사 카드로 온다. 플래그는 소모된다
	assert_str(str(GameState.pending_visitor.get("species_id"))).is_equal("g_geumjuri")
	assert_bool(GameState.flags.has(FestivalSystem.FLAG_RARE_PENDING)).is_false()
	# 장기 목표 '동지 만점' 완료
	assert_bool(_goal_system.is_done("g_l_festival")).is_true()
	# 같은 날 두 번 채점하지 않는다
	assert_int(_festival_system.score_today()).is_equal(-1)


func test_dongji_partial_score_no_rare_guest() -> void:
	GameState.day = 28
	assert_bool(GameState.calendar.from_dict({"season": "spring", "day_of_season": 28}, DataRegistry.seasons)).is_true()
	GameState.inventory.add("dish_patjuk", 1)
	Clock.start_day()
	Clock.advance_to_band(Clock.Band.EVENING)
	var dongji := DataRegistry.get_festival("f_dongji")
	var score := int(GameState.festival_results["f_dongji"])
	assert_int(score).is_equal(1)  # 목표 0 · 손님 0 · 팥죽 1그릇
	assert_bool(FestivalRules.is_perfect(dongji, score)).is_false()
	assert_bool(GameState.flags.has(FestivalSystem.FLAG_RARE_PENDING)).is_false()
	assert_bool(_goal_system.is_done("g_l_festival")).is_false()
