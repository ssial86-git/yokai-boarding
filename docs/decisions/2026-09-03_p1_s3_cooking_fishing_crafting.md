# P1-S3 요리·낚시·부적 — 실시간 작업대, 요리 3중 용도, 관대한 낚시, 판매 채널
날짜: 2026-09-03
결정:
- **작업대는 실시간이고 하나에 작업 하나다.** `WorkStation`(core)이 재료를 먼저 소모하고 초 단위로 익힌다. `StationSystem`(노드)이 가마솥(kitchen)·작업장(workshop) 두 작업대를 `_process` 로 흘리되 대화·심사(Clock hold) 중에는 멈춘다. 완성품은 자동으로 창고에 들어간다. 작업 상태는 세이브(`stations`)에 남아 로드 뒤 이어진다.
- **요리 3중 용도** (docs/01 v3 2.1): (1) 손님 만족 — `guest_species.liked_recipe`. 체크아웃하는 손님이 좋아하는 요리가 창고에 있으면 하나 먹고 `guest_dish_bonus_money` 를 더 낸다(DayCycle.settle_rent). (2) 동료 버프 — `recipes.buff_stat/buff_amount`. 주방 메뉴의 '배식'으로 하숙생에게 먹이면 그날 능력치가 오른다(`GameState.buffs`, 하루 시작에 비움, `stat_of()` 로 조회 — S4 자동 전투가 쓴다). (3) 판매 — 대문간 행상(`Market`, base_value × `sell_price_ratio`). 회색 시장은 P2. 씨앗·서사 열쇠는 팔 수 없다.
- **레시피 12(티어 1 여섯·티어 2 여섯)**, 티어는 unlocks feature `recipes_tier<n>` 으로 열린다. chains.csv 에 레시피 12행·어종 6행을 더해 42행, 전부 세 갈래 서로 다름 — 빌드가 강제한다(recipes 테이블이 생기면서 사슬 커버리지 대상에 자동 포함).
- **방 앞 E 는 방 종류로 갈린다.** 주방 → 요리·배식, 작업장 → 부적 제작·도구 벼리기, 대문간 → 팔기, 그 외 → 건설·개조. 작업 메뉴 안의 '개조' 줄이 건설 메뉴로 넘긴다. 메뉴는 `ListMenu` 뼈대(배경·제목·행·닫기·ESC) 위에 행만 채운다.
- **낚시는 타이밍 바다.** `Fishing`(core): 마커가 사인 왕복(0~1), 성공 구간 폭 `fishing_window_ratio=0.35`(관대), 구간 중심은 캐스트마다 무작위. 어종은 구역·시간대·낚싯대 레벨로 거른 뒤 가중 추첨(fish.csv 4어종 + 고물 2). 놓쳐도 `fishing_miss_junk_chance` 로 고물이 걸린다. 제한 시간(`fishing_max_seconds`)을 넘기면 놓친다. 낚시 중에는 이동만 잠그고 E 는 판정으로 듣는다. 낚시 자리는 `regions.fishing_x` 로 조립한다(개울 300).
- **부적 제작·도구 벼리기**는 작업장 메뉴다. 부적은 `talismans.craft_cost/craft_seconds` 로 작업대에서, 도구는 `tools.upgrade_cost` 로 즉시. 둘 다 unlocks(type talisman/tool)로 목록이 열린다. 부적 사용(투척·채집·귀환)은 S4.
- **실시간 통합 테스트**(4항): 시계를 1초씩 흘려 저녁 정산·빈 노크·튜토리얼, 밤 튜토리얼→사연, 대화 중 시계 정지, 만료 시 강제 취침을 `test_realtime_flow.gd` 가 검사한다.

이유:
- 원칙 3(세 갈래)을 요리에서 처음 실제로 닫았다 — 손님·동료·돈 세 시스템이 같은 아이템을 쓴다.
- 손맛 튜닝 대상이 아닌 낚시(docs/01 v3)는 판정을 넓게 잡고 수치를 tuning 에 뒀다.

대안과 기각 사유:
- 배식을 요괴 앞 '말 걸기'에 합치기: 선택 UI 가 필요해 대화창과 충돌. 주방 메뉴 한 곳이 단순하다.
- 요리 자동 산출(주방 `meal`)에 효율 계수 적용: 플레이어 요리는 레시피(요리), 요괴 자동 산출은 밥 — 아이템이 달라 직접 비교가 서지 않는다. 계수는 텃밭에만 두고 S4 시뮬레이터에서 재검토.
- 낚시를 별도 씬으로: 바 하나면 충분하고 HUD 에 그리는 편이 데이터 조립 원칙에 맞다.

미해결·사용자 결정 필요:
- 조리 시간(15~60초)·판매가·손님 보너스 20 은 초안. 낚시 구간 폭 0.35·왕복 속도 0.8 은 관대함의 기준값이며 플레이 후 조정.
- 작업장을 지어야 부적을 만들 수 있다(건설 150). 케이던스상 5일차에 부적이 열리므로 그 전에 작업장을 짓게 유도하는 안내 문구가 없다 — S4 에서 unlocks hint 로 보강.

영향받는 파일/문서: src/core/{work_station,fishing,market}.gd, src/systems/{station_system,fishing_system,day_cycle,unlock_system}.gd, src/ui/{list_menu,station_menu,fishing_bar,hud_text}.gd, src/world/{house_region,region_view,region_manager}.gd, src/player/player_controller.gd, src/autoload/{game_state,events,data_registry}.gd, src/core/resources/{recipe_data,guest_species_data,region_data}.gd, src/main.gd, data/csv/{recipes,fish,items,chains,guest_species,regions,tuning,strings_ko,metrics_events}.csv, tools/data/build_resources.py, test/unit/test_{work_station,fishing,market}.gd, test/integration/{test_station_fishing,test_realtime_flow}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
