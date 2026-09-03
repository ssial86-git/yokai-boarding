class_name GoalSystem
extends Node
## goals.csv 의 런타임 측 (P2-S2 목표 층위 3: 오늘 / 이번 절기 / 장기). 활동(activity_done)을 GameState.counters 에 누적하고,
## 상태가 바뀔 때마다 GoalRules 로 새로 완료된 목표를 찾아 GameState.goals_done 에 적고 보상·알림·지표. 순수 판정은 GoalRules.

const COUNTER_SEPARATOR := "."
const SUMMARY_TIERS: Array[String] = [GoalRules.TIER_TODAY, GoalRules.TIER_SEASON]


func _ready() -> void:
	Events.activity_done.connect(_on_activity)
	for refresh_signal: Signal in [
		Events.item_added, Events.ledger_changed, Events.room_changed, Events.floor_added, Events.affinity_changed,
		Events.day_started, Events.unlocked, Events.money_changed, Events.reputation_changed, Events.yokai_arrived,
		Events.game_loaded,
	]:
		refresh_signal.connect(func(_a: Variant = null, _b: Variant = null) -> void: evaluate())
	Events.festival_scored.connect(func(_id: String, _score: int, _max: int) -> void: evaluate())


func _on_activity(verb: String, detail: String, amount: int) -> void:
	GameState.bump_counter(verb, amount)
	if not detail.is_empty():
		GameState.bump_counter(verb + COUNTER_SEPARATOR + detail, amount)
	evaluate()


func build_context() -> GoalRules.Context:
	var ctx := GoalRules.Context.new()
	ctx.day = GameState.day
	ctx.inventory = GameState.inventory
	ctx.counters = GameState.counters
	ctx.ledger = GameState.ledger
	ctx.room_grid = GameState.room_grid
	ctx.beds = Lodging.total_beds(GameState.room_grid) if GameState.room_grid != null else 0
	ctx.affinity = GameState.affinity
	ctx.residents = GameState.residents
	ctx.unlocked = GameState.unlocked
	ctx.flags = GameState.flags
	ctx.money = GameState.money
	ctx.reputation = GameState.reputation
	ctx.festival_results = GameState.festival_results
	return ctx


## 새로 완료된 목표를 기록·보상하고 id 목록을 돌려준다.
func evaluate() -> Array[String]:
	var completed: Array[String] = []
	for goal in GoalRules.newly_completed(DataRegistry.goals, build_context(), GameState.goals_done):
		GameState.goals_done[goal.id] = GameState.day
		if goal.reward_money > 0:
			GameState.add_money(goal.reward_money)
		if goal.reward_reputation > 0:
			GameState.add_reputation(goal.reward_reputation)
		Events.message_posted.emit(DataRegistry.text("msg_goal_done", {"name": goal.name_ko}))
		Metrics.record("goal_completed", {"goal": goal.id, "tier": goal.tier})
		Events.goal_completed.emit(goal.id)
		completed.append(goal.id)
	return completed


func is_done(goal_id: String) -> bool:
	return GameState.goals_done.has(goal_id)


## 완료 기록과 무관하게 지금 조건이 충족돼 있는가 (명절 준비 목표 채점용).
func is_satisfied(goal_id: String) -> bool:
	var goal := DataRegistry.get_goal(goal_id)
	return goal != null and GoalRules.condition_holds(goal.condition, build_context())


func progress(goal: GoalData) -> Vector2i:
	return GoalRules.progress(goal.condition, build_context())


## 오늘 창 안의 목표 (완료 포함), 층위별. 할 일 탭이 그린다.
func visible(tiers: Array[String]) -> Array[GoalData]:
	return GoalRules.visible(DataRegistry.goals, GameState.day, tiers)


## HUD 칩 "할 일 done/total": 오늘·이번 절기 층위 중 창 안의 목표.
func summary() -> Vector2i:
	var total := 0
	var done := 0
	for goal in visible(SUMMARY_TIERS):
		total += 1
		if is_done(goal.id):
			done += 1
	return Vector2i(done, total)
