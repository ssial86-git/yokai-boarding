class_name ListMenu
extends Control
## 코드 조립 목록 메뉴의 공통 뼈대: 배경(클릭 닫기) + 패널 + 제목 + 행 목록(문구 + 버튼) + 닫기. ESC 로 닫힌다.
## 요리·제작·판매 메뉴가 이 위에 행만 채운다.

const PANEL_WIDTH_RATIO := 0.7
## 상단 시계 카드(두 줄 + 진행 바, 약 68px = 19%) 아래에서 시작해 HUD 를 덮지 않는다 (검증 에이전트가 잡은 10px 겹침 → 0.20)
const PANEL_TOP_RATIO := 0.20
## 행 목록(스크롤)의 높이는 _fit_rows() 가 "화면 아래 여백까지 남는 공간" 으로 맞춘다 — 탭 줄처럼 자식이 늘어도 닫기가 화면 밖으로 밀리지 않도록
const BOTTOM_MARGIN_PX := 4.0
const MIN_ROWS_HEIGHT_PX := 60.0

var _backdrop: Control
var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer


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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, MIN_ROWS_HEIGHT_PX)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	var close_button := Button.new()
	close_button.text = DataRegistry.text("ui_close")
	close_button.pressed.connect(close)
	column.add_child(close_button)

	_panel.custom_minimum_size = Vector2(view_size.x * PANEL_WIDTH_RATIO, 0)
	_panel.position = Vector2(view_size.x * (1.0 - PANEL_WIDTH_RATIO) * 0.5, view_size.y * PANEL_TOP_RATIO).round()
	_fit_rows()


func is_open() -> bool:
	return visible


func open_with_title(title: String) -> void:
	_title.text = title
	visible = true
	_fit_rows()


## 패널 아래가 화면(아래 여백 포함)을 넘지 않도록 행 목록 높이를 남는 공간에 맞춘다.
## 제목·탭·닫기 등 고정 부분(chrome)은 패널 최소 높이에서 행 목록 최소 높이를 빼 잰다 (검증 에이전트가 잡은 닫기 잘림).
func _fit_rows() -> void:
	var view_size := get_viewport_rect().size
	var chrome := _panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var available := view_size.y * (1.0 - PANEL_TOP_RATIO) - BOTTOM_MARGIN_PX - chrome
	_scroll.custom_minimum_size.y = maxf(floorf(available), MIN_ROWS_HEIGHT_PX)


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


## 행 목록에 임의의 컨트롤(격자 등)을 한 줄로 넣는다.
func add_control(control: Control) -> void:
	_rows.add_child(control)


func row_count() -> int:
	return _rows.get_child_count()


## 패널의 화면 사각형 (검증용 — HUD 시계 카드와 겹치지 않는지).
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


## 행 전부가 스크롤 없이 보이는가 (검증용 — 달력 탭의 행사 목록이 잘리지 않는지).
func rows_fit() -> bool:
	return _rows.get_combined_minimum_size().y <= _scroll.size.y + 0.5


## ESC(ui_cancel) 는 모든 메뉴에서 닫기다.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
