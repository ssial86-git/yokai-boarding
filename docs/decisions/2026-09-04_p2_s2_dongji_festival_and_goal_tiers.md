# P2-S2 — 동지 명절·목표 층위 3·28일 케이던스
날짜: 2026-09-04
결정:
- **명절은 데이터 한 행이다 (`festivals.csv`).** 절기·날짜, 나누는 요리와 그릇 상한, 손님 상한, 준비 목표(goals.csv id 목록), 항목별 점수, 보상, 만점 보상(추가 평판 + 그날 밤 희귀 손님 종족), 장식 조건 목표. P2 는 동지 하나 — 봄 28일(절기 끝). 채점은 `FestivalRules`(core): 점수 = 충족한 준비 목표 × 2 + min(손님, 2) × 1 + min(나눈 팥죽, 3) × 1 = 최대 11. 만점 = 셋을 다 채운 값(별도 컬럼 없음).
- **명절 당일 흐름**: 아침 `FestivalSystem` 이 `festival_started(id, decorated)` — 팥죽 3그릇 목표가 충족돼 있으면 `HouseView` 가 지붕선에 등(팔레트 색 사각)을 건다. 저녁은 **`rent_settled` 에서 채점**한다: DayCycle.settle 안에서 rent_settled 가 day_settled 보다 먼저 나오므로, 만점 플래그(값 = 종족 id)를 심사 추첨(`IntakeSystem.roll_visitor`, day_settled) 전에 심을 수 있다. 심사는 플래그를 소모해 그 종족(금주리)을 카드로 내민다. 창고의 팥죽은 상한까지 소모("나눴다").
- **목표 층위 3 (`goals.csv`)**: tier today/season/long, 조건식, 날 창(day_min~day_max, 0 = 만료 없음), 명절 소속, 보상. 조건 문법은 unlocks 와 같은 꼴을 확장했다(`GoalRules`): 정량 절 `item/count/rooms/affinity/festival:<대상>>=n`, `ledger/species/floors/beds/money/reputation>=n`, 불리언 절 `resident/unlock/flag:<대상>`. 활동은 **`Events.activity_done(verb, detail, amount)`** 하나로 모아 `GameState.counters` 에 `verb` 와 `verb.detail` 두 키로 누적한다(텃밭 `farm.till`·`farm.harvest.c_moon_melon`, 요리 `cook.r_patjuk`, 채집·낚시·판매·배식·제작·전투·벼리기). "오늘" 층위는 날 창이 있는 부탁(1~28일에 14개), "이번 절기" 는 명절 준비 3 + 텃밭 12칸 + 2층, "장기" 는 정착(호감도 3)·명부 4종·동지 만점.
- **UI**: 장부 메뉴 **'할 일' 탭 [H]** — 오늘/이번 절기(★ 동지 — 봄 28일 · 준비 n/3 헤더 포함)/장기 소제목 아래 "□/✓ 이름 (현재/목표)   보상". HUD 칩 줄 맨 왼쪽에 **"할 일 n/m"**(오늘·절기 층위 중 창 안의 목표). 달력 탭은 명절 날에 ★, 다가오는 목록에 "28일 — 동지 (명절 ★)". 지표 `goals_opened`·`goal_completed`·`festival_started`·`festival_scored` (P2 게이트 "명절을 스스로 준비함" 의 계측).
- **세이브 v7**: `counters` / `goals_done`(goal_id → 완료 날) / `festival_results`. v6 마이그레이션은 빈 Dictionary.
- **28일 케이던스**: unlocks.csv 에 15~28일을 채웠다 — 티어 3 레시피(15, 동지 팥죽·팥밥), 장식(17), 장기 목표(18), 만월(20), 잉어(22, 낚싯대 Lv2), 팥밥 개별 레시피 해금(24), 동지 전날(26), 동지(28) + 장마(10)·할 일(1). 이를 위해 unlock_type 에 `season_event`/`festival`/`recipe` 를 더했고(참조 검증 포함), `StationSystem.is_recipe_unlocked` 가 티어 + 개별 해금을, `FishingSystem` 이 어종 해금을 존중한다. 시뮬레이터 기본 일수 14→28, 케이던스 최대 공백 24분(목표 30 이하)·위임 교차 8일 유지.
- **콘텐츠**: 재료 팥(뒷산, 봄), 요리 동지 팥죽(티어 3, 팥 2·밥 1, 담력 +2)·팥밥, 물고기 잉어(저녁 개울, Lv2). 전부 chains 3칸 통과.

이유:
- 재미 원칙 6 과 P2 게이트("달력을 보고 명절을 준비한다")는 "준비할 것이 눈에 보이는 목표" 없이는 측정도 유도도 되지 않는다. 목표를 조건식 데이터로 두면 P3 의 명절 3개·챕터 목표가 CSV 행으로 끝난다.
- 활동을 시그널 하나로 모은 것은 Metrics 가 이미 같은 지점을 찍고 있어 카운터가 지표와 어긋나지 않게 하려는 것. 카운터를 세이브에 넣어 로드 후 목표 진행이 이어진다.
- rent_settled 채점은 시그널 순서에 의존하지만 DayCycle.settle 한 함수 안의 순서라 안정적이며, 별도 "명절 저녁" 시간대를 만들 필요가 없었다.

대안과 기각 사유:
- 오늘 목표를 매일 무작위 추첨: 시드·세이브·표시가 복잡해지고 "며칠 걸리는 부탁" 을 표현할 수 없다. 날 창으로 대체.
- 명절 장식 아이템(제작품): 제작은 부적만 지원하고 chains 대상도 아니어서 스키마 확장 비용이 크다. "팥죽 3그릇이 갖춰지면 장식" 으로 준비 목표와 장식을 묶었다.
- 명절 채점을 day_settled 에서: 심사 추첨과 순서 경쟁이 생긴다(둘 다 day_settled). rent_settled 로 앞당김.

미해결·사용자 결정 필요:
- 목표 창·보상·명절 점수 배분은 초안. 오늘 목표 14개 중 "마계 작물 수확"(달무리 참외 씨앗은 손님 하숙비로만 들어옴)은 씨앗 공급이 드물어 미달할 수 있다 — 회색 시장(P2-S3)에서 씨앗 판매로 보강 예정.
- 만점 희귀 손님은 빈 침대가 있어야 받을 수 있다(없으면 카드만 뜨고 거절 처리). 명절 전날 안내(26일)에 침대 언급을 추가할지.
- 장식은 지붕선 위 주황 사각 자리표시 — docs/02 아트 트랙.

영향받는 파일/문서: data/csv/{festivals,goals}.csv(신설), {items,materials,regions,recipes,fish,chains,unlocks,metrics_events,strings_ko}.csv, tools/data/build_resources.py, tools/sim/autoplay.py, src/core/{goal_rules,festival_rules}.gd(신설), src/core/resources/{goal_data,festival_data}.gd(신설), src/systems/{goal_system,festival_system}.gd(신설), src/systems/{station_system,fishing_system,expedition_system,intake_system,unlock_system}.gd, src/world/{farm_system,gather_system}.gd, src/house/house_view.gd, src/autoload/{game_state,save_manager,events,data_registry}.gd, src/ui/{hud,menu_hub}.gd, src/main.gd, test/unit/test_goal_rules.gd, test/integration/{test_festival_flow,test_save_roundtrip,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
