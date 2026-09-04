extends Node2D
## 메인 씬 루트. 씬 트리는 여기서 코드로 조립한다 (CLAUDE.md 5.2 — .tscn 은 이 루트 하나뿐).
##
## Main
##  ├ HouseController        방 규칙 적용 + 돈 + Events
##  ├ AssignmentController   배치 규칙 적용 + Events
##  ├ DayCycle               날씨, 저녁 정산(산출·하숙비·체크아웃), 배치 무효화 정리
##  ├ StorySystem            사연·튜토리얼 이벤트 진행, 말 걸기
##  ├ IntakeSystem           저녁 방문자 추첨·심사 결정
##  ├ TutorialSystem         첫 행동 플래그 + 성주 영감 안내 문구
##  ├ AudioSystem            효과음·빗소리
##  ├ UnlockSystem           unlocks.csv 케이던스 (지역·도구·텃밭 확장 해금)
##  ├ FarmSystem             텃밭 행동·성장·자동 물주기
##  ├ GatherSystem           채집 포인트 리스폰·채집
##  ├ StationSystem          가마솥 요리·작업장 제작·도구 벼리기·배식·판매 (실시간)
##  ├ FishingSystem          낚시 타이밍 바·추첨
##  ├ ExpeditionSystem       잿빛 들: 적·미니보스 스폰, 동행 자동 전투, 부적 Q/R/G, 스태미너 0 후퇴
##  ├ World (Node2D)
##  │   ├ RegionManager      구역 전환 (문 통과)
##  │   │   ├ HouseRegion    걸어다니는 집: HouseView + YokaiManager + 바닥·계단·방 앞 상호작용·대문
##  │   │   ├ Region_*       야외 구역 (regions.csv 로 조립, 하나만 존재)
##  │   │   └ Player         CharacterBody2D 직접 조작
##  │   ├ Lighting           CanvasModulate 시간대 색조
##  │   └ Camera             플레이어 추적·줌·클릭 판정
##  └ UI (CanvasLayer)
##      ├ DropLayer          방 위에 카드 놓기 (투명)
##      ├ Hud                시계 카드·상태 칩·안내·체력 바·상호작용 알약
##      ├ MessageLog         왼쪽 아래 메시지
##      ├ AssignmentPanel    아침 배치 카드 (집 안에서만)
##      ├ BuildMenu
##      ├ MenuHub            장부 탭 메뉴: 창고 · 하숙부 · 명부 (Tab / I·J·L)
##      ├ IntakePanel        심사 카드
##      ├ StationMenu        요리·제작·판매 메뉴 (방 앞 E)
##      ├ FishingBar         낚시 타이밍 바
##      ├ DialogueBox        대화창
##      └ DebugOverlay       F1 (디버그 빌드 전용)

const MESSAGE_LOG_MARGIN_PX := 4.0
## 단축키 (UI 정리): Tab 메뉴 · I/J/L 탭 · Z 취침 · B 배치 접기. 코드로 등록한다.
const ACTION_MENU := &"ui_menu_toggle"
const ACTION_TAB_INVENTORY := &"ui_tab_inventory"
const ACTION_TAB_ROSTER := &"ui_tab_roster"
const ACTION_TAB_LEDGER := &"ui_tab_ledger"
const ACTION_TAB_CALENDAR := &"ui_tab_calendar"
const ACTION_TAB_GOALS := &"ui_tab_goals"
const ACTION_SLEEP := &"ui_sleep"
const ACTION_PANEL := &"ui_panel_toggle"

var house_controller: HouseController
var assignment_controller: AssignmentController
var day_cycle: DayCycle
var story_system: StorySystem
var intake_system: IntakeSystem
var tutorial_system: TutorialSystem
var audio_system: AudioSystem
var unlock_system: UnlockSystem
var farm_system: FarmSystem
var gather_system: GatherSystem
var station_system: StationSystem
var fishing_system: FishingSystem
var expedition_system: ExpeditionSystem
var goal_system: GoalSystem
var festival_system: FestivalSystem
var blessing_system: BlessingSystem
var market_system: MarketSystem
var chapter_system: ChapterSystem
var promotion_system: PromotionSystem
var blessing_menu: BlessingMenu
var market_menu: MarketMenu

## 상점 NPC 첫 인사 대화(events.csv kind npc "ev_<npc>_greet")와 그 대화가 남기는 플래그("<npc>_met")
const NPC_GREET_EVENT_FORMAT := "ev_%s_greet"
const NPC_MET_FLAG_FORMAT := "%s_met"
var station_menu: StationMenu
var fishing_bar: FishingBar
var region_manager: RegionManager
var house_region: HouseRegion
var player: PlayerController
var house_view: HouseView
var yokai_manager: YokaiManager
var camera: HouseCamera
var hud: Hud
var menu_hub: MenuHub
var message_log: MessageLog
var build_menu: BuildMenu
var assignment_panel: AssignmentPanel
var dialogue_box: DialogueBox
var intake_panel: IntakePanel


