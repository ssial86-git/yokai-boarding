class_name DebugHud
extends Control
## M1 검증용 최소 HUD: 날짜·페이즈·돈 표시, 페이즈 진행, 저장/불러오기, (디버그 빌드) 돈 추가, 메시지 줄.
## 정식 HUD 는 M4 에서 src/ui/ 에 별도 구현하고 이 노드는 그때 제거한다.

const SAVE_SLOT := 1
const HUD_MARGIN_PX := 4.0

var _day_label: Label
var _phase_label: Label
var _money_label: Label
var _message_label: Label
var _message_timer: Timer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := VBoxContainer.new()
	top.position = Vector2(HUD_MARGIN_PX, HUD_MARGIN_PX)
	add_child(top)
	var status := HBoxContainer.new()
	top.add_child(status)
	_day_label = _label(status)
	_phase_label = _label(status)
	_money_label = _label(status)

	var buttons := HBoxContainer.new()
	top.add_child(buttons)
	_button(buttons, DataRegistry.text("ui_next_phase"), Clock.advance_phase)
	_button(buttons, DataRegistry.text("ui_save"), _on_save_pressed)
	_button(buttons, DataRegistry.text("ui_load"), _on_load_pressed)
	if OS.is_debug_build():
		var step := DataRegistry.tuning.get_int("debug_money_step")
		_button(buttons, DataRegistry.text("ui_debug_add_money", {"amount": step}), GameState.add_money.bind(step))

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_message_label.position = Vector2(HUD_MARGIN_PX, get_viewport_rect().size.y - HUD_MARGIN_PX)
	_message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_message_label)
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.wait_time = DataRegistry.tuning.get_float("hud_message_seconds")
	_message_timer.timeout.connect(func() -> void: _message_label.text = "")
	add_child(_message_timer)

	Events.money_changed.connect(func(_amount: int) -> void: refresh())
	Events.phase_changed.connect(func(_phase: int, _day: int) -> void: refresh())
	Events.day_started.connect(func(_day: int) -> void: refresh())
	Events.house_action_failed.connect(func(outcome: int) -> void:
		show_message(DataRegistry.text(BuildMenu.outcome_text_key(outcome))))
	Events.room_changed.connect(_on_room_changed)
	Events.floor_added.connect(func(floor: int) -> void:
		show_message(DataRegistry.text("msg_floor_added", {"floor": floor + 1})))
	Events.game_saved.connect(func(slot: int) -> void: show_message(DataRegistry.text("msg_saved", {"slot": slot})))
	Events.game_loaded.connect(func(slot: int) -> void:
		refresh()
		show_message(DataRegistry.text("msg_loaded", {"slot": slot})))
	refresh()


func refresh() -> void:
	var phase_name: String = Clock.Phase.keys()[Clock.phase].to_lower()
	_day_label.text = DataRegistry.text("hud_day", {"day": GameState.day})
	_phase_label.text = DataRegistry.text("phase_%s" % phase_name)
	_money_label.text = DataRegistry.text("hud_money", {"money": GameState.money})


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer.start()


func _on_room_changed(_coords: Vector2i, room_id: String) -> void:
	var room := DataRegistry.get_room(room_id)
	if room == null or room.kind == RoomGrid.ROOM_KIND_EMPTY:
		show_message(DataRegistry.text("msg_demolished"))
	else:
		show_message(DataRegistry.text("msg_built", {"name": room.name_ko}))


func _on_save_pressed() -> void:
	SaveManager.save_slot(SAVE_SLOT)


func _on_load_pressed() -> void:
	if SaveManager.load_slot(SAVE_SLOT) != OK:
		show_message(DataRegistry.text("msg_load_failed"))


func _label(parent: Control) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
