extends Node2D
## 메인 씬 루트. 씬 트리는 여기서 코드로 조립한다 (CLAUDE.md 5.2 — .tscn 은 이 루트 하나뿐).
##
## Main
##  ├ HouseController        방 규칙 적용 + 돈 + Events
##  ├ AssignmentController   배치 규칙 적용 + Events
##  ├ DayCycle               날씨, 저녁 정산(산출·하숙비·체크아웃), 배치 무효화 정리
##  ├ StorySystem            사연·튜토리얼 이벤트 진행
##  ├ IntakeSystem           저녁 방문자 추첨·심사 결정
##  ├ TutorialSystem         첫 행동 플래그 + 성주 영감 안내 문구
##  ├ AudioSystem            효과음·빗소리
##  ├ World (Node2D)
##  │   ├ HouseView          단면 렌더링 (RoomGrid 구독)
##  │   ├ YokaiManager       요괴·손님 액터 스폰·이동·또렷함·등불
##  │   ├ Lighting           CanvasModulate 시간대 색조
##  │   └ Camera             줌·드래그·클릭 판정
##  └ UI (CanvasLayer)
##      ├ DropLayer          방 위에 카드 놓기 (투명)
##      ├ Hud                상단 바·안내·창고
##      ├ MessageLog         왼쪽 아래 메시지
##      ├ AssignmentPanel    아침 배치 카드
##      ├ BuildMenu
##      ├ LedgerPanel        손님 명부
##      ├ RosterPanel        하숙부
##      ├ IntakePanel        심사 카드
##      ├ DialogueBox        대화창
##      └ DebugOverlay       F1 (디버그 빌드 전용)

const MESSAGE_LOG_MARGIN_PX := 4.0

var house_controller: HouseController
var assignment_controller: AssignmentController
var day_cycle: DayCycle
var story_system: StorySystem
var intake_system: IntakeSystem
var tutorial_system: TutorialSystem
var audio_system: AudioSystem
var house_view: HouseView
var yokai_manager: YokaiManager
var camera: HouseCamera
var hud: Hud
var message_log: MessageLog
var build_menu: BuildMenu
var assignment_panel: AssignmentPanel
var dialogue_box: DialogueBox
var intake_panel: IntakePanel


func _ready() -> void:
	_apply_window_scale()
	GameState.reset_new_game()

	house_controller = HouseController.new()
	house_controller.name = "HouseController"
	add_child(house_controller)
	assignment_controller = AssignmentController.new()
	assignment_controller.name = "AssignmentController"
	add_child(assignment_controller)
	day_cycle = DayCycle.new()
	day_cycle.name = "DayCycle"
	add_child(day_cycle)
	story_system = StorySystem.new()
	story_system.name = "StorySystem"
	add_child(story_system)
	intake_system = IntakeSystem.new()
	intake_system.name = "IntakeSystem"
	intake_system.is_dialogue_busy = story_system.is_busy
	add_child(intake_system)
	tutorial_system = TutorialSystem.new()
	tutorial_system.name = "TutorialSystem"
	add_child(tutorial_system)
	audio_system = AudioSystem.new()
	audio_system.name = "AudioSystem"
	add_child(audio_system)

	_build_world()
	_build_ui()

	camera.clicked.connect(_on_world_clicked)
	camera.hovered.connect(house_view.set_hover)

	Clock.start_day()
	Events.game_started.emit()
	tutorial_system.refresh(true)