func _ready() -> void:
	_apply_window_scale()
	_ensure_input_actions()
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
	unlock_system = UnlockSystem.new()
	unlock_system.name = "UnlockSystem"
	add_child(unlock_system)
	farm_system = FarmSystem.new()
	farm_system.name = "FarmSystem"
	add_child(farm_system)
	gather_system = GatherSystem.new()
	gather_system.name = "GatherSystem"
	add_child(gather_system)
	station_system = StationSystem.new()
	station_system.name = "StationSystem"
	station_system.unlock_system = unlock_system
	add_child(station_system)
	fishing_system = FishingSystem.new()
	fishing_system.name = "FishingSystem"
	fishing_system.unlock_system = unlock_system
	add_child(fishing_system)
	expedition_system = ExpeditionSystem.new()
	expedition_system.name = "ExpeditionSystem"
	expedition_system.unlock_system = unlock_system
	expedition_system.gather_system = gather_system
	add_child(expedition_system)
	goal_system = GoalSystem.new()
	goal_system.name = "GoalSystem"
	add_child(goal_system)
	festival_system = FestivalSystem.new()
	festival_system.name = "FestivalSystem"
	festival_system.goal_system = goal_system
	add_child(festival_system)
	blessing_system = BlessingSystem.new()
	blessing_system.name = "BlessingSystem"
	blessing_system.unlock_system = unlock_system
	add_child(blessing_system)
	market_system = MarketSystem.new()
	market_system.name = "MarketSystem"
	add_child(market_system)
	chapter_system = ChapterSystem.new()
	chapter_system.name = "ChapterSystem"
	add_child(chapter_system)
	promotion_system = PromotionSystem.new()
	promotion_system.name = "PromotionSystem"
	promotion_system.unlock_system = unlock_system
	add_child(promotion_system)

	_build_world()
	_build_ui()

	house_region.open_room_menu = _open_room_menu
	yokai_manager.talk_action = _on_yokai_talk
	player.blocked_check = func() -> bool:
		return build_menu.is_open() or station_menu.is_open() or menu_hub.is_open() or blessing_menu.is_open() or market_menu.is_open()
	hud.modal_open_check = func() -> bool:
		return build_menu.is_open() or station_menu.is_open() or menu_hub.is_open() or intake_panel.visible \
			or blessing_menu.is_open() or market_menu.is_open()
	region_manager.merchant_action = _on_merchant_talk
	player.movement_locked_check = fishing_system.is_active
	region_manager.fishing_system = fishing_system
	expedition_system.region_manager = region_manager
	player.talisman_requested.connect(_on_talisman_requested)
	camera.clicked.connect(_on_world_clicked)
	camera.hovered.connect(house_view.set_hover)

	Clock.start_day()
	region_manager.travel(GameState.player_region, "", GameState.player_position)
	Events.game_started.emit()
	tutorial_system.refresh(true)


