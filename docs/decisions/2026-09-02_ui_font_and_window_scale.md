# UI 픽셀 폰트와 창 배율
날짜: 2026-09-02
결정:
- UI 기본 폰트는 **Galmuri11**(OFL 1.1, `assets/fonts/`). `project.godot` 의 `gui/theme/custom_font` 로 등록하고 안티앨리어싱·힌팅·서브픽셀 위치 지정을 끈다 (프로젝트 설정과 폰트 `.import` 양쪽).
- 폰트 **크기는 코드 조립 Theme**(`UiTheme.build()`, `tuning.ui_font_size=11`)으로 고정해 UI 루트 Control 에 넣는다. Godot 에는 `gui/theme/default_font_size` 프로젝트 설정이 **없으며**(기본 테마 크기 16 고정), 손으로 만든 Theme `.tres` 는 CLAUDE.md 5.2 에 따라 피한다.
- 창 크기는 시작 시 `Main._apply_window_scale()` 이 뷰포트(640×360)의 정수 배로 맞춘다. `tuning.window_integer_scale` 이 0 이면 화면 사용 가능 영역의 `window_auto_scale_fill`(0.8) 안에 드는 최대 배율(4K 150% 환경에서 4배 = 2560×1440). headless 에서는 건너뛴다.

이유:
- 번짐의 1차 원인은 시스템 폴백 폰트(안티앨리어싱)를 정수 배율로 확대한 것. 2차 원인은 11px 설계 폰트가 기본 크기 16px 로 찍혀 획 폭이 1~2px 로 들쭉날쭉해진 것 — 실제 창 캡처의 획 폭 분포(전부 2의 배수)와 `ThemeDB.fallback_font_size=16` 진단으로 확인.
- 고해상도 모니터에서 1280×720 창은 너무 작아 11px 폰트가 읽기 어렵다. 배율을 정수로만 올려 픽셀 스냅을 유지한다.

대안과 기각 사유:
- `Viewport.oversampling_override=1.0`: 화면 픽셀 비교 결과 변화 없음(뷰포트 스트레치 모드에서는 이미 1배). 기각.
- 폰트 크기를 22(2배)로 올리기: 뷰포트 내부 해상도가 640×360 이라 글자가 화면의 1/8 을 차지. 기각. 더 큰 글자가 필요하면 Galmuri14 를 별도 폰트로 추가한다.
- `canvas_items` 스트레치 모드로 UI 만 고해상도 렌더: 픽셀 스프라이트와 UI 의 픽셀 격자가 어긋나 톤이 깨짐. 기각.

영향받는 파일/문서: project.godot([gui]), assets/fonts/*, src/ui/ui_theme.gd, src/main.gd, data/csv/tuning.csv(ui_font_size, window_integer_scale, window_auto_scale_fill), test/tools/diag_viewport.gd, docs/asset_licenses.md
