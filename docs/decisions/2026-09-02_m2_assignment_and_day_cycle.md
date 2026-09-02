# M2 배치·하루 사이클 모델
날짜: 2026-09-02
결정:
- **배치 모델**: `Assignment`(core)는 요괴 id → 일할 칸(또는 REST). 일터는 `capacity>0` 이고 kind 가 production/service/gate/storage 인 방. lodging 은 휴식처(첫 객실, 없으면 대문간)이며 일터가 아니다. 정원은 `RoomData.capacity`. 페이즈 제한(아침에만 변경)은 `AssignmentController`(Node) 가 검사한다. 방이 바뀌면 `DayCycle` 이 `prune()` 으로 무효 배치를 휴식으로 되돌린다.
- **하루 흐름**: 아침(배치, 수동 진행) → 낮(240초 자동, 요괴가 일터로 걸어가 일함) → 저녁 진입 시 `DaySettlement.settle()` 로 정산 → 밤 → 다음 날. 배치는 다음 날에도 유지된다.
- **산출**: `rooms.csv` 의 `output_item`/`output_amount`(일꾼 1명·하루 기준) × 배율. 배율 = (선호 방이면 1+work_bonus) × (컨디션 < low_condition_threshold 이면 low_condition_multiplier). 반올림은 0.5 올림. 산출은 `items.csv`(8종) 의 id 로 `Inventory` 에 쌓인다.
- **컨디션**: 요괴별 0~condition_max. 일하면 -work_condition_cost, 쉬면 +rest_condition_gain. 휴식처가 quiet 방이고 상하좌우 옆 칸에서 일하는 요괴의 noise 가 있으면 -noise × noise_condition_penalty_per_level. 이것이 M2 의 "아침 배치 퍼즐" 제약이다(뚝딱이 소음 3 vs 옆 객실 휴식자).
- **이동**: `RoomGraph`(core) BFS. 같은 층 옆 칸 연결, `stair_column`(0) 에서만 층 이동. `YokaiActor` 는 칸 경로를 직선으로 걷고 실수 위치를 따로 들고 반올림해 픽셀 스냅한다(프레임당 1px 미만 이동이 누적되도록).
- **드래그 배치 UI**: `YokaiCard`(`_get_drag_data`) → `DropLayer`(월드 위 투명 Control, `_can_drop_data`/`_drop_data`, 마우스는 PASS) 또는 `AssignmentPanel`/카드 위에 놓으면 휴식. 드래그 중 `HouseView` 가 칸마다 배치 가능 여부를 색으로 칠한다.
- **입주**: M3 심사 전까지 새 게임은 `yokai.csv` 의 `in_slice=true` 3명이 처음부터 입주. 침대(객실 정원) 제약은 M3 에서.
- **세이브 v3**: game_state 에 conditions / inventory / assignment 추가. v2 → v3 는 빈 값으로 채우고 `GameState.from_dict` 가 기본값을 넣는다.

이유:
- 규칙(배치·산출·컨디션·경로)을 전부 core 순수 클래스로 두어 단위 테스트 21개로 고정했고, 노드는 시그널 어댑터만 한다 (CLAUDE.md 5.3).
- 컨디션을 도입한 이유: 소음·선호 방만으로는 3명·방 2개에서 배치 고민이 생기지 않는다. 일/휴식 교대가 매일의 결정을 만든다. 수치는 전부 tuning.csv 이며 사람이 플레이 후 조정한다.
- 산출 적용을 저녁 진입 시점 한 번으로 둔 것은 낮 도중 개입(사건)이 M3 이후라 실시간 누적이 아직 필요 없기 때문.

대안과 기각 사유:
- 낮 동안 실시간 산출 누적: 낮 사건 시스템이 없어 이점 없음. M3 에서 사건과 함께 재검토.
- 클릭-클릭(카드 선택 후 방 클릭) 배치: docs/01 이 "드래그로 배정" 을 명시. 드래그로 구현하고 카드 위 드롭=휴식으로 보조.
- 어둑이 `night_worker` 를 밤 산출로 구현: 어둑이의 특성(등불지기)은 결계 시스템(M3/Tier 2) 소관이라 M2 에서는 낮 일꾼과 동일하게 취급. 플래그는 데이터에 유지.

영향받는 파일/문서: src/core/{inventory,room_graph,assignment,day_settlement}.gd, src/core/resources/{item_data,room_data}.gd, src/yokai/*, src/systems/day_cycle.gd, src/ui/{yokai_card,assignment_panel,drop_layer,debug_hud}.gd, src/house/house_view.gd, src/main.gd, src/autoload/{game_state,save_manager,data_registry,events}.gd, data/csv/{items,rooms,tuning,strings_ko}.csv, tools/data/build_resources.py, test/unit/test_{inventory,room_graph,assignment,day_settlement}.gd, test/integration/{test_day_cycle,test_save_roundtrip}.gd
