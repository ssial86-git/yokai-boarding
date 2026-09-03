class_name UiStyles
extends RefCounted
## 코드 조립 UI 의 공통 스타일 (UI 정리 2026-09-04). 한 곳에서 색·여백·글자 크기를 정해 모든 패널·버튼·칩이 같은 결로 보이게 한다.
## 색·투명도·여백·글자 크기는 tuning.csv 에서 읽는다 (.tres 테마를 손으로 만들지 않기 위해 — CLAUDE.md 5.2).
## 배경은 불투명(기본 alpha 1.0) — 반투명 패널 뒤로 글자가 비치던 문제를 없앤다.

const CORNER_RADIUS := 3


static func _tuning() -> TuningData:
	return DataRegistry.tuning


static func color(key: String, fallback: String) -> Color:
	return Color.html(_tuning().get_string(key, fallback))


static func font_size() -> int:
	return _tuning().get_int("ui_font_size", 13)


static func header_font_size() -> int:
	return _tuning().get_int("ui_header_font_size", 15)


static func padding() -> float:
	return float(_tuning().get_int("ui_panel_padding_px", 6))


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background := color("ui_panel_color", "2e2733")
	background.a = _tuning().get_float("ui_panel_alpha", 1.0)
	style.bg_color = background
	style.border_color = color("ui_panel_border_color", "7a7180")
	style.set_border_width_all(1)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(padding())
	return style


## 칩: 상태 하나(돈·평판·침대)를 담는 작은 상자. 패널보다 어둡고 테두리 없음.
static func chip() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color("ui_chip_color", "1a1620")
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(padding() * 0.6)
	style.content_margin_left = padding()
	style.content_margin_right = padding()
	return style


static func button(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = color("ui_button_hover_color", "5f8090")
		"pressed":
			style.bg_color = color("ui_accent_color", "f2a65a")
		"disabled":
			style.bg_color = color("ui_button_disabled_color", "4a4352")
		_:
			style.bg_color = color("ui_button_color", "3f5c73")
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(padding() * 0.6)
	style.content_margin_left = padding() * 1.4
	style.content_margin_right = padding() * 1.4
	return style


## UI 루트(CanvasLayer 아래 Control)에 한 번 걸면 모든 Button·Label·PanelContainer 가 같은 결이 된다.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = font_size()
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("normal", "Button", button("normal"))
	theme.set_stylebox("hover", "Button", button("hover"))
	theme.set_stylebox("pressed", "Button", button("pressed"))
	theme.set_stylebox("disabled", "Button", button("disabled"))
	theme.set_stylebox("focus", "Button", button("hover"))
	theme.set_color("font_color", "Button", color("ui_text_color", "ede6dc"))
	theme.set_color("font_disabled_color", "Button", color("ui_text_dim_color", "7a7180"))
	theme.set_color("font_pressed_color", "Button", color("ui_chip_color", "1a1620"))
	theme.set_color("font_color", "Label", color("ui_text_color", "ede6dc"))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = color("ui_chip_color", "1a1620")
	bar_bg.set_corner_radius_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = color("ui_accent_color", "f2a65a")
	bar_fill.set_corner_radius_all(2)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme


static func apply_panel(container: PanelContainer) -> void:
	container.add_theme_stylebox_override("panel", panel())


static func apply_chip(container: PanelContainer) -> void:
	container.add_theme_stylebox_override("panel", chip())


## 제목 라벨: 조금 큰 글자, 강조색.
static func header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", header_font_size())
	label.add_theme_color_override("font_color", color("ui_accent_color", "f2a65a"))
	return label


## 흐린 보조 글자 (단축키 힌트 등).
static func dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color("ui_text_dim_color", "7a7180"))
	return label


## 텍스트 칩 하나. label 을 돌려받아 나중에 text 만 바꾼다.
static func text_chip(parent: Control, text: String) -> Label:
	var box := PanelContainer.new()
	apply_chip(box)
	var label := Label.new()
	label.text = text
	box.add_child(label)
	parent.add_child(box)
	return label


## "취침 [Z]" 처럼 단축키를 붙인 버튼.
static func key_button(parent: Control, text: String, key_hint: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = "%s  %s" % [text, key_hint] if not key_hint.is_empty() else text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
