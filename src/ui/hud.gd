class_name Hud
extends Control
## HUD (UI 정리 2026-09-04). 유사 생활 시뮬 관행을 따른다: 시계·날짜·날씨는 한 카드, 돈·평판·침대는 상태 칩,
## 체력 바는 왼쪽 아래, 상호작용 안내는 오른쪽 아래 알약, 창고·하숙부·명부는 Tab 하나로 여는 탭 메뉴(MenuHub).
## 모든 기능은 단축키 하나(Z 취침 · Tab 메뉴 · I/J/L 탭 · B 배치 접기), ESC 는 닫기.
## 사람용 문장은 Events.message_posted 로 MessageLog 에 보낸다. 디버그 도구는 DebugOverlay 로 분리.

## 상단 카드 줄의 실제 높이가 바뀔 때 (레이아웃 확정·안내 줄 표시/숨김). main.gd 가 카메라 오프셋을 다시 잡는다.
signal bar_resized

const HINT_WIDTH_RATIO := 0.6
const STAMINA_BAR_HEIGHT := 6.0
const EXPEDITION_KIND := "expedition"

var menu_hub: MenuHub

var _top: HBoxContainer
var _clock_line1: Label
var _clock_line2: Label
var _progress: ProgressBar
var _money_chip: Label
var _reputation_chip: Label
var _beds_chip: Label
var _sleep_button: Button
var _hint_panel: PanelContainer
var _hint_label: Label
var _stamina_panel: PanelContainer
var _stamina: ProgressBar
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _expedition_chip: PanelContainer
var _margin: float = 4.0
var _stamina_low: float = 20.0
## 시계는 매 프레임 흐르므로 표시 분이 바뀔 때만 다시 그린다.
var _last_hour_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tuning := DataRegistry.tuning
	_margin = float(tuning.get_int("ui_margin_px", 4))
	_stamina_low = tuning.get_float("stamina_low_threshold", _stamina_low)

	_build_top()
	_build_hint()
	_build_stamina(tuning)
	_build_prompt()

	Events.prompt_changed.connect(set_prompt)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.region_entered.connect(_on_region_entered)
	Events.hint_changed.connect(_on_hint_changed)
	for refresh_signal: Signal in [
		Events.money_changed, Events.timeband_changed, Events.day_started,
		Events.reputation_changed, Events.weather_changed, Events.guests_changed, Events.yokai_arrived,
		Events.room_changed, Events.floor_added, Events.game_loaded,
	]:
		refresh_signal.connect(func(_a: Variant = null, _b: Variant = null) -> void: refresh())
	_connect_messages()
	refresh()


func _build_top() -> void:
	_top = HBoxContainer.new()
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = _margin
	_top.offset_right = -_margin
	_top.offset_top = _margin
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.resized.connect(func() -> void:
		_layout_hint()
		bar_resized.emit())
	add_child(_top)

	# 시계 카드: "06:00 아침 · 1일차" / "맑음 · 하숙집" + 하루 진행 바
	var clock_card := PanelContainer.new()
	_top.add_child(clock_card)
	var clock_column := VBoxContainer.new()
	clock_card.add_child(clock_column)
	_clock_line1 = UiStyles.header("")
	clock_column.add_child(_clock_line1)
	_clock_line2 = UiStyles.dim("")
	clock_column.add_child(_clock_line2)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 3)
	clock_column.add_child(_progress)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(spacer)

	# 상태 칩 + 버튼
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_top.add_child(right)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(chips)
	_money_chip = UiStyles.text_chip(chips, "")
	_reputation_chip = UiStyles.text_chip(chips, "")
	_beds_chip = UiStyles.text_chip(chips, "")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	_sleep_button = UiStyles.key_button(buttons, DataRegistry.text("ui_sleep"), DataRegistry.text("key_hint_sleep"),
		func() -> void: Clock.sleep())
	UiStyles.key_button(buttons, DataRegistry.text("ui_menu"), DataRegistry.text("key_hint_menu"),
		func() -> void:
			if menu_hub != null:
				menu_hub.toggle())


