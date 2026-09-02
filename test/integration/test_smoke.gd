class_name TestSmoke
extends GdUnitTestSuite
## 메인 씬이 headless 로 로드되고 1프레임 진행되는지, autoload 5종이 살아 있는지 확인한다.

const MAIN_SCENE := "res://scenes/main.tscn"
const AUTOLOADS: Array[String] = ["Events", "GameState", "DataRegistry", "Clock", "SaveManager"]


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
