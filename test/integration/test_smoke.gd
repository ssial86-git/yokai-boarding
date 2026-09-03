class_name TestSmoke
extends GdUnitTestSuite
## 메인 씬이 headless 로 로드되고 1프레임 진행되는지, autoload 6종이 살아 있는지,
## 내장 지표(Metrics)가 metrics_events.csv 정의대로 JSONL 을 남기는지 확인한다 (docs/01 v3 7절 "지표 수집 누락" 리스크).

const MAIN_SCENE := "res://scenes/main.tscn"
const AUTOLOADS: Array[String] = ["Events", "GameState", "DataRegistry", "Clock", "SaveManager", "Metrics"]
const METRICS_PATH := "user://metrics/test_smoke.jsonl"


func after_test() -> void:
	Metrics.close_session()
	if FileAccess.file_exists(METRICS_PATH):
		DirAccess.remove_absolute(METRICS_PATH)


func test_main_scene_loads_one_frame() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var root: Node = runner.scene()
	assert_object(root).is_not_null()
	assert_str(root.name).is_equal("Main")


func test_autoloads_present() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for autoload_name: String in AUTOLOADS:
		assert_bool(tree.root.has_node(autoload_name)) \
			.override_failure_message("autoload 누락: %s" % autoload_name) \
			.is_true()


func test_metrics_write_defined_events_as_jsonl() -> void:
	assert_int(Metrics.open_session(METRICS_PATH)).is_equal(OK)
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	Clock.advance_to_band(Clock.Band.DAY)
	Metrics.close_session()

	var kinds: Array[String] = []
	for line: String in FileAccess.get_file_as_string(METRICS_PATH).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		assert_bool(parsed is Dictionary).override_failure_message("JSON 줄이 아님: %s" % line).is_true()
		var row := parsed as Dictionary
		for key in ["t", "day", "timeband", "kind", "data"]:
			assert_bool(row.has(key)).override_failure_message("%s 키 없음: %s" % [key, line]).is_true()
		var kind := str(row["kind"])
		var definition := DataRegistry.get_metrics_event(kind)
		assert_object(definition).override_failure_message("metrics_events.csv 에 없는 kind: %s" % kind).is_not_null()
		for field: Variant in (row["data"] as Dictionary):
			assert_bool(definition.fields.has(str(field))) \
				.override_failure_message("%s 의 정의되지 않은 필드 %s" % [kind, field]).is_true()
		kinds.append(kind)
	for expected in ["session_start", "day_started", "timeband", "dialogue", "session_end"]:
		assert_array(kinds).override_failure_message("지표 미기록: %s" % expected).contains([expected])
	assert_int(Metrics.count("timeband")).is_greater_equal(2)  # 아침 진입 + 낮 진입


func test_metrics_reject_undefined_kind_and_field() -> void:
	var before := Metrics.count("dialogue")
	Metrics.record("not_a_defined_event", {})
	Metrics.record("dialogue", {"event": "x", "bogus": 1})
	assert_int(Metrics.count("not_a_defined_event")).is_equal(0)
	assert_int(Metrics.count("dialogue")).is_equal(before)
