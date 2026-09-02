# UI 픽셀 폰트와 창 배율
날짜: 2026-09-02
상태: **픽셀 폰트 부분은 같은 날 철회.** 사용자가 실제 플레이 화면에서 시스템 기본 폰트(16px, 안티앨리어싱, 2배 창)를 더 선호해 Galmuri11 파일·`[gui]` 설정·`UiTheme` 을 제거했다. 창 배율 자동화 코드는 남기되 기본값을 `window_integer_scale=2`(처음과 같은 1280×720)로 되돌렸다. 아래 기록은 재시도 시 참고용 — 픽셀 한글 폰트를 다시 도입한다면 (1) 설계 크기 확인(Galmuri11=12px) (2) 실제 창 캡처로 검증 (3) 사용자 선호 확인 순으로 진행한다.

결정(철회 전):
- UI 기본 폰트는 **Galmuri11**(OFL 1.1, `assets/fonts/`). `project.godot` 의 `gui/theme/custom_font` 로 등록하고 안티앨리어싱·힌팅·서브픽셀 위치 지정을 끈다 (프로젝트 설정과 폰트 `.import` 양쪽).
- 폰트 **크기는 코드 조립 Theme**(`UiTheme.build()`, `tuning.ui_font_size=12`)으로 고정해 UI 루트 Control 에 넣는다. Godot 에는 `gui/theme/default_font_size` 프로젝트 설정이 **없으며**(기본 테마 크기 16 고정), 손으로 만든 Theme `.tres` 는 CLAUDE.md 5.2 에 따라 피한다.
- **Galmuri11 의 설계 크기는 12px** 이다. 이름의 11 은 글리프 높이(px)이고 em 에는 여백 1px 이 포함된다. 11px 로 찍으면 FreeType 마스크 높이가 10 이 되어 받침 글자의 행 하나가 사라진다(눌린 모양). 12px 에서 마스크 높이 11, 모든 획이 1px 로 정렬됨을 Pillow 래스터와 실제 창 캡처로 확인했다.
- 창 크기는 시작 시 `Main._apply_window_scale()` 이 뷰포트(640×360)의 정수 배로 맞춘다. `tuning.window_integer_scale` 이 0 이면 화면 사용 가능 영역의 `window_auto_scale_fill`(0.8) 안에 드는 최대 배율(4K 150% 환경에서 4배 = 2560×1440). headless 에서는 건너뛴다.

이유:
- 번짐의 1차 원인은 시스템 폴백 폰트(안티앨리어싱)를 정수 배율로 확대한 것. 2차 원인은 픽셀 폰트가 기본 크기 16px 로 찍혀 획 폭이 1~2px 로 들쭉날쭉해진 것 — 실제 창 캡처의 획 폭 분포(전부 2의 배수)와 `ThemeDB.fallback_font_size=16` 진단으로 확인. 3차 원인은 크기를 11 로 잘못 잡아 받침 글자가 눌린 것.
- 고해상도 모니터에서 1280×720 창은 너무 작아 11px 폰트가 읽기 어렵다. 배율을 정수로만 올려 픽셀 스냅을 유지한다.

대안과 기각 사유:
- `Viewport.oversampling_override=1.0`: 화면 픽셀 비교 결과 변화 없음(뷰포트 스트레치 모드에서는 이미 1배). 기각.
- 폰트 크기를 22(2배)로 올리기: 뷰포트 내부 해상도가 640×360 이라 글자가 화면의 1/8 을 차지. 기각. 더 큰 글자가 필요하면 Galmuri14 를 별도 폰트로 추가한다.
- `canvas_items` 스트레치 모드로 UI 만 고해상도 렌더: 픽셀 스프라이트와 UI 의 픽셀 격자가 어긋나 톤이 깨짐. 기각.

영향받는 파일/문서: project.godot([gui]), assets/fonts/*, src/ui/ui_theme.gd, src/main.gd, data/csv/tuning.csv(ui_font_size, window_integer_scale, window_auto_scale_fill), test/tools/diag_viewport.gd, docs/asset_licenses.md
