class_name DebugOverlay
extends Control
## 개발용 도구 (F1 토글, 디버그 빌드 전용): 저장/불러오기 슬롯 1, 돈 추가, 시간 건너뛰기(시간대·+1시간·취침).
## 릴리스 빌드에서는 만들지 않는다. ESC 로 닫힌다.

const SAVE_SLOT := 1
const TOGGLE_KEY := KEY_F1
const SKIP_HOURS := 1.0

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	UiStyles.apply_panel(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var title := Label.new()
	title.text = DataRegistry.text("ui_debug_title")
	column.add_child(title)
	_button(column, DataRegistry.text("ui_save"), func() -> void: SaveManager.save_slot(SAVE_SLOT))
	_button(column, DataRegistry.text("ui_load"), func() -> void:
		if SaveManager.load_slot(SAVE_SLOT) != OK:
			Events.message_posted.emit(DataRegistry.text("msg_load_failed")))
	var step := DataRegistry.tuning.get_int("debug_money_step")
	_button(column, DataRegistry.text("ui_debug_add_money", {"amount": step}), GameState.add_money.bind(step))

	# 시간 건너뛰기 — 테스트용. hold(대화·심사) 를 무시하고 시계를 밀므로 열린 대화는 먼저 닫는 편이 안전하다
	var skip_title := Label.new()
	skip_title.text = DataRegistry.text("ui_debug_time_title")
	column.add_child(skip_title)
	_button(column, DataRegistry.text("ui_debug_skip_hour"), skip_hour)
	_button(column, DataRegistry.text("ui_debug_skip_day"), func() -> void: skip_to_band(Clock.Band.DAY))
	_button(column, DataRegistry.text("ui_debug_skip_evening"), func() -> void: skip_to_band(Clock.Band.EVENING))
	_button(column, DataRegistry.text("ui_debug_skip_night"), func() -> void: skip_to_band(Clock.Band.NIGHT))
	_button(column, DataRegistry.text("ui_debug_sleep"), func() -> void: Clock.sleep())
	_button(column, DataRegistry.text("ui_close"), func() -> void: visible = false)


func skip_hour() -> void:
	var goal := Clock.timeline.seconds_for_hour(Clock.get_hour() + SKIP_HOURS)
	Clock.advance_seconds(maxf(goal - Clock.elapsed_seconds(), 0.0))


## 이미 지난 시간대를 고르면 취침 후 다음 날 그 시간대까지 간다.
func skip_to_band(band: int) -> void:
	if Clock.band >= band:
		Clock.sleep()
	Clock.advance_to_band(band)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
