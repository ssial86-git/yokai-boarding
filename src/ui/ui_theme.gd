class_name UiTheme
extends RefCounted
## UI 공통 Theme 을 코드로 만든다 (.tres 를 손으로 만들지 않기 위해 — CLAUDE.md 5.2).
## 폰트는 project.godot 의 gui/theme/custom_font(ThemeDB 폴백)를 쓰고, 크기만 tuning 으로 고정한다.
## 픽셀 폰트는 설계 크기가 아닌 크기로 찍으면 획이 깨진다. Galmuri11 은 글리프 높이 11px + 여백 1px 이라
## 설계 크기가 12px 이다 (11 로 찍으면 받침 글자의 행이 하나 빠져 눌린다). 이 크기를 임의로 바꾸지 않는다.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = DataRegistry.tuning.get_int("ui_font_size", ThemeDB.fallback_font_size)
	return theme
