extends SceneTree
## 최종 검증용 자동 플레이: 창을 띄우고 시드를 고정한 채 이틀을 실제로 진행하면서
## 핵심 상태(입주·손님·카드 수·집이 화면 안에 있는지·정산·심사·사연)를 검사하고 단계마다 PNG 를 남긴다.
## 결과는 <출력 폴더>/playthrough_report.json 에 쓰고, 실패가 있으면 종료 코드 1.
## 사용: & $env:GODOT_BIN --path . -s res://test/tools/playthrough_check.gd -- <출력 폴더>
## headless 에서는 렌더·입력이 없으므로 창 모드 전용이다. 검증 에이전트는 이 리포트와 PNG 를 읽는다.

const SEED := 20260902
const WALK_FRAMES_MAX := 600

var _checks: Array[Dictionary] = []
var _out_dir: String = "user://"
var _shot_index: int = 0


func _initialize() -> void:
	_out_dir = _arg_out_dir()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("Clock")
	var story: Node = main.get("story_system")
	var intake: Node = main.get("intake_system")
	var house: Node = main.get("house_controller")
	var assign: Node = main.get("assignment_controller")
	var panel: Node = main.get("assignment_panel")
	var manager: Node = main.get("yokai_manager")
	var view: Node2D = main.get("house_view")
	var camera: Camera2D = main.get("camera")
	var dialogue_box: Control = main.get("dialogue_box")
	var intake_panel: Control = main.get("intake_panel")
	(gs.get("rng") as RandomNumberGenerator).seed = SEED

	# --- 1일차 아침 ---
	_check("tutorial_dialogue_open_day1", dialogue_box.visible, "1일차 아침 성주 영감 대화창이 떠 있다")
	await _shot("01_morning_tutorial")
	_drain(story, intake)
	await _frames(2)
	_check("house_in_view", _house_in_view(view, camera), "집 전체가 카메라 화면 안에 있다")
	_check("cards_match_residents", int(panel.call("card_count")) == (gs.get("residents") as Array).size(),
		"카드 수 == 하숙생 수 (%d)" % (gs.get("residents") as Array).size())
	await _shot("02_morning_plain")
	gs.set("money", 1000)
	_check("build_guest_room", int(house.call("try_place_room", Vector2i(3, 0), "guest_room")) == 0, "객실 건설 OK")
	_check("assign_kitchen", int(assign.call("try_assign", "y02_eoduki", Vector2i(2, 0))) == 0, "어둑이 → 주방 배치 OK")
	await _frames(2)
	await _shot("03_morning_assigned")

	# --- 낮: 걸어가서 일하는지 ---
	clock.call("advance_phase")
	var actor: Node2D = manager.call("get_actor", "y02_eoduki")
	var worked := false
	for i in WALK_FRAMES_MAX:
		await process_frame
		if int(actor.get("state")) == 2:  # WORKING
			worked = true
			break
	_check("worker_reaches_kitchen", worked and actor.get("current_cell") == Vector2i(2, 0), "어둑이가 주방에 도착해 일한다")
	await _shot("04_day_working")

	# --- 저녁: 정산 + 심사 ---
	clock.call("advance_phase")
	await _frames(2)
	var inventory: RefCounted = gs.get("inventory")
	_check("settlement_meal", int(inventory.call("get_count", "meal")) >= 2, "저녁 정산으로 밥이 들어왔다")
	_drain_story_only(story)
	await _frames(2)
	if not bool(intake.call("has_pending")):
		# 이 시드에서 방문자가 없으면 손님을 직접 세워 심사 화면·손님 카드 경로를 반드시 검사한다
		gs.set("pending_visitor", {"visitor_id": "v_guest", "kind": "guest", "species_id": "g_mongdanggwi", "yokai_id": "", "omen": 0})
		(root.get_node("Events") as Node).emit_signal("visitor_knocked", gs.get("pending_visitor"))
		await _frames(2)
	var had_visitor := bool(intake.call("has_pending"))
	_check("visitor_present", had_visitor, "저녁에 심사할 방문자가 있다")
	if had_visitor:
		_check("intake_panel_open", intake_panel.visible, "심사 카드가 떠 있다")
		await _shot("05_evening_intake")
		var outcome := int(intake.call("decide", 0))
		_check("intake_accept", outcome == 0, "손님 받기 OK (outcome=%d)" % outcome)
		await _frames(2)
		var guests: Array = gs.get("guests")
		_check("guest_recorded", guests.size() == 1, "체류 손님 1명")
		_check("guest_card_shown", int(panel.call("guest_card_count")) == guests.size(), "손님 카드가 패널에 보인다")
		_check("guest_actor_spawned", int(manager.call("actor_count")) == (gs.get("residents") as Array).size() + guests.size(),
			"손님 액터가 집에 보인다")
		await _shot("06_evening_after_accept")
	_drain(story, intake)

	# --- 밤: 사연 ---
	clock.call("advance_phase")
	await _frames(2)
	# 1일차 밤은 튜토리얼이 먼저 뜬다. 튜토리얼만 넘기고 나면 하숙생 사연(kind=story) 이 이어져야 한다.
	for i in 50:
		var current: Resource = story.get("current_event")
		if current == null or str(current.get("kind")) != "tutorial":
			break
		_drain_story_only_one_step(story)
	await _frames(2)
	var night_event: Resource = story.get("current_event")
	var is_story := night_event != null and str(night_event.get("kind")) == "story"
	_check("night_story_open", is_story and dialogue_box.visible,
		"밤에 하숙생 사연(story) 대화창이 떠 있다 (event=%s)" % (str(night_event.get("id")) if night_event != null else "none"))
	await _shot("07_night_story")
	_drain(story, intake)

	# --- 2일차 아침 ---
	clock.call("advance_phase")
	await _frames(2)
	_check("day_advanced", int(gs.get("day")) == 2, "2일차가 되었다")
	_check("assignment_kept", assign.call("can_assign", "y02_eoduki", Vector2i(2, 0)) == 0, "배치 규칙이 아침에 다시 열린다")
	_check("house_in_view_day2", _house_in_view(view, camera), "2일차에도 집이 화면 안에 있다")
	_check("cards_day2", int(panel.call("card_count")) == (gs.get("residents") as Array).size() + (gs.get("guests") as Array).size(),
		"2일차 카드 수 == 하숙생 + 손님")
	await _shot("08_day2_morning")

	_write_report()


