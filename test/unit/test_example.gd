class_name TestExample
extends GdUnitTestSuite
## gdUnit4 설치 확인용 예제. src/core/ 첫 클래스가 생기면 실제 테스트로 교체한다.


func test_framework_runs() -> void:
	assert_int(1 + 1).is_equal(2)


func test_tuning_data_accessors() -> void:
	var tuning := TuningData.new()
	tuning.values = {"a": 3, "b": 1.5, "c": true, "d": "x"}
	assert_int(tuning.get_int("a")).is_equal(3)
	assert_float(tuning.get_float("b")).is_equal(1.5)
	assert_bool(tuning.get_bool("c")).is_true()
	assert_str(tuning.get_string("d")).is_equal("x")
	assert_int(tuning.get_int("missing", 7)).is_equal(7)
