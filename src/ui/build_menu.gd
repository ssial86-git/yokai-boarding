class_name BuildMenu
extends Control
## 칸 클릭 시 열리는 증축·개조·철거 메뉴. 노드는 전부 코드로 조립한다.
## 배경(backdrop)을 클릭하면 닫힌다. 버튼은 규칙 위반이면 비활성 + 툴팁으로 이유를 보여준다.

const PANEL_MARGIN_PX := 4.0

var controller: HouseController

var _backdrop: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _coords: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	# anchors 와 offsets 를 함께 잡아야 실제로 화면 전체를 덮는다 (set_anchors_preset 만으로는 0x0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	UiStyles.apply_panel(_panel)
	add_child(_panel)
	_box = VBoxContainer.new()
	_panel.add_child(_box)


func is_open() -> bool:
	return visible


func open_for_cell(coords: Vector2i, screen_pos: Vector2) -> void:
	_coords = coords
	_clear()
	var grid := controller.grid()
	if not grid.is_floor_built(coords.y):
		_build_locked_floor(grid, coords.y)
	elif grid.is_empty(coords):
		_build_empty_lot(grid)
	else:
		_build_existing_room(grid)
	_add_button(DataRegistry.text("ui_close"), close)
	visible = true
	_place_panel.call_deferred(screen_pos)


func close() -> void:
	visible = false
	_coords = Vector2i(-1, -1)


## ESC(ui_cancel) 는 모든 메뉴에서 닫기다.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- 내용 구성 ---

func _build_locked_floor(grid: RoomGrid, floor: int) -> void:
	_add_label(DataRegistry.text("ui_build_title_locked", {"floor": floor + 1}))
	if floor != grid.built_floors:
		_add_label(DataRegistry.text("outcome_floor_locked"))
		return
	var cost := grid.get_next_floor_cost()
	var outcome := grid.check_add_floor(GameState.money)
	var button := _add_button(
		DataRegistry.text("ui_add_floor_option", {"floor": floor + 1, "cost": cost}),
		func() -> void:
			controller.try_add_floor()
			close()
	)
	_apply_outcome(button, outcome)


func _build_empty_lot(grid: RoomGrid) -> void:
	_add_label(DataRegistry.text("ui_build_title_empty"))
	_add_room_options(grid)


func _build_existing_room(grid: RoomGrid) -> void:
	var room := grid.get_room(_coords)
	_add_label(room.name_ko)
	_add_label(DataRegistry.text("ui_renovate_header"))
	_add_room_options(grid)
	var refund := grid.get_demolish_refund(_coords)
	var button := _add_button(
		DataRegistry.text("ui_demolish_option", {"refund": refund}),
		func() -> void:
			controller.try_demolish(_coords)
			close()
	)
	_apply_outcome(button, grid.check_demolish(_coords))


func _add_room_options(grid: RoomGrid) -> void:
	var current_id := grid.get_room_id(_coords)
	for room in DataRegistry.rooms_buildable_sorted():
		if room.id == current_id:
			continue
		var outcome := grid.check_place(_coords, room.id, GameState.money)
		var button := _add_button(
			DataRegistry.text("ui_build_option", {"name": room.name_ko, "cost": room.build_cost}),
			func() -> void:
				controller.try_place_room(_coords, room.id)
				close()
		)
		_apply_outcome(button, outcome)


# --- 위젯 ---

func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	_box.add_child(label)
	return label


func _add_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	_box.add_child(button)
	return button


func _apply_outcome(button: Button, outcome: RoomGrid.Outcome) -> void:
	if outcome == RoomGrid.Outcome.OK:
		return
	button.disabled = true
	button.tooltip_text = DataRegistry.text(outcome_text_key(outcome))


static func outcome_text_key(outcome: int) -> String:
	return "outcome_%s" % (RoomGrid.Outcome.keys()[outcome] as String).to_lower()


func _clear() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


func _place_panel(screen_pos: Vector2) -> void:
	_panel.reset_size()
	var view_size := get_viewport_rect().size
	var target := screen_pos + Vector2(PANEL_MARGIN_PX, PANEL_MARGIN_PX)
	target.x = clampf(target.x, 0.0, maxf(0.0, view_size.x - _panel.size.x))
	target.y = clampf(target.y, 0.0, maxf(0.0, view_size.y - _panel.size.y))
	_panel.position = target.round()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()
