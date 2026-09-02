class_name Hud
extends Control
## 정식 HUD: 상단 바(날짜·페이즈·날씨·돈·평판·침대 / 행동 버튼), 성주 영감 안내 줄, 낮 진행 바, 창고 줄.
## 사람용 문장은 Events.message_posted 로 MessageLog 에 보낸다. 디버그 도구는 DebugOverlay 로 분리.

## 상단 바의 실제 높이가 바뀔 때 (레이아웃 확정·안내 줄 표시/숨김). main.gd 가 카메라 오프셋을 다시 잡는다.
signal bar_resized

var ledger_panel: LedgerPanel
var roster_panel: RosterPanel

var _status_label: Label
var _inventory_label: Label
var _hint_label: Label
var _advance_button: Button
var _progress: ProgressBar
var _bar: PanelContainer


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
	_advance_button = Button.new()
	_advance_button.pressed.connect(Clock.advance_phase)
	row.add_child(_advance_button)
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

	for refresh_signal: Signal in [
		Events.money_changed, Events.phase_changed, Events.day_started, Events.item_added, Events.item_removed,
		Events.reputation_changed, Events.weather_changed, Events.guests_changed, Events.yokai_arrived,
		Events.room_changed, Events.floor_added, Events.game_loaded,
	]:
		refresh_signal.connect(func(_a: Variant = null, _b: Variant = null) -> void: refresh())
	Events.hint_changed.connect(_on_hint_changed)
	_connect_messages()
	refresh()


func _process(_delta: float) -> void:
	_progress.value = Clock.get_phase_progress()


func bar_height() -> float:
	return _bar.size.y


func refresh() -> void:
	var phase_name: String = Clock.Phase.keys()[Clock.phase].to_lower()
	_status_label.text = " · ".join([
		DataRegistry.text("hud_day", {"day": GameState.day}),
		DataRegistry.text("phase_%s" % phase_name),
		DataRegistry.text("weather_%s" % GameState.weather),
		DataRegistry.text("hud_money", {"money": GameState.money}),
		DataRegistry.text("hud_reputation", {"value": GameState.reputation}),
		DataRegistry.text("hud_beds", {
			"used": Lodging.used_beds(GameState.residents, GameState.guests),
			"total": Lodging.total_beds(GameState.room_grid)}),
	])
	_advance_button.text = DataRegistry.text("ui_advance_%s" % phase_name)
	_progress.visible = Clock.get_phase_length(Clock.phase) > 0.0
	var items := GameState.inventory.items()
	_inventory_label.text = DataRegistry.text("hud_inventory_empty") if items.is_empty() \
		else DataRegistry.text("hud_inventory", {"list": HudText.item_list(items)})


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
	Events.phase_changed.connect(func(phase: int, _day: int) -> void:
		if phase == Clock.Phase.NIGHT and not get_tree().get_first_node_in_group("story_busy"):
			pass)
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