func _build_world() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	region_manager = RegionManager.new()
	region_manager.name = "RegionManager"
	house_region = HouseRegion.new()
	house_region.name = "HouseRegion"
	region_manager.house_region = house_region
	region_manager.add_child(house_region)
	player = PlayerController.new()
	player.name = "Player"
	region_manager.player = player
	region_manager.add_child(player)
	region_manager.farm_system = farm_system
	region_manager.gather_system = gather_system
	region_manager.unlock_system = unlock_system
	world.add_child(region_manager)
	house_view = house_region.house_view
	yokai_manager = house_region.yokai_manager
	house_view.drop_check = func(yokai_id: String, cell: Vector2i) -> bool:
		return assignment_controller.can_assign(yokai_id, cell) == AssignmentController.Outcome.OK

	var lighting := DayNightLighting.new()
	lighting.name = "Lighting"
	world.add_child(lighting)

	camera = HouseCamera.new()
	camera.name = "Camera"
	camera.follow = player
	var margin := float(DataRegistry.tuning.get_int("camera_bounds_margin_px"))
	camera.bounds = house_view.house_bounds().grow(margin)
	camera.position = house_view.house_bounds().get_center()
	region_manager.camera = camera
	world.add_child(camera)
	camera.clamp_to_bounds()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	# 모든 UI 는 테마를 가진 루트 Control 아래에 둔다 — 패널·버튼·칩이 같은 결이 되도록 (UiStyles.make_theme)
	var ui_root := Control.new()
	ui_root.name = "UiRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiStyles.make_theme()
	ui.add_child(ui_root)

	var drop_layer := DropLayer.new()
	drop_layer.name = "DropLayer"
	drop_layer.controller = assignment_controller
	drop_layer.house_view = house_view
	ui_root.add_child(drop_layer)

	menu_hub = MenuHub.new()
	menu_hub.name = "MenuHub"
	hud = Hud.new()
	hud.name = "Hud"
	hud.menu_hub = menu_hub
	hud.goal_system = goal_system
	ui_root.add_child(hud)

	message_log = MessageLog.new()
	message_log.name = "MessageLog"
	# 아래쪽에 앵커를 두고 위로 자라게 한다 — 패널이 숨어도(야외) 화면 밖으로 밀리지 않도록
	message_log.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	message_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_log.alignment = BoxContainer.ALIGNMENT_END  # 줄이 적어도 아래에 붙는다
	ui_root.add_child(message_log)

	assignment_panel = AssignmentPanel.new()
	assignment_panel.name = "AssignmentPanel"
	assignment_panel.controller = assignment_controller
	ui_root.add_child(assignment_panel)
	# 위 바와 아래 패널 사이에 집이 오도록 카메라를 밀고, 메시지 로그는 패널 바로 위에 붙인다.
	# 크기는 레이아웃이 끝난 뒤에야 맞으므로 실제 바/패널의 resized 에 걸고, 첫 프레임 뒤 한 번 더 잡는다.
	assignment_panel.resized.connect(_layout_around_panels)
	assignment_panel.visibility_changed.connect(_layout_around_panels)
	hud.bar_resized.connect(_layout_around_panels)
	_layout_around_panels.call_deferred()

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	build_menu.controller = house_controller
	ui_root.add_child(build_menu)

	intake_panel = IntakePanel.new()
	intake_panel.name = "IntakePanel"
	intake_panel.intake = intake_system
	ui_root.add_child(intake_panel)

	station_menu = StationMenu.new()
	station_menu.name = "StationMenu"
	station_menu.station_system = station_system
	station_menu.open_renovate = func(coords: Vector2i) -> void:
		build_menu.open_for_cell(coords, _player_screen_position())
	ui_root.add_child(station_menu)
	blessing_menu = BlessingMenu.new()
	blessing_menu.name = "BlessingMenu"
	blessing_menu.blessing_system = blessing_system
	ui_root.add_child(blessing_menu)
	market_menu = MarketMenu.new()
	market_menu.name = "MarketMenu"
	market_menu.market_system = market_system
	ui_root.add_child(market_menu)

	fishing_bar = FishingBar.new()
	fishing_bar.name = "FishingBar"
	fishing_bar.fishing_system = fishing_system
	ui_root.add_child(fishing_bar)

	menu_hub.goal_system = goal_system
	menu_hub.festival_system = festival_system
	menu_hub.chapter_system = chapter_system
	ui_root.add_child(menu_hub)  # 장부 메뉴는 작업 메뉴보다 위, 대화창보다 아래

	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	dialogue_box.story = story_system
	ui_root.add_child(dialogue_box)

	if OS.is_debug_build():
		var debug_overlay := DebugOverlay.new()
		debug_overlay.name = "DebugOverlay"
		ui_root.add_child(debug_overlay)


func _layout_around_panels() -> void:
	var view_size := get_viewport().get_visible_rect().size
	# 레이아웃 전의 엉뚱한 크기(0 이나 화면보다 큰 값)로 카메라를 밀지 않는다
	var top := clampf(hud.bar_height(), 0.0, view_size.y * 0.5)
	var bottom := clampf(assignment_panel.size.y if assignment_panel.visible else 0.0, 0.0, view_size.y * 0.5)
	camera.offset = Vector2(0, (bottom - top) * 0.5)
	message_log.offset_left = MESSAGE_LOG_MARGIN_PX
	message_log.offset_bottom = -hud.log_bottom_inset(bottom)  # 체력 바 위
	message_log.offset_top = message_log.offset_bottom - maxf(message_log.size.y, message_log.get_minimum_size().y)
	# 토스트 더미가 시계 카드·안내 줄까지 올라오지 않도록 (tuning message_log_top_ratio 아래에서만 쌓인다)
	message_log.max_height = maxf(
		view_size.y - hud.log_bottom_inset(bottom) - view_size.y * DataRegistry.tuning.get_float("message_log_top_ratio", 0.36), 0.0)
	hud.set_prompt_bottom(bottom + MESSAGE_LOG_MARGIN_PX)


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


