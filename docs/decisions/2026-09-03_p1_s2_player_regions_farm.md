# P1-S2 플레이어와 집·마당·뒷산 — 직접 조작, 데이터 조립 구역, 텃밭·채집, 자동화 층
날짜: 2026-09-03
결정:
- **플레이어는 CharacterBody2D 직접 조작이다** (`src/player/player_controller.gd`). 좌우 이동, 달리기(스태미너 소모), 경사로(단차), 사다리·계단(Area2D 그룹 `ladder`, 타는 동안 층 바닥 통과), E 상호작용. 점프는 없다 — 정밀 플랫포밍 금지(CLAUDE.md 5.7). 입력 액션은 project.godot 을 손대지 않고 main.gd 가 InputMap 에 코드로 등록한다(A/D·←→, W/S·↑↓, Shift, E/Space).
- **상호작용은 Callable 조립이다.** `Interactable`(Area2D)은 안내 문구·가능 여부·행동을 Callable 로 받고, 문·채집 포인트·텃밭 칸·방·요괴 모두 이 하나로 만든다. 플레이어의 감지 반경 안에서 `interact_priority` 가 큰 것, 같으면 가까운 것을 잡고 `Events.prompt_changed` 로 HUD 에 "E: 캐기" 를 띄운다. (`priority` 는 Area2D 내장 멤버라 이름을 피했다.)
- **구역은 regions.csv 로만 조립한다.** `RegionLayout`(core)이 `ground`(x0:x1:y 구간, 높이 차는 `ramp_width_px` 경사로), `doors`(region:x), `gather_span`, `farm_x` 를 기하로 풀고 `RegionView` 가 바닥 충돌체·벽·문·채집 포인트·텃밭 칸을 만든다. 하숙집은 `HouseRegion` 이 기존 HouseView/YokaiManager 를 감싸 층 바닥(위층은 일방향)·계단 열의 사다리·방 앞 상호작용(짓기/개조 → 기존 BuildMenu)·대문을 방 그리드에서 만든다. `RegionManager` 는 하숙집(상주)과 야외 구역(하나만 존재) 중 하나를 보이고 플레이어를 옮긴다. 카메라는 플레이어를 감쇠 추적하고 드래그 스크롤은 없앴다.
- **텃밭·채집은 순수 로직 + 노드 어댑터.** `Farm`(core): 괭이질→파종(씨앗 소모)→물주기→하루 끝 성장(물 비율 × (1+음기 보너스))→수확, 수확한 칸은 갈아 둔 채. `GatherPoints`(core): 희귀도 가중 추첨(common 3/uncommon 2/rare 1), 도구 갈래·레벨 조건, 포인트 소진·하루 리스폰. 채집 추첨 RNG 는 `시드:날짜:구역` 해시로 파생해 방문자 RNG 를 소모하지 않는다(시드 고정 테스트 보호).
- **자동화 층은 텃밭 슬롯이다.** `Assignment.FIELD`(가상 칸, 정원 `field_workers_max`)에 배치된 요괴는 낮 진입 시 `Farm.water_all(automation_efficiency=0.6)` — 플레이어 물주기 1.0 대비 하루 0.6일 성장. 정산에서 일한 것으로 컨디션을 깎는다. 집 단면에서는 대문간 앞에서 일하는 모습으로 보인다. 주방·작업장 산출(요리)은 이미 요괴 자동이며 플레이어가 요리할 수 있게 되는 S3 에서 같은 계수를 적용한다. '청소'는 대응 시스템이 아직 없어 이번에 넣지 않았다.
- **최소 해금 엔진**(`UnlockSystem` + `UnlockRules` core)을 S2 에 앞당겼다. 뒷산(2일차)·도끼·곡괭이·괭이·텃밭 12칸 확장이 unlocks.csv 로 열려야 "처음 보는 것" 케이던스가 실제로 작동하기 때문이다. 해금 행이 가리키지 않는 구역(마당·우물)은 늘 열려 있다. 30분 규칙 시뮬레이터는 여전히 S4.
- **콘텐츠**: 재료 14(이승 11·마계 3, wood 는 기존 아이템 재사용)·작물 7(이승 5·마계 2, 씨앗·수확물 아이템 14)·사슬 21행(전부 세 갈래 서로 다름). 뒷산 채집 풀 10, 개울 3, 잿빛 들 3(S4 용 자리). 시작 소지품·도구는 tuning(`start_items`, `start_tools`).
- **세이브 v5 확장**: `stamina`, `farm`, `tools`, `unlocked`, `regions[*].gather_materials`. 빠진 키는 기본값(v4 세이브도 그대로 열린다).

이유:
- docs/08 원칙 1(동사 12+)·2(실시간+스태미너)·5(하숙집=자동화 층)를 화면에 올리는 첫 세션이다. 원칙 5 의 "위임의 트레이드오프"를 수치 하나(0.6)로 만들어 시뮬레이터가 교차점을 잡을 수 있게 했다.
- 구역을 데이터로 조립해야 S4 의 잿빛 들과 이후 지역 7+밤 변형이 CSV 행으로 끝난다.

대안과 기각 사유:
- TileMap + 내비메시: 정밀 플랫포밍이 없고 지형이 구간+경사로뿐이라 과하다. CLAUDE.md 5.7 도 내비메시를 금한다.
- project.godot [input] 직접 편집: 직렬화 형식 오류 위험. 코드 등록이 안전하고 기존 설정이 있으면 양보한다.
- 상호작용을 타입별 클래스 상속으로: 문·방·요괴는 데이터만 다르므로 Callable 조립이 짧다. 그림이 필요한 텃밭·채집 포인트만 서브클래스.
- 텃밭 배치를 방(room)으로: 마당은 방 그리드 밖이다. 가상 칸 FIELD 가 기존 Assignment 검증·직렬화(좌표 쌍)를 그대로 쓴다.

미해결·사용자 결정 필요 (손맛은 Claude 가 판단하지 않는다):
- 이동감: `player_walk_speed_px 70 / run 120 / climb 55 / gravity 900`, 스태미너 `run_drain 8/s, regen 4/s, gather 5, farm 4` 는 기본값이다. 직접 플레이 후 조정을 요청한다.
- 야외 구역 폭(마당 480·뒷산 960)과 채집 포인트 8개 간격, 텃밭 칸 폭 16px 은 자리표시 그림 기준이다.
- 어둑이 '흐림'(호감도 또렷함)은 텃밭 배치 카드에서도 그대로 적용된다.

영향받는 파일/문서: src/player/{player_controller,interactable}.gd, src/world/{region_manager,region_view,house_region,farm_plot_node,gather_point_node,farm_system,gather_system}.gd, src/systems/unlock_system.gd, src/core/{stamina,farm,gather_points,region_layout,unlock_rules,assignment,day_settlement}.gd, src/autoload/{game_state,events}.gd, src/house/house_camera.gd, src/yokai/yokai_manager.gd, src/ui/{hud,hud_text,yokai_card,assignment_panel}.gd, src/systems/{story_system,tutorial_system}.gd, src/main.gd, data/csv/{regions,materials,crops,chains,items,tuning,strings_ko,hints,metrics_events,unlocks}.csv, tools/data/build_resources.py, tools/art/gen_placeholder.py, assets/art_generated/player.png, test/unit/test_{stamina,farm,gather_points,region_layout,unlock_rules}.gd, test/integration/{test_player_world,test_hud_tutorial,test_save_roundtrip}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