func _check(id: String, ok: bool, label: String) -> void:
	_checks.append({"id": id, "ok": ok, "label": label})
	print("[check] %s %s — %s" % ["PASS" if ok else "FAIL", id, label])


func _house_in_view(view: Node2D, camera: Camera2D) -> bool:
	var view_size := root.get_visible_rect().size
	var half := view_size / (2.0 * camera.zoom.x)
	var visible := Rect2(camera.get_screen_center_position() - half, half * 2.0)
	return visible.encloses(view.call("house_bounds") as Rect2)


func _drain(story: Node, intake: Node) -> void:
	for i in 100:
		if bool(story.call("is_busy")):
			var node: RefCounted = story.call("current_node")
			if node != null and bool(node.call("has_options")):
				story.call("choose", 0)
			else:
				story.call("advance")
		elif bool(intake.call("has_pending")):
			intake.call("decide", 1)  # DECLINE
		else:
			return


func _drain_story_only_one_step(story: Node) -> void:
	var node: RefCounted = story.call("current_node")
	if node != null and bool(node.call("has_options")):
		story.call("choose", 0)
	else:
		story.call("advance")


func _drain_story_only(story: Node) -> void:
	for i in 100:
		if not bool(story.call("is_busy")):
			return
		var node: RefCounted = story.call("current_node")
		if node != null and bool(node.call("has_options")):
			story.call("choose", 0)
		else:
			story.call("advance")


func _shot(name: String) -> void:
	await _frames(2)
	_shot_index += 1
	var path := _out_dir.path_join("%s.png" % name)
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	print("[shot] %s -> %s" % [error_string(err), path])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _write_report() -> void:
	var failed := 0
	for check in _checks:
		if not bool(check["ok"]):
			failed += 1
	var report := {"seed": SEED, "checks": _checks, "failed": failed, "total": _checks.size()}
	var file := FileAccess.open(_out_dir.path_join("playthrough_report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[playthrough] %d/%d 통과, 실패 %d" % [_checks.size() - failed, _checks.size(), failed])
	quit(0 if failed == 0 else 1)


func _arg_out_dir() -> String:
	var passthrough := false
	for arg in OS.get_cmdline_args():
		if passthrough:
			return arg
		if arg == "--":
			passthrough = true
	var user_args := OS.get_cmdline_user_args()
	return user_args[0] if not user_args.is_empty() else "user://"
