class_name UiStyles
extends RefCounted
## 코드 조립 UI 의 공통 스타일. Godot 기본 패널은 반투명이라 뒤 글자가 비치므로 불투명 상자를 쓴다.
## 색·투명도·여백은 tuning.csv 에서 읽는다 (.tres 테마를 손으로 만들지 않기 위해 — CLAUDE.md 5.2).


static func panel() -> StyleBoxFlat:
	var tuning := DataRegistry.tuning
	var style := StyleBoxFlat.new()
	var color := Color.html(tuning.get_string("ui_panel_color", "2e2733"))
	color.a = tuning.get_float("ui_panel_alpha", 0.96)
	style.bg_color = color
	style.border_color = Color.html(tuning.get_string("ui_panel_border_color", "7a7180"))
	style.set_border_width_all(1)
	style.set_content_margin_all(float(tuning.get_int("ui_panel_padding_px", 6)))
	return style


static func apply_panel(container: PanelContainer) -> void:
	container.add_theme_stylebox_override("panel", panel())
