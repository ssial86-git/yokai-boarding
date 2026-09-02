class_name DebugHud
extends Control
## M1~M3 검증용 최소 HUD: 날짜·페이즈·날씨·돈·평판·침대·창고, 낮 진행 바, 페이즈 진행, 명부, 저장/불러오기,
## (디버그 빌드) 돈 추가, 메시지 줄. 정식 HUD 는 M4 에서 src/ui/ 에 별도 구현하고 이 노드는 그때 제거한다.

const SAVE_SLOT := 1
const HUD_MARGIN_PX := 4.0
const PROGRESS_WIDTH_PX := 160.0
const MESSAGE_BOTTOM_OFFSET_PX := 96.0

var ledger_panel: LedgerPanel

var _status_label: Label
var _inventory_label: Label
var _advance_button: Button
var _progress: ProgressBar
var _message_label: Label
var _message_timer: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := VBoxContainer.new()
	top.position = Vector2(HUD_MARGIN_PX, HUD_MARGIN_PX)
	add_child(top)
	_status_label = _label(top)
	_inventory_label = _label(top)

	var buttons := HBoxContainer.new()
	top.add_child(buttons)
	_advance_button = _button(buttons, "", Clock.advance_phase)
	_button(buttons, DataRegistry.text("ui_ledger"), func() -> void:
		if ledger_panel != null:
			ledger_panel.toggle())
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
	_message_label.position = Vector2(HUD_MARGIN_PX, get_viewport_rect().size.y - MESSAGE_BOTTOM_OFFSET_PX)
	_message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_message_label)
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.wait_time = DataRegistry.tuning.get_float("hud_message_seconds")
	_message_timer.timeout.connect(func() -> void: _message_label.text = "")
	add_child(_message_timer)

	for refresh_signal: Signal in [
		Events.money_changed, Events.phase_changed, Events.day_started, Events.item_added, Events.item_removed,
		Events.reputation_changed, Events.weather_changed, Events.guests_changed, Events.yokai_arrived,
		Events.room_changed, Events.floor_added,
	]:
		refresh_signal.connect(func(_a: Variant = null, _b: Variant = null) -> void: refresh())
	Events.house_action_failed.connect(func(outcome: int) -> void:
		show_message(DataRegistry.text(BuildMenu.outcome_text_key(outcome))))
	Events.assignment_failed.connect(func(_id: String, outcome: int) -> void:
		show_message(DataRegistry.text(AssignmentController.outcome_text_key(outcome))))
	Events.assignment_changed.connect(_on_assignment_changed)
	Events.room_changed.connect(_on_room_changed)
	Events.floor_added.connect(func(floor: int) -> void:
		show_message(DataRegistry.text("msg_floor_added", {"floor": floor + 1})))
	Events.day_settled.connect(_on_day_settled)
	Events.visitor_knocked.connect(func(visitor: Dictionary) -> void:
		if visitor.is_empty():
			show_message(DataRegistry.text("msg_visitor_none")))
	Events.intake_decided.connect(_on_intake_decided)
	Events.yokai_arrived.connect(func(yokai_id: String) -> void:
		show_message(DataRegistry.text("msg_yokai_joined", {"name": DataRegistry.yokai_name(yokai_id)})))
	Events.game_saved.connect(func(slot: int) -> void: show_message(DataRegistry.text("msg_saved", {"slot": slot})))
	Events.game_loaded.connect(func(slot: int) -> void:
		refresh()
		show_message(DataRegistry.text("msg_loaded", {"slot": slot})))
	refresh()


func _process(_delta: float) -> void:
	_progress.value = Clock.get_phase_progress()


func refresh() -> void:
	var phase_name: String = Clock.Phase.keys()[Clock.phase].to_lower()
	var beds_total := Lodging.total_beds(GameState.room_grid)
	var beds_used := Lodging.used_beds(GameState.residents, GameState.guests)
	_status_label.text = " · ".join([
		DataRegistry.text("hud_day", {"day": GameState.day}),
		DataRegistry.text("phase_%s" % phase_name),
		DataRegistry.text("weather_%s" % GameState.weather),
		DataRegistry.text("hud_money", {"money": GameState.money}),
		DataRegistry.text("hud_reputation", {"value": GameState.reputation}),
		DataRegistry.text("hud_beds", {"used": beds_used, "total": beds_total}),
	])
	_advance_button.text = DataRegistry.text("ui_advance_%s" % phase_name)
	_progress.visible = Clock.get_phase_length(Clock.phase) > 0.0
	var items := GameState.inventory.items()
	if items.is_empty():
		_inventory_label.text = DataRegistry.text("hud_inventory_empty")
	else:
		_inventory_label.text = DataRegistry.text("hud_inventory", {"list": _item_list(items)})


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer.start()


func _item_list(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in items:
		parts.append(DataRegistry.text("hud_inventory_item",
			{"name": DataRegistry.item_name(item_id), "count": items[item_id]}))
	return ", ".join(parts)


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
	var day: int = summary.get("day", GameState.day)
	var totals: Dictionary = summary.get("totals", {})
	var lines: Array[String] = []
	if totals.is_empty():
		lines.append(DataRegistry.text("msg_settled_none", {"day": day}))
	else:
		lines.append(DataRegistry.text("msg_settled", {"day": day, "summary": _item_list(totals)}))
	for yokai_id: String in summary.get("noise_hits", {}):
		lines.append(DataRegistry.text("msg_noise_hit", {"name": DataRegistry.yokai_name(yokai_id)}))
	lines.append_array(_rent_lines(summary.get("rent", {})))
	show_message("\n".join(lines))
	refresh()


func _rent_lines(rent: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var parts: Array[String] = []
	var money: int = rent.get("money", 0)
	if money > 0:
		parts.append(DataRegistry.text("msg_rent_money", {"amount": money}))
	for item_id: String in rent.get("items", {}):
		parts.append(DataRegistry.text("msg_rent_item", {"item": DataRegistry.item_name(item_id), "amount": rent["items"][item_id]}))
	var bonus: int = rent.get("condition_bonus", 0)
	if bonus > 0:
		parts.append(DataRegistry.text("msg_rent_buff", {"amount": bonus}))
	if not parts.is_empty():
		lines.append(DataRegistry.text("msg_rent_summary", {"list": ", ".join(parts)}))
	for guest: Dictionary in rent.get("departed", []):
		var species_id := str(guest.get("species_id", ""))
		var species := DataRegistry.get_guest_species(species_id)
		lines.append(DataRegistry.text("msg_guest_checkout", {
			"name": DataRegistry.species_name(species_id),
			"rent": species.rent_note_ko if species != null else DataRegistry.text("msg_rent_none"),
		}))
	for mishap: String in rent.get("mishap_texts", []):
		lines.append(mishap)
	return lines


func _on_intake_decided(visitor: Dictionary, outcome: int) -> void:
	var name := DataRegistry.species_name(str(visitor.get("species_id", "")))
	if str(visitor.get("kind", "")) == "erased":
		name = DataRegistry.yokai_name(str(visitor.get("yokai_id", "")))
	match outcome:
		Intake.Outcome.ACCEPTED:
			show_message(DataRegistry.text("msg_intake_accepted", {"name": name}))
		Intake.Outcome.DECLINED:
			show_message(DataRegistry.text("msg_intake_declined", {"name": name}))
		Intake.Outcome.NO_BED:
			show_message(DataRegistry.text("msg_intake_no_bed"))
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
