class_name TestChapterRules
extends GdUnitTestSuite
## 챕터 게이트(병렬 목표 중 n개)·승격 조건 순수 로직 (P2-S4) + 목표 조건 residents 절.


func _chapter(id: String, order: int, goals: Array[String], required: int, next_id: String) -> ChapterData:
	var chapter := ChapterData.new()
	chapter.id = id
	chapter.order = order
	chapter.gate_goals = goals
	chapter.gate_required = required
	chapter.next_id = next_id
	return chapter


func _species(id: String, promotable: bool, promotes_to: String) -> GuestSpeciesData:
	var species := GuestSpeciesData.new()
	species.id = id
	species.promotable = promotable
	species.promotes_to = promotes_to
	return species


func test_first_and_gate_progress() -> void:
	var c1 := _chapter("c1", 1, ["a", "b", "c", "d"], 2, "c2")
	var c2 := _chapter("c2", 2, [], 0, "")
	assert_str(ChapterRules.first({"c2": c2, "c1": c1}).id).is_equal("c1")
	assert_that(ChapterRules.gate_progress(c1, {})).is_equal(Vector2i(0, 4))
	assert_bool(ChapterRules.gate_met(c1, {"a": 3})).is_false()
	assert_that(ChapterRules.gate_progress(c1, {"a": 3, "d": 5, "zzz": 1})).is_equal(Vector2i(2, 4))
	assert_bool(ChapterRules.gate_met(c1, {"a": 3, "d": 5})).is_true()
	assert_bool(ChapterRules.gate_met(c2, {"a": 3, "d": 5})).is_false()  # 마지막 챕터는 넘어가지 않는다
	assert_bool(ChapterRules.gate_met(null, {})).is_false()


func test_promotable_yokai_requires_visits_reputation_and_not_resident() -> void:
	var species := {
		"g_a": _species("g_a", true, "y_a"),
		"g_b": _species("g_b", true, "y_b"),
		"g_c": _species("g_c", false, "y_c"),
		"g_d": _species("g_d", true, ""),
	}
	var ledger := {"g_a": 2, "g_b": 5, "g_c": 9, "g_d": 9}
	var residents: Array[String] = ["y_b"]
	assert_array(ChapterRules.promotable_yokai(species, ledger, 5, residents, 2, 5)).contains_exactly(["y_a"])
	assert_array(ChapterRules.promotable_yokai(species, ledger, 4, residents, 2, 5)).is_empty()  # 평판 부족
	assert_array(ChapterRules.promotable_yokai(species, {"g_a": 1}, 9, residents, 2, 5)).is_empty()  # 방문 부족
	var nobody: Array[String] = []
	assert_array(ChapterRules.promotable_yokai(species, ledger, 9, nobody, 2, 5)).contains_exactly(["y_a", "y_b"])
	assert_str(ChapterRules.species_for_yokai(species, "y_b").id).is_equal("g_b")
	assert_that(ChapterRules.species_for_yokai(species, "y_zzz")).is_null()


func test_goal_residents_clause() -> void:
	var ctx := GoalRules.Context.new()
	ctx.residents = ["y01", "y02"]
	assert_bool(GoalRules.condition_holds("residents>=2", ctx)).is_true()
	assert_bool(GoalRules.condition_holds("residents>=3", ctx)).is_false()
	assert_that(GoalRules.progress("residents>=3", ctx)).is_equal(Vector2i(2, 3))