func _build_world() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	house_view = HouseView.new()
	house_view.name = "HouseView"
	house_view.drop_check = func(yokai_id: String, cell: Vector2i) -> bool:
		return assignment_controller.can_assign(yokai_id, cell) == AssignmentController.Outcome.OK
	world.add_child(house_view)

	yokai_manager = YokaiManager.new()
	yokai_manager.name = "YokaiManager"
	yokai_manager.house_view = house_view
	world.add_child(yokai_manager)

	var lighting := DayNightLighting.new()
	lighting.name = "Lighting"
	world.add_child(lighting)

	camera = HouseCamera.new()
	camera.name = "Camera"
	var margin := float(DataRegistry.tuning.get_int("camera_bounds_margin_px"))
	camera.bounds = house_view.house_bounds().grow(margin)
	camera.position = house_view.house_bounds().get_center()
	world.add_child(camera)
	camera.clamp_to_bounds()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var drop_layer := DropLayer.new()
	drop_layer.name = "DropLayer"
	drop_layer.controller = assignment_controller
	drop_layer.house_view = house_view
	ui.add_child(drop_layer)

	var ledger_panel := LedgerPanel.new()
	ledger_panel.name = "LedgerPanel"
	var roster_panel := RosterPanel.new()
	roster_panel.name = "RosterPanel"

	hud = Hud.new()
	hud.name = "Hud"
	hud.ledger_panel = ledger_panel
	hud.roster_panel = roster_panel
	ui.add_child(hud)

	message_log = MessageLog.new()
	message_log.name = "MessageLog"
	ui.add_child(message_log)

	assignment_panel = AssignmentPanel.new()
	assignment_panel.name = "AssignmentPanel"
	assignment_panel.controller = assignment_controller
	ui.add_child(assignment_panel)
	# 위 바와 아래 패널 사이에 집이 오도록 카메라를 밀고, 메시지 로그는 패널 바로 위에 붙인다.
	# 크기는 레이아웃이 끝난 뒤에야 맞으므로 실제 바/패널의 resized 에 걸고, 첫 프레임 뒤 한 번 더 잡는다.
	assignment_panel.resized.connect(_layout_around_panels)
	hud.bar_resized.connect(_layout_around_panels)
	_layout_around_panels.call_deferred()

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	build_menu.controller = house_controller
	ui.add_child(build_menu)

	ui.add_child(ledger_panel)
	ui.add_child(roster_panel)

	intake_panel = IntakePanel.new()
	intake_panel.name = "IntakePanel"
	intake_panel.intake = intake_system
	ui.add_child(intake_panel)

	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	dialogue_box.story = story_system
	ui.add_child(dialogue_box)

	if OS.is_debug_build():
		var debug_overlay := DebugOverlay.new()
		debug_overlay.name = "DebugOverlay"
		ui.add_child(debug_overlay)


func _layout_around_panels() -> void:
	var view_size := get_viewport().get_visible_rect().size
	# 레이아웃 전의 엉뚱한 크기(0 이나 화면보다 큰 값)로 카메라를 밀지 않는다
	var top := clampf(hud.bar_height(), 0.0, view_size.y * 0.5)
	var bottom := clampf(assignment_panel.size.y, 0.0, view_size.y * 0.5)
	camera.offset = Vector2(0, (bottom - top) * 0.5)
	message_log.position = Vector2(MESSAGE_LOG_MARGIN_PX, view_size.y - bottom - MESSAGE_LOG_MARGIN_PX)
	message_log.grow_vertical = Control.GROW_DIRECTION_BEGIN


## 창 크기를 뷰포트(640x360)의 정수 배로 맞춘다. tuning window_integer_scale 이 0 이면 화면에 맞는 최대 배율.
## 고해상도 모니터에서 2배(1280x720) 창이 너무 작게 보이는 문제를 피한다. 스크린샷 러너 등 창이 없는 실행은 건너뛴다.
func _apply_window_scale() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tuning := DataRegistry.tuning
	var base := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	)
	var scale := tuning.get_int("window_integer_scale")
	if scale <= 0:
		var usable := Vector2(DisplayServer.screen_get_usable_rect().size) * tuning.get_float("window_auto_scale_fill")
		scale = maxi(1, mini(floori(usable.x / base.x), floori(usable.y / base.y)))
	var window_size := base * scale
	var screen_rect := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(window_size)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - window_size) / 2)


func _on_world_clicked(world_pos: Vector2) -> void:
	var coords := house_view.world_to_cell(world_pos)
	if house_view.grid().is_in_bounds(coords):
		build_menu.open_for_cell(coords, get_viewport().get_mouse_position())