## 입력 액션을 코드로 등록한다 (project.godot 의 입력 맵 직렬화 형식에 손대지 않기 위해).
## 이미 프로젝트 설정에 있으면 그대로 둔다.
func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		PlayerController.ACTION_LEFT: [KEY_A, KEY_LEFT],
		PlayerController.ACTION_RIGHT: [KEY_D, KEY_RIGHT],
		PlayerController.ACTION_UP: [KEY_W, KEY_UP],
		PlayerController.ACTION_DOWN: [KEY_S, KEY_DOWN],
		PlayerController.ACTION_RUN: [KEY_SHIFT],
		PlayerController.ACTION_INTERACT: [KEY_E, KEY_SPACE],
		PlayerController.ACTION_THROW: [KEY_Q],
		PlayerController.ACTION_RETURN: [KEY_R],
		PlayerController.ACTION_GATHER: [KEY_G],
		ACTION_MENU: [KEY_TAB],
		ACTION_TAB_INVENTORY: [KEY_I],
		ACTION_TAB_ROSTER: [KEY_J],
		ACTION_TAB_LEDGER: [KEY_L],
		ACTION_TAB_CALENDAR: [KEY_K],
		ACTION_TAB_GOALS: [KEY_H],
		ACTION_SLEEP: [KEY_Z],
		ACTION_PANEL: [KEY_B],
	}
	for action: StringName in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


## HUD 단축키. 대화·심사 중(Clock hold)에는 듣지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if Clock.is_held():
		return
	if event.is_action_pressed(ACTION_MENU):
		menu_hub.toggle()
	elif event.is_action_pressed(ACTION_TAB_INVENTORY):
		menu_hub.toggle(MenuHub.Tab.INVENTORY)
	elif event.is_action_pressed(ACTION_TAB_ROSTER):
		menu_hub.toggle(MenuHub.Tab.ROSTER)
	elif event.is_action_pressed(ACTION_TAB_LEDGER):
		menu_hub.toggle(MenuHub.Tab.LEDGER)
	elif event.is_action_pressed(ACTION_TAB_CALENDAR):
		menu_hub.toggle(MenuHub.Tab.CALENDAR)
	elif event.is_action_pressed(ACTION_TAB_GOALS):
		menu_hub.toggle(MenuHub.Tab.GOALS)
	elif event.is_action_pressed(ACTION_SLEEP):
		if Clock.can_sleep():
			Clock.sleep()
	elif event.is_action_pressed(ACTION_PANEL):
		assignment_panel.toggle_collapsed()
	else:
		return
	get_viewport().set_input_as_handled()


func _player_screen_position() -> Vector2:
	return get_viewport().get_canvas_transform() * player.global_position


## Q / R / G — 부적 사용은 ExpeditionSystem 이 판단한다 (탐험지 밖에서도 귀환·채집 부적은 쓸 수 있다).
func _on_talisman_requested(kind: String) -> void:
	match kind:
		"throw":
			expedition_system.throw_talisman()
		"return":
			expedition_system.use_return_talisman()
		"gather":
			expedition_system.use_gather_talisman()


## 방 앞에서 E: 주방 → 요리·배식, 작업장 → 제작·벼리기, 대문간 → 팔기, 그 외 → 건설·개조 메뉴.
## 하숙생 앞에서 E: 조건 맞는 사연이 있으면 대화, 없으면(인사 한 줄 뒤) 가호 접붙이기 메뉴 (P2-S3, 해금 뒤).
func _on_yokai_talk(yokai_id: String) -> void:
	if story_system.try_talk(yokai_id):
		return
	if blessing_system.is_open() and blessing_system.blessing_for(yokai_id) != null:
		blessing_menu.open_for(yokai_id)


## 상점 NPC 앞에서 E: 첫 만남은 인사 대화(플래그 <npc>_met), 그 뒤로는 그 상점의 거래 메뉴.
func _on_merchant_talk(npc_id: String, shop_id: String) -> void:
	if not GameState.flags.has(NPC_MET_FLAG_FORMAT % npc_id):
		var event := DataRegistry.get_event(NPC_GREET_EVENT_FORMAT % npc_id)
		if event != null and not story_system.is_busy():
			story_system.start_event(event)
			return
	market_menu.open(shop_id, npc_id)


func _open_room_menu(coords: Vector2i) -> void:
	var grid := house_view.grid()
	var room_id := grid.get_room_id(coords) if grid.is_floor_built(coords.y) else ""
	match room_id:
		"kitchen":
			station_menu.open_cook(coords)
		"workshop":
			station_menu.open_craft(coords)
		"gate":
			station_menu.open_sell(coords)
		_:
			build_menu.open_for_cell(coords, _player_screen_position())


## 집 안에서 방을 클릭해도 건설 메뉴가 열린다 (E 와 같은 기능 — 마우스 조작 유지).
func _on_world_clicked(world_pos: Vector2) -> void:
	if region_manager.current_region_id != HouseRegion.REGION_ID:
		return
	var coords := house_view.world_to_cell(world_pos)
	if house_view.grid().is_in_bounds(coords):
		build_menu.open_for_cell(coords, get_viewport().get_mouse_position())
