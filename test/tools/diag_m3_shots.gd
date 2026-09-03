extends SceneTree
## 개발용: 메인 씬을 띄워 1일차 아침 튜토리얼(대화창), 2일차 저녁 심사 카드(빈 카드), 밤 사연을 캡처한다.
## headless 로는 렌더링이 안 되므로 창이 잠깐 뜬다. autoload 는 root 에서 노드로 찾는다.
## 사용: & $env:GODOT_BIN --path . -s res://test/tools/diag_m3_shots.gd -- <출력 폴더>

const WARMUP := 4


func _initialize() -> void:
	var out_dir := _out_dir()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(WARMUP)
	var story: Node = main.get("story_system")
	var intake: Node = main.get("intake_system")
	var house: Node = main.get("house_controller")
	var clock: Node = root.get_node("Clock")
	var game_state: Node = root.get_node("GameState")

	await _shot(out_dir.path_join("m3_tutorial.png"))  # 1일차 아침 튜토리얼 대화창
	_drain(story, intake)
	game_state.set("money", 1000)
	house.call("try_place_room", Vector2i(3, 0), "guest_room")
	for band in [1, 2, 3]:  # Clock.Band DAY, EVENING, NIGHT
		clock.call("advance_to_band", band)
		_drain(story, intake)
	clock.call("sleep")  # 2일차 아침
	_drain(story, intake)
	clock.call("advance_to_band", 1)  # 낮
	clock.call("advance_to_band", 2)  # 2일차 저녁: 빈 카드 방문자
	await _frames(WARMUP)
	await _shot(out_dir.path_join("m3_intake.png"))
	if bool(intake.call("has_pending")):
		intake.call("decide", 0)  # ACCEPT
	await _frames(WARMUP)
	await _shot(out_dir.path_join("m3_arrival.png"))  # 도착 튜토리얼 대화창
	_drain(story, intake)
	clock.call("advance_to_band", 3)  # 밤: 사연
	await _frames(WARMUP)
	await _shot(out_dir.path_join("m3_night.png"))
	quit(0)


func _drain(story: Node, intake: Node) -> void:
	for i in 100:
		if bool(story.call("is_busy")):
			var node: RefCounted = story.call("current_node")
			if node != null and bool(node.call("has_options")):
				story.call("choose", 0)
			else:
				story.call("advance")
		elif bool(intake.call("has_pending")):
			intake.call("decide", 0)
		else:
			return


func _shot(path: String) -> void:
	await _frames(2)
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	print("[diag] %s -> %s" % [error_string(err), path])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _out_dir() -> String:
	var passthrough := false
	for arg in OS.get_cmdline_args():
		if passthrough:
			return arg
		if arg == "--":
			passthrough = true
	var user_args := OS.get_cmdline_user_args()
	return user_args[0] if not user_args.is_empty() else "user://"
