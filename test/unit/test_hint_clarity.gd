class_name TestHintClarity
extends GdUnitTestSuite


func _hint(id: String, phase: String, day_min: int, day_max: int, requires: String, blocked: String, priority: int) -> HintData:
	var hint := HintData.new()
	hint.id = id
	hint.timeband = phase
	hint.day_min = day_min
	hint.day_max = day_max
	hint.requires_flag = requires
	hint.blocked_by_flag = blocked
	hint.priority = priority
	return hint


func test_hint_picker_flags_and_priority() -> void:
	var hints := {
		"assign": _hint("assign", "morning", 1, 0, "", "first_assignment_done", 50),
		"start": _hint("start", "morning", 1, 0, "first_assignment_done", "first_day_started", 40),
		"build": _hint("build", "any", 1, 3, "", "first_build_done", 30),
		"night": _hint("night", "night", 1, 2, "", "", 20),
	}
	assert_str(HintPicker.pick(hints, "morning", 1, {}).id).is_equal("assign")
	assert_str(HintPicker.pick(hints, "morning", 1, {"first_assignment_done": true}).id).is_equal("start")
	assert_str(HintPicker.pick(hints, "morning", 1, {"first_assignment_done": true, "first_day_started": true}).id).is_equal("build")
	assert_str(HintPicker.pick(hints, "day", 2, {}).id).is_equal("build")
	assert_object(HintPicker.pick(hints, "day", 4, {})).is_null()
	assert_str(HintPicker.pick(hints, "night", 2, {"first_build_done": true}).id).is_equal("night")
	assert_object(HintPicker.pick(hints, "night", 3, {"first_build_done": true})).is_null()


func test_clarity_alpha() -> void:
	var dim := YokaiData.new()
	dim.clarity_by_affinity = true
	var solid := YokaiData.new()
	assert_float(Clarity.alpha_for(solid, 0, 0.4, 3)).is_equal(1.0)
	assert_float(Clarity.alpha_for(dim, 0, 0.4, 3)).is_equal(0.4)
	assert_float(Clarity.alpha_for(dim, 3, 0.4, 3)).is_equal(1.0)
	assert_float(Clarity.alpha_for(dim, 9, 0.4, 3)).is_equal(1.0)
	assert_float(Clarity.alpha_for(dim, 1, 0.4, 3)).is_equal_approx(0.6, 0.0001)
	assert_float(Clarity.alpha_for(dim, 1, 0.4, 0)).is_equal(1.0)
	assert_float(Clarity.alpha_for(null, 1, 0.4, 3)).is_equal(1.0)
