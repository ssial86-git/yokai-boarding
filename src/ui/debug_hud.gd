class_name DebugHud
extends Control
## M1~M2 검증용 최소 HUD: 날짜·페이즈·돈·창고 표시, 낮 진행 바, 페이즈 진행, 저장/불러오기,
## (디버그 빌드) 돈 추가, 메시지 줄. 정식 HUD 는 M4 에서 src/ui/ 에 별도 구현하고 이 노드는 그때 제거한다.

const SAVE_SLOT := 1
const HUD_MARGIN_PX := 4.0
const PROGRESS_WIDTH_PX := 160.0
const MESSAGE_BOTTOM_OFFSET_PX := 96.0

var _day_label: Label
var _phase_label: Label
var _money_label: Label
var _inventory_label: Label
var _advance_button: Button
var _progress: ProgressBar
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
	_inventory_label = _label(top)

	var buttons := HBoxContainer.new()
	top.add_child(buttons)
	_advance_button = _button(buttons, "", Clock.advance_phase)
	_button(buttons, DataRegistry.text("ui_save"), _on_save_pressed)
	_button(buttons, DataRegistry.text("ui_load"), _on_load_pressed)
	if OS.is_debug_build():
		var step := DataRegistry.tuning.get_int("debug_money_step")
		_button(buttons, DataRegistry.text("ui_debug_add_money", {"amount": step}), GameState.add_money.bind(step))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(PROGRESS_WIDTH_PX, 0)
	_progress.max_value = 1.0
	_progress.show_percentage = false
	top.add_child(_progress)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_message_label.position = Vector2(HUD_MARGIN_PX, get_viewport_rect().size.y - MESSAGE_BOTTOM_OFFSET_PX)
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
	Events.item_added.connect(func(_id: String, _count: int) -> void: refresh())
	Events.house_action_failed.connect(func(outcome: int) -> void:
		show_message(DataRegistry.text(BuildMenu.outcome_text_key(outcome))))
	Events.assignment_failed.connect(func(_id: String, outcome: int) -> void:
		show_message(DataRegistry.text(AssignmentController.outcome_text_key(outcome))))
	Events.assignment_changed.connect(_on_assignment_changed)
	Events.room_changed.connect(_on_room_changed)
	Events.floor_added.connect(func(floor: int) -> void:
		show_message(DataRegistry.text("msg_floor_added", {"floor": floor + 1})))
	Events.day_settled.connect(_on_day_settled)
	Events.game_saved.connect(func(slot: int) -> void: show_message(DataRegistry.text("msg_saved", {"slot": slot})))
	Events.game_loaded.connect(func(slot: int) -> void:
		refresh()
		show_message(DataRegistry.text("msg_loaded", {"slot": slot})))
	refresh()


func _process(_delta: float) -> void:
	_progress.value = Clock.get_phase_progress()


func refresh() -> void:
	var phase_name: String = Clock.Phase.keys()[Clock.phase].to_lower()
	_day_label.text = DataRegistry.text("hud_day", {"day": GameState.day})
	_phase_label.text = DataRegistry.text("phase_%s" % phase_name)
	_money_label.text = DataRegistry.text("hud_money", {"money": GameState.money})
	_advance_button.text = DataRegistry.text("ui_advance_%s" % phase_name)
	_progress.visible = Clock.get_phase_length(Clock.phase) > 0.0
	var items := GameState.inventory.items()
	if items.is_empty():
		_inventory_label.text = DataRegistry.text("hud_inventory_empty")
	else:
		var parts: Array[String] = []
		for item_id: String in items:
			parts.append(DataRegistry.text("hud_inventory_item",
				{"name": DataRegistry.item_name(item_id), "count": items[item_id]}))
		_inventory_label.text = DataRegistry.text("hud_inventory", {"list": ", ".join(parts)})


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer.start()


func _on_room_changed(_coords: Vector2i, room_id: String) -> void:
	var room := DataRegistry.get_room(room_id)
	if room == null or room.kind == RoomGrid.ROOM_KIND_EMPTY:
		show_message(DataRegistry.text("msg_demolished"))
	else:
		show_message(DataRegistry.text("msg_built", {"name": room.name_ko}))


func _on_assignment_changed(yokai_id: String, cell: Vector2i) -> void:
	var yokai_name := DataRegistry.yokai_name(yokai_id)
	if cell == Assignment.REST:
		show_message(DataRegistry.text("msg_rested", {"name": yokai_name}))
	else:
		var room_name := DataRegistry.room_name(GameState.room_grid.get_room_id(cell))
		show_message(DataRegistry.text("msg_assigned", {"name": yokai_name, "room": room_name}))


func _on_day_settled(summary: Dictionary) -> void:
	var totals: Dictionary = summary.get("totals", {})
	var lines: Array[String] = []
	if totals.is_empty():
		lines.append(DataRegistry.text("msg_settled_none", {"day": summary.get("day", GameState.day)}))
	else:
		var parts: Array[String] = []
		for item_id: String in totals:
			parts.append(DataRegistry.text("hud_inventory_item",
				{"name": DataRegistry.item_name(item_id), "count": totals[item_id]}))
		lines.append(DataRegistry.text("msg_settled", {"day": summary.get("day", GameState.day), "summary": ", ".join(parts)}))
	for yokai_id: String in summary.get("noise_hits", {}):
		lines.append(DataRegistry.text("msg_noise_hit", {"name": DataRegistry.yokai_name(yokai_id)}))
	show_message("\n".join(lines))
	refresh()


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
