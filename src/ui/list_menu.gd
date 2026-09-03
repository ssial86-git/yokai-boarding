class_name ListMenu
extends Control
## 코드 조립 목록 메뉴의 공통 뼈대: 배경(클릭 닫기) + 패널 + 제목 + 행 목록(문구 + 버튼) + 닫기. ESC 로 닫힌다.
## 요리·제작·판매 메뉴가 이 위에 행만 채운다.

const PANEL_WIDTH_RATIO := 0.7
## 상단 시계 카드·칩 줄(약 15%) 아래에서 시작해 HUD 를 덮지 않는다
const PANEL_TOP_RATIO := 0.16
## 행 목록(스크롤)의 높이 — 뷰포트 높이 대비
const ROWS_HEIGHT_RATIO := 0.5

var _backdrop: Control
var _panel: PanelContainer
var _title: Label
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
	_title = UiStyles.header("")  # 배치 패널 제목과 같은 주황 강조
	column.add_child(_title)
	# 행이 많아도(레시피 12줄) 닫기 버튼이 화면 밖으로 밀리지 않도록 목록만 스크롤한다
	var view_size := get_viewport_rect().size
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, view_size.y * ROWS_HEIGHT_RATIO)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var close_button := Button.new()
	close_button.text = DataRegistry.text("ui_close")
	close_button.pressed.connect(close)
	column.add_child(close_button)

	_panel.custom_minimum_size = Vector2(view_size.x * PANEL_WIDTH_RATIO, 0)
	_panel.position = Vector2(view_size.x * (1.0 - PANEL_WIDTH_RATIO) * 0.5, view_size.y * PANEL_TOP_RATIO).round()


func is_open() -> bool:
	return visible


func open_with_title(title: String) -> void:
	_title.text = title
	visible = true


func close() -> void:
	visible = false


func clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	_rows.add_child(label)


## 문구 + 버튼 한 줄. button_text 가 비면 문구만.
func add_row(text: String, button_text: String = "", on_pressed: Callable = Callable(), enabled: bool = true) -> Button:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var button: Button = null
	if not button_text.is_empty():
		button = Button.new()
		button.text = button_text
		button.disabled = not enabled
		if on_pressed.is_valid():
			button.pressed.connect(on_pressed)
		row.add_child(button)
	_rows.add_child(row)
	return button


func row_count() -> int:
	return _rows.get_child_count()


## ESC(ui_cancel) 는 모든 메뉴에서 닫기다.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
