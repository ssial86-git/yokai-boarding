class_name RosterPanel
extends Control
## 하숙부 (docs/06 0절 — 사연 기록 = 말소 보호): 하숙생마다 이름·종족·호감도·사연 진행(본 막 수)을 보여준다.

const PANEL_WIDTH_RATIO := 0.6

var _backdrop: Control
var _panel: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close())
	add_child(_backdrop)

	_panel = PanelContainer.new()
	UiStyles.apply_panel(_panel)
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var title := Label.new()
	title.text = DataRegistry.text("ui_roster_title")
	column.add_child(title)
	_rows = VBoxContainer.new()
	column.add_child(_rows)
	var close_button := Button.new()
	close_button.text = DataRegistry.text("ui_close")
	close_button.pressed.connect(close)
	column.add_child(close_button)

	var view_size := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(view_size.x * PANEL_WIDTH_RATIO, 0)
	_panel.position = Vector2(view_size.x * (1.0 - PANEL_WIDTH_RATIO) * 0.5, view_size.y * 0.2).round()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if GameState.residents.is_empty():
		_add_row(DataRegistry.text("ui_roster_empty"))
	for yokai_id in GameState.residents:
		var yokai := DataRegistry.get_yokai(yokai_id)
		if yokai == null:
			continue
		var story_ids := DataRegistry.story_event_ids(yokai_id)
		var seen := 0
		for event_id in story_ids:
			if GameState.seen_events.has(event_id):
				seen += 1
		_add_row(DataRegistry.text("ui_roster_row", {
			"name": yokai.name_ko,
			"species": yokai.species_ko,
			"affinity": int(GameState.affinity.get(yokai_id, 0)),
			"seen": seen,
			"total": story_ids.size(),
		}))
	visible = true


func close() -> void:
	visible = false


## ESC(ui_cancel) 는 모든 메뉴에서 닫기다.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _add_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	_rows.add_child(label)
