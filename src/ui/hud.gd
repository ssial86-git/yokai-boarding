class_name Hud
extends Control
## 정식 HUD: 상단 바(날짜·시각·시간대·날씨·돈·평판·침대 / 취침 버튼), 성주 영감 안내 줄, 하루 진행 바, 창고 줄.
## 사람용 문장은 Events.message_posted 로 MessageLog 에 보낸다. 디버그 도구는 DebugOverlay 로 분리.

## 상단 바의 실제 높이가 바뀔 때 (레이아웃 확정·안내 줄 표시/숨김). main.gd 가 카메라 오프셋을 다시 잡는다.
signal bar_resized

const PROMPT_MARGIN_PX := 4.0

var ledger_panel: LedgerPanel
var roster_panel: RosterPanel

var _status_label: Label
var _inventory_label: Label
var _hint_label: Label
var _sleep_button: Button
var _progress: ProgressBar
var _stamina: ProgressBar
var _prompt_label: Label
var _bar: PanelContainer
var _stamina_low: float = 20.0
## 시계는 매 프레임 흐르므로 표시 분이 바뀔 때만 상태 줄을 다시 그린다.
var _last_hour_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bar = PanelContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	UiStyles.apply_panel(_bar)
	_bar.resized.connect(func() -> void: bar_resized.emit())
	add_child(_bar)
	var column := VBoxContainer.new()
	_bar.add_child(column)

	var row := HBoxContainer.new()
	column.add_child(row)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_label)
	_sleep_button = Button.new()
	_sleep_button.text = DataRegistry.text("ui_sleep")
	_sleep_button.pressed.connect(func() -> void: Clock.sleep())
	row.add_child(_sleep_button)
	_button(row, DataRegistry.text("ui_roster"), func() -> void: roster_panel.toggle())
	_button(row, DataRegistry.text("ui_ledger"), func() -> void: ledger_panel.toggle())

	_inventory_label = Label.new()
	column.add_child(_inventory_label)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_label)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 4)
	column.add_child(_progress)
	_stamina = ProgressBar.new()
	_stamina.max_value = GameState.stamina.params.max_value
	_stamina.value = GameState.stamina.value
	_stamina.show_percentage = false
	_stamina.custom_minimum_size = Vector2(0, 4)
	_stamina.modulate = Color.html(DataRegistry.tuning.get_string("drop_ok_color"))
	_stamina_low = DataRegistry.tuning.get_float("stamina_low_threshold", _stamina_low)
	column.add_child(_stamina)

	# 상호작용 안내 ("E: 캐기"): 화면 오른쪽 아래, 배치 패널 위 (왼쪽 아래 메시지 로그와 겹치지 않게)
	_prompt_label = Label.new()
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.visible = false
	add_child(_prompt_label)
	Events.prompt_changed.connect(set_prompt)
	Events.stamina_changed.connect(func(value: float, max_value: float) -> void:
		_stamina.max_value = max_value
		_stamina.value = value
		_stamina.modulate = Color.html(DataRegistry.tuning.get_string(
			"drop_bad_color" if value <= _stamina_low else "drop_ok_color")))
	Events.region_entered.connect(func(_region_id: String) -> void: refresh())

	for refresh_signal: Signal in [
		Events.money_changed, Events.timeband_changed, Events.day_started, Events.item_added, Events.item_removed,
		Events.reputation_changed, Events.weather_changed, Events.guests_changed, Events.yokai_arrived,
		Events.room_changed, Events.floor_added, Events.game_loaded,
	]:
		refresh_signal.connect(func(_a: Variant = null, _b: Variant = null) -> void: refresh())
	Events.hint_changed.connect(_on_hint_changed)
	_connect_messages()
	refresh()


func _process(_delta: float) -> void:
	_progress.value = Clock.get_day_progress()
	if Clock.format_hour() != _last_hour_text:
		refresh()


func bar_height() -> float:
	return _bar.size.y


func refresh() -> void:
	_last_hour_text = Clock.format_hour()
	var region := DataRegistry.get_region(GameState.player_region)
	_status_label.text = " · ".join([
		DataRegistry.text("hud_day", {"day": GameState.day}),
		DataRegistry.text("hud_time", {"time": _last_hour_text}),
		DataRegistry.text("timeband_%s" % Clock.band_name()),
		DataRegistry.text("hud_region", {"name": region.name_ko if region != null else GameState.player_region}),
		DataRegistry.text("weather_%s" % GameState.weather),
		DataRegistry.text("hud_money", {"money": GameState.money}),
		DataRegistry.text("hud_reputation", {"value": GameState.reputation}),
		DataRegistry.text("hud_beds", {
			"used": Lodging.used_beds(GameState.residents, GameState.guests),
			"total": Lodging.total_beds(GameState.room_grid)}),
	])
	_sleep_button.disabled = not Clock.can_sleep()
	var items := GameState.inventory.items()
	_inventory_label.text = DataRegistry.text("hud_inventory_empty") if items.is_empty() \
		else DataRegistry.text("hud_inventory", {"list": HudText.item_list(items)})


func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


## 안내 문구를 아래 패널 위로 올린다 (main.gd 가 패널 높이를 잰 뒤 부른다).
func set_prompt_bottom(bottom_px: float) -> void:
	_prompt_label.offset_bottom = -bottom_px
	_prompt_label.offset_top = -bottom_px - _prompt_label.get_minimum_size().y
	_prompt_label.offset_right = -PROMPT_MARGIN_PX


func prompt_text() -> String:
	return _prompt_label.text if _prompt_label.visible else ""


func _on_hint_changed(text: String) -> void:
	_hint_label.visible = not text.is_empty()
	_hint_label.text = DataRegistry.text("hud_hint_prefix", {"text": text}) if not text.is_empty() else ""


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


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
