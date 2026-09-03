class_name TestStamina
extends GdUnitTestSuite
## 스태미너: 소모·회복·0 에서의 둔화(강제 기절 없음)·직렬화.


func _params() -> Stamina.Params:
	var params := Stamina.Params.new()
	params.max_value = 50.0
	params.run_drain_per_second = 10.0
	params.regen_per_second = 5.0
	params.exhausted_multiplier = 0.5
	params.low_threshold = 10.0
	return params


func test_spend_drain_regen_and_exhaustion() -> void:
	var stamina := Stamina.new(_params())
	assert_float(stamina.value).is_equal(50.0)
	assert_bool(stamina.spend(20.0)).is_true()
	assert_float(stamina.value).is_equal(30.0)
	stamina.drain(2.0)  # 달리기 2초 = 20
	assert_float(stamina.value).is_equal(10.0)
	assert_bool(stamina.is_low()).is_true()
	assert_bool(stamina.spend(25.0)).is_false()  # 모자라도 0 까지 깎고 행동은 막지 않는다
	assert_float(stamina.value).is_equal(0.0)
	assert_bool(stamina.is_exhausted()).is_true()
	assert_float(stamina.speed_multiplier()).is_equal(0.5)
	stamina.regen(3.0)
	assert_float(stamina.value).is_equal(15.0)
	assert_float(stamina.speed_multiplier()).is_equal(1.0)
	stamina.regen(100.0)
	assert_float(stamina.value).is_equal(50.0)
	assert_float(stamina.ratio()).is_equal(1.0)


func test_serialization_clamps_and_rejects_bad_data() -> void:
	var stamina := Stamina.new(_params())
	stamina.value = 12.5
	var restored := Stamina.new(_params())
	assert_bool(restored.from_dict(stamina.to_dict())).is_true()
	assert_float(restored.value).is_equal(12.5)
	assert_bool(restored.from_dict({"value": 999.0})).is_true()
	assert_float(restored.value).is_equal(50.0)
	assert_bool(restored.from_dict({})).is_false()
	assert_bool(restored.from_dict({"value": "x"})).is_false()


func test_params_from_tuning() -> void:
	var tuning := TuningData.new()
	tuning.values = {"stamina_max": 80.0, "stamina_run_drain_per_second": 3.0, "stamina_low_threshold": 25.0}
	var params := Stamina.Params.from_tuning(tuning)
	assert_float(params.max_value).is_equal(80.0)
	assert_float(params.run_drain_per_second).is_equal(3.0)
	assert_float(params.low_threshold).is_equal(25.0)
	assert_float(params.regen_per_second).is_equal(4.0)  # 기본값 유지
