extends SceneTree
## 최종 검증용 자동 플레이: 창을 띄우고 시드를 고정한 채 이틀을 실제로 진행하면서
## 핵심 상태(입주·손님·카드 수·집이 화면 안에 있는지·정산·심사·사연)를 검사하고 단계마다 PNG 를 남긴다.
## 결과는 <출력 폴더>/playthrough_report.json 에 쓰고, 실패가 있으면 종료 코드 1.
## 사용: & $env:GODOT_BIN --path . -s res://test/tools/playthrough_check.gd -- <출력 폴더>
## headless 에서는 렌더·입력이 없으므로 창 모드 전용이다. 검증 에이전트는 이 리포트와 PNG 를 읽는다.

const SEED := 20260902
const WALK_SECONDS_MAX := 12.0

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
	# 실제 마우스 입력으로 카드 → '동행' 존 드래그 (사용자가 잡은 버그: 존이 드롭을 받지 못해 휴식으로 떨어졌다)
	var card: Control = panel.call("get_card", "y01_ttukttagi")
	var party_rect: Rect2 = panel.call("party_zone_rect")
	await _drag(card.get_global_rect().get_center(), party_rect.get_center())
	var assignment: RefCounted = gs.get("assignment")
	_check("drag_card_to_party_zone", assignment.call("get_cell", "y01_ttukttagi") == Vector2i(-3, -3),
		"뚝딱이 카드를 마우스로 동행 존에 끌어 놓으면 '동행'이 된다 (지금: %s)" % str(assignment.call("get_cell", "y01_ttukttagi")))
	var field_rect: Rect2 = panel.call("field_zone_rect")
	await _drag(card.get_global_rect().get_center(), field_rect.get_center())
	_check("drag_card_to_field_zone", assignment.call("get_cell", "y01_ttukttagi") == Vector2i(-2, -2),
		"같은 카드를 텃밭 존에 끌어 놓으면 '텃밭'이 된다")
	_check("drag_back_to_rest", int(assign.call("try_rest", "y01_ttukttagi")) == 0, "다시 휴식으로 (뒤 검사는 뚝딱이가 쉬는 전제)")
	await _frames(2)

	# --- 낮: 걸어가서 일하는지 --- (Clock.Band: 0 아침 / 1 낮 / 2 저녁 / 3 밤)
	clock.call("advance_to_band", 1)
	var actor: Node2D = manager.call("get_actor", "y02_eoduki")
	# 걷기는 실시간(px/초)이라 프레임 수가 아니라 초로 기다린다 — 창이 초점을 잃으면 수백 FPS 로 돌아 프레임 대기가 순식간에 끝난다
	var worked := await _wait_until(func() -> bool: return int(actor.get("state")) == 2, WALK_SECONDS_MAX)  # WORKING
	_check("worker_reaches_kitchen", worked and actor.get("current_cell") == Vector2i(2, 0), "어둑이가 주방에 도착해 일한다")
	await _shot("04_day_working")

	# --- 저녁: 정산 + 심사 ---
	clock.call("advance_to_band", 2)
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
		# 검증 에이전트가 잡은 결함: 카드 3장이 되면 휴식·텃밭·동행 드롭존이 화면 밖으로 밀렸다
		_check("drop_zones_on_screen_with_guest", bool(panel.call("zones_on_screen")), "카드 3장에도 휴식·텃밭·동행 존이 화면 안에 있다")
		await _shot("06_evening_after_accept")
	_drain(story, intake)

	# --- 밤: 사연 ---
	clock.call("advance_to_band", 3)
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

	# --- 취침 → 2일차 아침 ---
	clock.call("sleep")
	await _frames(2)
	_check("day_advanced", int(gs.get("day")) == 2, "2일차가 되었다")
	_check("assignment_kept", assign.call("can_assign", "y02_eoduki", Vector2i(2, 0)) == 0, "배치 규칙이 아침에 다시 열린다")
	_check("house_in_view_day2", _house_in_view(view, camera), "2일차에도 집이 화면 안에 있다")
	_check("cards_day2", int(panel.call("card_count")) == (gs.get("residents") as Array).size() + (gs.get("guests") as Array).size(),
		"2일차 카드 수 == 하숙생 + 손님")
	await _shot("08_day2_morning")

	# --- P1-S2: 플레이어·마당 텃밭·뒷산 채집 ---
	var region_manager: Node = main.get("region_manager")
	var farm_system: Node = main.get("farm_system")
	var gather_system: Node = main.get("gather_system")
	var player: Node2D = main.get("player")
	_check("player_in_house", player != null and str(gs.get("player_region")) == "r_house", "플레이어가 하숙집 안에 있다")
	_check("player_on_floor", player != null and bool(player.call("is_on_floor")), "플레이어가 바닥 위에 서 있다")
	_check("hoe_unlocked", (gs.get("tools") as Dictionary).has("hoe"), "1일차 괭이 해금")
	_check("back_hill_unlocked_day2", bool(region_manager.call("is_region_open", "r_back_hill")), "2일차 아침 뒷산이 열렸다")
	_check("travel_yard", bool(region_manager.call("travel", "r_yard")), "대문 → 마당")
	await _frames(3)
	_check("panel_hidden_outdoors", not (panel as Control).visible, "마당에서는 배치 패널이 숨는다")
	await _shot("09_yard_plain")
	_check("farm_till", bool(farm_system.call("act", 0)), "텃밭 0번 괭이질")
	_check("farm_sow", bool(farm_system.call("act", 0)), "텃밭 0번 파종 (무 씨앗)")
	_check("farm_water", bool(farm_system.call("act", 0)), "텃밭 0번 물주기")
	var farm: RefCounted = gs.get("farm")
	var plot: RefCounted = farm.call("get_plot", 0)
	_check("plot_growing", int(plot.get("state")) == 2 and str(plot.get("crop_id")) == "c_radish", "0번 칸이 무 자라는 중")
	await _frames(2)
	await _shot("10_yard_farmed")
	_check("travel_back_hill", bool(region_manager.call("travel", "r_back_hill")), "마당 → 뒷산")
	await _frames(3)
	var points: RefCounted = gather_system.call("points_for", "r_back_hill")
	_check("gather_points_8", int(points.call("size")) == 8, "뒷산 채집 포인트 8개")
	var gathered := false
	for i in int(points.call("size")):
		if bool(gather_system.call("can_gather", "r_back_hill", i)):
			gathered = bool(gather_system.call("gather", "r_back_hill", i))
			break
	_check("gathered_one", gathered, "채집 포인트 하나를 캤다")
	await _frames(2)
	await _shot("11_back_hill")
	# --- P1-S3: 개울 낚시·가마솥 요리 메뉴 ---
	var fishing_system: Node = main.get("fishing_system")
	var station_menu: Control = main.get("station_menu")
	(gs.get("unlocked") as Dictionary)["u_fishing"] = int(gs.get("day"))  # 4일차 해금을 미리 연다
	(gs.get("tools") as Dictionary)["rod"] = 1
	_check("travel_stream", bool(region_manager.call("travel", "r_stream")), "뒷산 → 개울")
	await _frames(3)
	var spot: Node2D = region_manager.call("current_view").get_node_or_null("FishingSpot")
	_check("fishing_spot_exists", spot != null, "개울에 낚시 자리가 있다")
	if spot != null:
		player.call("place", spot.position)  # 낚시 자리 앞에 서서 E
	_check("fishing_started", bool(fishing_system.call("start", "r_stream")), "찌를 던졌다 (타이밍 바)")
	await _physics_frames(3)  # 안내 문구는 물리 프레임에서 갱신된다
	_check("fishing_prompt_strike", str(main.get("hud").call("prompt_text")) == "E: 지금!", "안내 문구가 'E: 지금!' 으로 바뀐다")
	await _shot("12_fishing_bar")
	var cast: RefCounted = fishing_system.get("cast")
	if cast != null:
		cast.set("center", float(cast.call("marker")))
	var caught := str(fishing_system.call("strike"))
	_check("fishing_caught", not caught.is_empty(), "구간 안에서 E → 낚았다 (%s)" % caught)
	_check("travel_home", bool(region_manager.call("travel", "r_house")), "개울 → 집")
	await _frames(2)
	(gs.get("unlocked") as Dictionary)["u_recipes_tier1"] = int(gs.get("day"))
	station_menu.call("open_cook", Vector2i(2, 0))
	await _frames(2)
	_check("cook_menu_open", station_menu.visible and int(station_menu.call("row_count")) >= 12, "가마솥 메뉴에 레시피 12줄이 보인다")
	await _shot("13_cook_menu")
	station_menu.call("close")
	await _frames(1)

	# --- 사용자가 잡은 회귀: 창고·상태 줄이 길어지면 상단 바가 화면을 넘어 취침 버튼이 사라졌다 ---
	var hud: Control = main.get("hud")
	for item_id in ["meal", "m_stone", "m_bamboo", "m_namul", "m_clay", "wood", "m_mushroom", "m_ore", "m_spring_water", "m_ember_stone", "doodle", "radish", "perilla", "seed_cabbage", "cloth", "scrap"]:
		inventory.call("add", item_id, 3)
	(root.get_node("Events") as Node).emit_signal("item_added", "meal", 3)
	gs.set("money", 8750)
	gs.set("reputation", 33)
	(root.get_node("Events") as Node).emit_signal("money_changed", 8750)
	await _frames(3)
	var sleep_rect: Rect2 = hud.call("sleep_button_rect")
	var view_width := root.get_visible_rect().size.x
	_check("sleep_button_on_screen", sleep_rect.size.x > 0.0 and sleep_rect.end.x <= view_width + 0.5,
		"창고 16종·돈 4자리에도 취침 버튼이 화면 안에 있다 (right=%.0f / %.0f)" % [sleep_rect.end.x, view_width])
	var hub: Control = main.get("menu_hub")
	hub.call("open_tab", 0)  # 창고 탭
	await _frames(2)
	_check("inventory_tab_rows", hub.visible and int(hub.call("row_count")) >= 16, "장부 메뉴 창고 탭에 종류별 소제목과 16종 이상이 보인다")
	await _shot("14_inventory_menu")
	# --- P2-S1: 달력 탭 ---
	hub.call("open_tab", 3)
	await _frames(2)
	var calendar_obj: RefCounted = gs.get("calendar")
	_check("calendar_tab_rows", hub.visible and int(hub.call("row_count")) >= 4, "달력 탭에 제목·격자·범례·다가오는 행사가 보인다")
	_check("calendar_day_matches", int(calendar_obj.get("day_of_season")) == int(gs.get("day")) and str(calendar_obj.get("season_id")) == "spring",
		"달력 = 봄 %d일 (통산 %d일차)" % [int(calendar_obj.get("day_of_season")), int(gs.get("day"))])
	_check("yin_in_range", int(gs.get("yin")) >= 0 and int(gs.get("yin")) <= 3, "오늘 음기 %d (0~3)" % int(gs.get("yin")))
	_check("calendar_rows_fit", bool(hub.call("rows_fit")), "달력 탭의 행이 스크롤 없이 전부 보인다 (만월 줄이 잘리지 않음)")
	var panel_rect: Rect2 = hub.call("panel_rect")
	var bar_height := float(main.get("hud").call("bar_height"))
	_check("menu_below_clock_card", panel_rect.position.y >= bar_height - 0.5,
		"장부 패널 위쪽(%.0f)이 시계 카드 줄(%.0f) 아래에 있다" % [panel_rect.position.y, bar_height])
	var view_height := root.get_visible_rect().size.y
	_check("menu_close_on_screen", panel_rect.end.y <= view_height + 0.5,
		"장부 패널 아래쪽(%.0f)이 화면(%.0f) 안에 있다 — 닫기 버튼이 잘리지 않음" % [panel_rect.end.y, view_height])
	await _shot("17_calendar_tab")
	# --- P2-S2: 할 일 탭 + HUD 칩 ---
	hub.call("open_tab", 4)
	await _frames(2)
	_check("goals_tab_rows", hub.visible and int(hub.call("row_count")) >= 8, "할 일 탭에 오늘·이번 절기(동지 준비)·장기 목표가 보인다")
	var chip_text := str(main.get("hud").call("goals_chip_text"))
	_check("goals_chip_shown", chip_text.begins_with("할 일 "), "HUD 오른쪽 위에 '할 일 n/m' 칩 (%s)" % chip_text)
	_check("goal_counter_till", int((gs.get("counters") as Dictionary).get("farm.till", 0)) >= 1, "괭이질이 활동 카운터에 쌓였다")
	await _shot("18_goals_tab")
	hub.call("close")
	await _frames(1)

	# --- P1-S4: 잿빛 들 — 동행 편성 → 적·동료 스폰 → 부적 투척 → 귀환 ---
	var expedition: Node = main.get("expedition_system")
	for unlock_id in ["u_well", "u_ash_field", "u_party"]:
		(gs.get("unlocked") as Dictionary)[unlock_id] = int(gs.get("day"))
	_check("party_assign_1", int(assign.call("try_assign", "y01_ttukttagi", Vector2i(-3, -3))) == 0, "뚝딱이 → 동행 (아침 배치)")
	_check("party_assign_2", int(assign.call("try_assign", "y02_eoduki", Vector2i(-3, -3))) == 0, "어둑이 → 동행")
	_check("travel_well", bool(region_manager.call("travel", "r_well")), "마당 → 우물 아래")
	_check("travel_ash_field", bool(region_manager.call("travel", "r_ash_field")), "우물 → 잿빛 들")
	await _frames(3)
	var enemies: Array = expedition.get("enemies")
	var companions: Array = expedition.get("companions")
	_check("enemies_spawned", enemies.size() == 4, "잿빛 들에 적 4마리 (regions.enemy_count)")
	_check("companions_spawned", companions.size() == 2, "동행 2명이 따라왔다")
	if not enemies.is_empty():
		player.call("place", (enemies[0] as Node2D).global_position + Vector2(-60.0, 0.0))
		# 동료는 걸어오는 데 시간이 걸리므로 캡처를 위해 플레이어 뒤에 세운다
		for i in companions.size():
			(companions[i] as Node2D).global_position = player.global_position + Vector2(-24.0 * float(i + 1), 0.0)
	await _frames(3)
	await _shot("15_ash_field")
	inventory.call("add", "t_throw", 1)
	var target_hp := int((enemies[0] as Node).get("hp")) if not enemies.is_empty() else 0
	_check("talisman_thrown", bool(expedition.call("throw_talisman")), "Q: 투척 부적을 던졌다")
	await _frames(4)  # 부적이 플레이어 앞으로 나온 뒤 찍는다
	var in_flight := (expedition.get("projectiles") as Array).size() == 1
	var hit := not enemies.is_empty() and is_instance_valid(enemies[0]) and int((enemies[0] as Node).get("hp")) < target_hp
	_check("projectile_in_flight_or_hit", in_flight or hit, "부적이 날고 있거나 적을 맞혔다 (flight=%s hit=%s)" % [in_flight, hit])
	await _shot("16_talisman_flight")
	for i in 60:
		await process_frame
		if (expedition.get("enemies") as Array).size() < enemies.size():
			break
	inventory.call("add", "t_return", 1)
	_check("talisman_return", bool(expedition.call("use_return_talisman")), "R: 귀환 부적으로 집에 돌아왔다")
	_check("back_home", str(gs.get("player_region")) == "r_house", "집에 있다")
	await _frames(2)

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


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## 조건이 참이 될 때까지 실시간 seconds 만큼 기다린다. 참이 되면 true.
func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await process_frame
	return bool(condition.call())


# --- 실제 입력 재현 (diag_drag.gd 와 같은 방식). Input.parse_input_event 의 좌표는 창 픽셀이므로 스트레치 배율을 곱한다 ---

const DRAG_STEPS := 16
var _last_mouse: Vector2 = Vector2.ZERO


func _drag(from_viewport: Vector2, to_viewport: Vector2) -> void:
	var window_scale: Vector2 = Vector2(root.get_window().size) / root.get_visible_rect().size
	var start := from_viewport * window_scale
	var end := to_viewport * window_scale
	_motion(start)
	await process_frame
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	await process_frame
	for i in DRAG_STEPS:
		_motion(start.lerp(end, float(i + 1) / DRAG_STEPS))
		await process_frame
	_mouse(end, MOUSE_BUTTON_LEFT, false)
	await _frames(3)


func _mouse(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos - _last_mouse  # 드래그 시작 판정은 relative 누적으로 한다
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_last_mouse = pos
	Input.parse_input_event(event)


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