func _build_hint() -> void:
	# 성주 영감 안내: 위 가운데, 카드 줄 아래
	_hint_panel = PanelContainer.new()
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.visible = false
	add_child(_hint_panel)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(get_viewport_rect().size.x * HINT_WIDTH_RATIO, 0)
	_hint_panel.add_child(_hint_label)


func _build_stamina(tuning: TuningData) -> void:
	_stamina_panel = PanelContainer.new()
	UiStyles.apply_chip(_stamina_panel)
	_stamina_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_stamina_panel)
	var row := HBoxContainer.new()
	_stamina_panel.add_child(row)
	row.add_child(UiStyles.dim(DataRegistry.text("hud_stamina_label")))
	_stamina = ProgressBar.new()
	_stamina.max_value = GameState.stamina.params.max_value
	_stamina.value = GameState.stamina.value
	_stamina.show_percentage = false
	_stamina.custom_minimum_size = Vector2(tuning.get_int("stamina_bar_width_px", 110), STAMINA_BAR_HEIGHT)
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stamina)


func _build_prompt() -> void:
	# 상호작용 안내 알약: 오른쪽 아래
	_prompt_panel = PanelContainer.new()
	UiStyles.apply_chip(_prompt_panel)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.visible = false
	add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.add_theme_color_override("font_color", UiStyles.color("ui_accent_color", "f2a65a"))
	_prompt_panel.add_child(_prompt_label)
	# 탐험지 조작 칩: 알약 위
	_expedition_chip = PanelContainer.new()
	UiStyles.apply_chip(_expedition_chip)
	_expedition_chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_expedition_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_expedition_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_expedition_chip.visible = false
	add_child(_expedition_chip)
	_expedition_chip.add_child(UiStyles.dim(DataRegistry.text("hud_expedition_chip")))


func _process(_delta: float) -> void:
	_progress.value = Clock.get_day_progress()
	if Clock.format_hour() != _last_hour_text:
		refresh()


## 상단 카드 줄 높이 (카메라 오프셋용).
func bar_height() -> float:
	return maxf(_top.size.y, _top.get_combined_minimum_size().y) + _margin * 2.0


## 취침 버튼의 화면 사각형 (검증용 — 상단이 화면을 넘지 않는지).
func sleep_button_rect() -> Rect2:
	return _sleep_button.get_global_rect()


func refresh() -> void:
	_last_hour_text = Clock.format_hour()
	var region := DataRegistry.get_region(GameState.player_region)
	_clock_line1.text = DataRegistry.text("hud_clock_line1", {
		"time": _last_hour_text, "timeband": DataRegistry.text("timeband_%s" % Clock.band_name()), "day": GameState.day})
	_clock_line2.text = DataRegistry.text("hud_clock_line2", {
		"weather": DataRegistry.text("weather_%s" % GameState.weather),
		"region": region.name_ko if region != null else GameState.player_region})
	_money_chip.text = DataRegistry.text("chip_money", {"money": GameState.money})
	_reputation_chip.text = DataRegistry.text("chip_reputation", {"value": GameState.reputation})
	_beds_chip.text = DataRegistry.text("chip_beds", {
		"used": Lodging.used_beds(GameState.residents, GameState.guests),
		"total": Lodging.total_beds(GameState.room_grid)})
	_sleep_button.disabled = not Clock.can_sleep()
	_layout_hint()


func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = not text.is_empty()


## 아래쪽 요소(체력 바·안내 알약·탐험 칩)를 배치 패널 위로 올린다 (main.gd 가 패널 높이를 잰 뒤 부른다).
func set_prompt_bottom(bottom_px: float) -> void:
	var inset := bottom_px + _margin
	_prompt_panel.offset_bottom = -inset
	_prompt_panel.offset_top = -inset - _prompt_panel.get_combined_minimum_size().y
	_prompt_panel.offset_right = -_margin
	var chip_bottom := inset + _prompt_panel.get_combined_minimum_size().y + _margin
	_expedition_chip.offset_bottom = -chip_bottom
	_expedition_chip.offset_top = -chip_bottom - _expedition_chip.get_combined_minimum_size().y
	_expedition_chip.offset_right = -_margin
	_stamina_panel.offset_left = _margin
	_stamina_panel.offset_bottom = -inset
	_stamina_panel.offset_top = -inset - _stamina_panel.get_combined_minimum_size().y


