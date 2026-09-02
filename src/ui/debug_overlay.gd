class_name DebugOverlay
extends Control
## 개발용 도구 (F1 토글, 디버그 빌드 전용): 저장/불러오기 슬롯 1, 돈 추가. 릴리스 빌드에서는 만들지 않는다.

const SAVE_SLOT := 1
const TOGGLE_KEY := KEY_F1

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


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
