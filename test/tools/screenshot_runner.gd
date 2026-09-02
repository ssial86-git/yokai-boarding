extends SceneTree
## 개발용: 메인 씬을 실제 렌더러로 띄워 몇 프레임 뒤 스크린샷을 저장하고 종료한다.
## headless 로는 렌더링이 안 되므로 창이 잠깐 뜬다. gdUnit4 테스트가 아니므로 테스트 탐색에서 제외된다.
## -s 스크립트는 autoload 전역 이름이 컴파일 시점에 등록되기 전이라 autoload 는 root 에서 노드로 찾는다.
##
## 사용 (프로젝트 루트):
##   & $env:GODOT_BIN --path . -s res://test/tools/screenshot_runner.gd -- <출력.png> [phase] [floors] [money]
##   phase: morning|day|evening|night (기본 day), floors: 증축할 층 수(기본 0), money: 시작 자금 덮어쓰기

const WARMUP_FRAMES := 6
const DEFAULT_OUTPUT := "user://screenshot.png"


func _initialize() -> void:
	var args := _user_args()
	var output := args[0] if args.size() > 0 else DEFAULT_OUTPUT
	var phase_name := args[1] if args.size() > 1 else "day"
	var extra_floors := int(args[2]) if args.size() > 2 else 0
	var money := int(args[3]) if args.size() > 3 else -1

	if not root.has_node("GameState"):
		push_error("[screenshot_runner] autoload 가 없다 — --path 로 프로젝트를 지정했는가?")
		quit(1)
		return
	var game_state: Node = root.get_node("GameState")
	var clock: Node = root.get_node("Clock")
	var events: Node = root.get_node("Events")

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame

	if money >= 0:
		game_state.set("money", money)
	# 튜토리얼 대화창이 집을 가리지 않도록 열린 대화를 끝까지 넘긴다
	var story: Node = main.get("story_system")
	for i in 50:
		if not bool(story.call("is_busy")):
			break
		var node: RefCounted = story.call("current_node")
		if node != null and bool(node.call("has_options")):
			story.call("choose", 0)
		else:
			story.call("advance")
	var controller: Node = main.get("house_controller")
	var grid: RefCounted = game_state.get("room_grid")
	for i in extra_floors:
		game_state.set("money", maxi(int(game_state.get("money")), int(grid.call("get_next_floor_cost"))))
		controller.call("try_add_floor")
	var phases: Dictionary = clock.get_script().get_script_constant_map()["Phase"]
	if phases.has(phase_name.to_upper()):
		clock.set("phase", phases[phase_name.to_upper()])
		events.emit_signal("phase_changed", clock.get("phase"), game_state.get("day"))

	for i in WARMUP_FRAMES:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png(output)
	print("[screenshot_runner] %s -> %s (%dx%d)" % [error_string(err), output, image.get_width(), image.get_height()])
	quit(0 if err == OK else 1)


func _user_args() -> PackedStringArray:
	var result := PackedStringArray()
	var passthrough := false
	for arg in OS.get_cmdline_args():
		if passthrough:
			result.append(arg)
		elif arg == "--":
			passthrough = true
	if result.is_empty():
		result = OS.get_cmdline_user_args()
	return result