## 왼쪽 아래 메시지 로그가 앉을 바닥 (체력 바 위).
func log_bottom_inset(bottom_px: float) -> float:
	return bottom_px + _margin * 2.0 + _stamina_panel.get_combined_minimum_size().y


func prompt_text() -> String:
	return _prompt_label.text if _prompt_panel.visible else ""


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina.max_value = max_value
	_stamina.value = value
	_stamina.modulate = Color.html(DataRegistry.tuning.get_string(
		"drop_bad_color" if value <= _stamina_low else "drop_ok_color"))


func _on_region_entered(region_id: String) -> void:
	var region := DataRegistry.get_region(region_id)
	_expedition_chip.visible = region != null and region.kind == EXPEDITION_KIND
	refresh()


func _on_hint_changed(text: String) -> void:
	_hint_panel.visible = not text.is_empty()
	_hint_label.text = DataRegistry.text("hud_hint_prefix", {"text": text}) if not text.is_empty() else ""
	_layout_hint()


## 안내 줄은 상단 카드 줄 바로 아래. 레이아웃 전에는 size 가 0 이라 최소 크기와 비교해 큰 쪽을 쓴다.
func _layout_hint() -> void:
	var top_height := maxf(_top.size.y, _top.get_combined_minimum_size().y)
	_hint_panel.offset_top = top_height + _margin * 2.0
	_hint_panel.offset_bottom = _hint_panel.offset_top + _hint_panel.get_combined_minimum_size().y


## 시스템 시그널을 사람용 문장으로 바꿔 메시지 로그에 보낸다.
func _connect_messages() -> void:
	Events.house_action_failed.connect(func(outcome: int) -> void:
		_post(DataRegistry.text(BuildMenu.outcome_text_key(outcome))))
	Events.assignment_failed.connect(func(_id: String, outcome: int) -> void:
		_post(DataRegistry.text(AssignmentController.outcome_text_key(outcome))))
	Events.assignment_changed.connect(func(yokai_id: String, cell: Vector2i) -> void:
		_post(HudText.assignment(yokai_id, cell)))
	Events.room_changed.connect(func(_coords: Vector2i, room_id: String) -> void: _post(HudText.room_changed(room_id)))
	Events.floor_added.connect(func(floor: int) -> void:
		_post(DataRegistry.text("msg_floor_added", {"floor": floor + 1})))
	Events.day_settled.connect(func(summary: Dictionary) -> void: _post(HudText.settlement(summary)))
	Events.visitor_knocked.connect(func(visitor: Dictionary) -> void:
		if visitor.is_empty():
			_post(DataRegistry.text("msg_visitor_none")))
	Events.intake_decided.connect(func(visitor: Dictionary, outcome: int) -> void:
		_post(HudText.intake(visitor, outcome)))
	Events.yokai_arrived.connect(func(yokai_id: String) -> void:
		_post(DataRegistry.text("msg_yokai_joined", {"name": DataRegistry.yokai_name(yokai_id)})))
	Events.dialogue_started.connect(func(event_id: String) -> void:
		var event := DataRegistry.get_event(event_id)
		if event != null and event.kind == "story":
			_post(DataRegistry.text("msg_story_started", {"title": event.title_ko})))
	Events.slept.connect(func(day: int, forced: bool) -> void:
		_post(DataRegistry.text("msg_slept_forced" if forced else "msg_slept", {"day": day})))
	Events.game_saved.connect(func(slot: int) -> void: _post(DataRegistry.text("msg_saved", {"slot": slot})))
	Events.game_loaded.connect(func(slot: int) -> void: _post(DataRegistry.text("msg_loaded", {"slot": slot})))


func _post(text: String) -> void:
	if not text.is_empty():
		Events.message_posted.emit(text)
