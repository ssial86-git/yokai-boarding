# M1 방 그리드 모델과 하숙집 뷰 구조
날짜: 2026-09-02
결정:
- **그리드 모델**: `RoomGrid`(core, RefCounted)는 층×칸 문자열 배열이며 `Vector2i(column, floor)`, floor 0 = 1층. 시작은 1층만 지어진 상태이고 위층은 "잠김"(셀 값 `""`)이다. **증축 = 층 추가**(`add_floor`, 비용 `floor_build_cost × growth^(built_floors-1)`), **설치/개조 = `place_room`**(빈터→방, 방→방 모두 목표 방의 `build_cost` 지불), **철거 = `demolish_room`**(`build_cost × demolish_refund_ratio` 환불). `requires_room` 은 "그 방이 집 어딘가에 하나 이상" 조건이며, 다른 방이 필요로 하는 마지막 방은 철거·개조할 수 없다.
- **돈은 그리드 밖**: RoomGrid 는 돈을 인자로 받아 검증(`INSUFFICIENT_FUNDS`)만 하고 차감은 `HouseController`(Node) 가 한다. 결과는 `RoomGrid.Outcome` enum 으로 돌려주고 UI 문자열 키는 `outcome_<enum 소문자>` 로 자동 매핑한다.
- **상태 소유**: `GameState.room_grid` 가 그리드를 소유하고 `to_dict/from_dict` 에 포함된다. 세이브 스키마 **v2**(v1→v2 마이그레이션: room_grid 없으면 시작 배치로 채움). JSON 은 정수를 float 로 돌려주므로 로드 시 int 로 되돌린다.
- **씬 조립**: `.tscn` 은 여전히 `scenes/main.tscn` 하나. `main.gd` 가 HouseController / World(HouseView, Lighting, Camera) / UI(DebugHud, BuildMenu) 를 코드로 조립하고 시그널을 잇는다. 입력(휠 줌·드래그·클릭 판정)은 `HouseCamera` 한곳에서 처리해 노드 순서에 따른 판정 모호성을 없앤다.
- **렌더링 규격**: 방 1칸 = 64×48px (16px 격자 4×3), 월드 좌표는 1층 바닥 y=0 에서 위로 갈수록 음수. 카메라 줌은 정수 배율만(픽셀 스냅 유지). 등불은 `PointLight2D` + 코드 생성 방사형 그라디언트 텍스처, `lantern_phases` 에 든 페이즈에만 켜진다. 페이즈 색조는 `CanvasModulate` 트윈.
- **UI 문자열**: `data/csv/strings_ko.csv` → `strings_ko.tres`(Dictionary). `DataRegistry.text(key, args)` 로만 접근. 코드에 한글 리터럴을 두지 않는다.
- **팔레트·tuning 승인**: 2026-09-02 사용자가 임시 32색 팔레트(`data/palette.hex`)와 tuning 가정값(`start_money=200`, 아침·저녁·밤 페이즈 수동 진행, 낮 240초)을 승인했다. `GODOT_BIN` 영구 등록은 보류(사용자 결정).

이유:
- "층 잠금 + 층 추가" 로 증축을 모델링하면 docs/01 의 완료 판정 "3층 증축" 이 상태 하나(`built_floors`)로 검증되고, 빈터 클릭 → 방 선택 흐름(docs/04 M1)과 자연스럽게 분리된다.
- 돈을 그리드 밖에 두어 RoomGrid 를 노드·autoload 없이 단위 테스트할 수 있다 (CLAUDE.md 5.3).
- 시작 배치를 `tuning.start_layout_floor0` 문자열로 둔 것은 표 하나를 더 만들 만큼의 구조가 아니라서다. 층별·조건부 시작 배치가 필요해지면 `house_start.csv` 로 승격한다.
- 디버그 HUD(페이즈 진행·저장·불러오기·돈 추가)는 경제가 없는 M1 에서 3층 증축을 손으로 검증하기 위한 임시물이다. M4 정식 HUD 에서 제거한다.

대안과 기각 사유:
- 빈터가 아닌 "없는 칸" 을 자유 건설하는 모델: docs/01 5절 "슬롯 그리드, 자유 건설 아님" 위배. 기각.
- 개조 비용을 (신규 − 기존 환불) 로 계산: 밸런스 근거가 없어 단순 규칙(신규 비용 전액)으로 시작. M3 경제 시뮬레이터에서 재검토.
- HouseController 대신 GameState 에 조작 메서드 추가: GameState 가 비대해지고 Events 발신 책임이 섞임. 기각.

영향받는 파일/문서: src/core/room_grid.gd, src/core/camera_bounds.gd, src/house/*, src/systems/lighting.gd, src/ui/build_menu.gd, src/ui/debug_hud.gd, src/main.gd, src/autoload/{game_state,save_manager,data_registry,events}.gd, data/csv/{tuning,strings_ko}.csv, tools/data/build_resources.py, test/unit/test_room_grid.gd, test/unit/test_camera_bounds.gd, test/integration/{test_save_roundtrip,test_house_view}.gd
