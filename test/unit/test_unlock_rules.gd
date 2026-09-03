class_name TestUnlockRules
extends GdUnitTestSuite
## 해금 규칙: 조건식 평가, 날짜·시간대 게이트, 같은 평가 안의 연쇄 해금.


func _unlock(id: String, day_min: int, timeband: String, condition: String, expected_day: int = -1) -> UnlockData:
	var unlock := UnlockData.new()
	unlock.id = id
	unlock.day_min = day_min
	unlock.expected_day = day_min if expected_day < 0 else expected_day
	unlock.timeband = timeband
	unlock.condition = condition
	return unlock


func _ctx(day: int, timeband: String = "morning") -> UnlockRules.Context:
	var ctx := UnlockRules.Context.new()
	ctx.day = day
	ctx.timeband = timeband
	return ctx


func test_condition_clauses() -> void:
	var ctx := _ctx(3)
	ctx.flags = {"clue": true}
	ctx.affinity = {"y1": 2}
	ctx.residents = ["y1"]
	ctx.inventory.add("wood", 3)
	ctx.unlocked = {"u_base": 1}
	assert_bool(UnlockRules.condition_holds("", ctx)).is_true()
	assert_bool(UnlockRules.condition_holds("flag:clue", ctx)).is_true()
	assert_bool(UnlockRules.condition_holds("flag:none", ctx)).is_false()
	assert_bool(UnlockRules.condition_holds("affinity:y1>=2", ctx)).is_true()
	assert_bool(UnlockRules.condition_holds("affinity:y1>=3", ctx)).is_false()
	assert_bool(UnlockRules.condition_holds("resident:y1;unlock:u_base;item:wood>=3", ctx)).is_true()
	assert_bool(UnlockRules.condition_holds("item:wood>=4", ctx)).is_false()
	assert_bool(UnlockRules.condition_holds("unlock:u_missing", ctx)).is_false()
	assert_bool(UnlockRules.condition_holds("bogus:x", ctx)).is_false()


func test_day_and_timeband_gate_and_already_unlocked() -> void:
	var unlock := _unlock("u_x", 2, "night", "")
	assert_bool(UnlockRules.is_satisfied(unlock, _ctx(1, "night"))).is_false()
	assert_bool(UnlockRules.is_satisfied(unlock, _ctx(2, "morning"))).is_false()
	assert_bool(UnlockRules.is_satisfied(unlock, _ctx(2, "night"))).is_true()
	var ctx := _ctx(5, "night")
	ctx.unlocked = {"u_x": 2}
	assert_bool(UnlockRules.is_satisfied(unlock, ctx)).is_false()
	assert_bool(UnlockRules.is_satisfied(_unlock("u_any", 1, "any", ""), _ctx(1, "evening"))).is_true()


func test_newly_satisfied_chains_in_order() -> void:
	var unlocks := {
		"u_hill": _unlock("u_hill", 2, "morning", ""),
		"u_axe": _unlock("u_axe", 2, "morning", "unlock:u_hill"),
		"u_axe2": _unlock("u_axe2", 8, "any", "unlock:u_axe"),
		"u_first": _unlock("u_first", 1, "any", ""),
	}
	var opened := UnlockRules.newly_satisfied(unlocks, _ctx(1))
	assert_int(opened.size()).is_equal(1)
	assert_str(opened[0].id).is_equal("u_first")
	var ctx := _ctx(2)
	ctx.unlocked = {"u_first": 1}
	var ids: Array[String] = []
	for unlock in UnlockRules.newly_satisfied(unlocks, ctx):
		ids.append(unlock.id)
	assert_array(ids).contains_exactly(["u_hill", "u_axe"])  # 같은 평가 안에서 연쇄, expected_day 순
	assert_bool(ctx.unlocked.has("u_hill")).is_false()  # 평가는 컨텍스트를 바꾸지 않는다
