# P1-S1 기반 전환 — 실시간 하루, P1 스키마 10종, 세이브 v5, Metrics 내장
날짜: 2026-09-03
결정:
- **Clock 은 실시간 하루다.** `DayTimeline`(core, RefCounted)이 경과 실초를 게임 시각(06:00~24:00)으로 펴고 시간대(아침/낮/저녁/밤)를 계산한다. 시간대는 `Events.timeband_changed` 로 알리는 **트리거일 뿐**이며 하루를 끝내는 강제 컷은 취침(`Clock.sleep`)뿐이다 — 시계가 다 흐르면 강제 취침(`forced=true`). 대화·심사가 열려 있는 동안은 `hold/release` 로 시간을 멈춘다. 수치는 전부 tuning(`day_length_seconds=720`, `clock_start/end_hour`, `timeband_*_hour`, `sleep_earliest_hour`).
- 기존 페이즈 의존 코드는 시간대 트리거로 이식했다: 저녁 진입 → 정산 → 심사(체인 유지), 밤 진입 → 사연, 낮 진입 → 요괴 출근, 아침에만 배치. events.csv·hints.csv 의 컬럼은 `phase` → `timeband` 로 이름을 바꿨다(코드·데이터 용어 통일). HUD 의 "낮 시작/건너뛰기" 버튼은 "취침" 버튼으로 바뀌었다.
- **P1 신설 스키마 10종**(materials, crops, fish, talismans, tools, regions, enemies, unlocks, chains, metrics_events)을 확정했다. 목록 컬럼은 세미콜론 구분, 비용은 `item:n`. materials·fish·talismans 의 id 는 items.csv 에도 있어야 한다(인벤토리 공용). 초안 행(부적 3·도구 8·지역 6·적 3)의 수치는 자리표시이며 S2~S4 에서 확정한다. materials/crops/fish 는 헤더만이다.
- **chains.csv 는 재미 원칙 3 의 기계 강제다.** 용도 3칸이 비거나(3칸 미달), 세 용도의 갈래(kind)가 같거나, 대상 콘텐츠(재료·작물·부적·요리)에 사슬 행이 없으면 build_resources.py 가 빌드를 실패시킨다. recipes 테이블이 생기면 자동으로 대상에 든다.
- **unlocks.csv 는 재미 원칙 6 의 데이터다.** docs/01 v3 4절 표를 36행으로 전개했고(`day_min`, `expected_day`, 조건식, 타입별 참조 검증), 1~14일 어느 날도 예정 해금이 비지 않는다. 런타임 해금 엔진과 30분 규칙 시뮬레이터는 S4 몫이다.
- **세이브 v5**: `clock.elapsed_seconds`, `game_state.player{region,x,y}`, `game_state.regions{id: {visited, gather_taken, enemies_defeated, boss_defeated}}`. v4 의 페이즈는 그 시간대의 시작 초로 옮기고(페이즈 안 경과는 길이 체계가 달라 버림) 플레이어·탐험지는 기본값으로 채운다.
- **Metrics autoload 가 PlaytestLog 를 대체한다.** metrics_events.csv 에 정의된 kind·필드만 JSONL(`user://metrics/session_*.jsonl`)로 남기고, 정의 밖이면 push_error. `day_ended.activities`(그날 쓴 동사 종류 수)가 P1 게이트 "하루 4개 이상 활동" 판정 데이터다. headless 에서는 파일을 열지 않되 `open_session()` 으로 강제할 수 있어 스모크 테스트가 실제 JSONL 발생과 정의 일치를 검증한다.

이유:
- docs/08 재미 원칙 2(실시간 하루)·3(사슬)·6(케이던스)을 코드가 아니라 데이터와 빌드 검증으로 지키기 위해. 사람 감이 아니라 빌드 실패로 원칙 위반을 잡는다.
- 스키마를 P1 에서 전부 확정해야 이후 콘텐츠 추가가 CSV 행 추가로 끝난다(docs/01 v3 2.3).
- 시간대 경계 계산은 부동소수 오차가 있어 `HOUR_EPSILON` 으로 경계 초에 서 있으면 그 시간대로 본다 — `advance_to_band` 가 정확히 트리거를 쏘게 하기 위해.

대안과 기각 사유:
- 페이즈 이름 `phase` 를 데이터에 남기고 코드만 바꾸기: 두 용어가 공존해 S2~S4 에서 혼동. 이번 한 번의 치환 비용이 더 싸다.
- 신설 CSV 를 헤더만으로 두기: unlocks 의 타입별 참조 검증이 빈 껍데기가 된다. 참조되는 최소 id 행만 넣었다.
- chains 검증을 경고로 두기: 원칙 3 은 "넣지 않는다"이므로 실패여야 한다.
- 시계를 `_process` 대신 Timer 로: 시간대 경계마다 타이머를 다시 잡아야 하고 세이브 복원이 복잡해진다. 경과 초 하나가 단순하다.

미해결·다음 세션:
- 취침 시 "하루 단축"의 연출·정산 순서, 실시간 12분의 체감(10/12/15 A/B)은 사용자가 플레이 후 tuning 으로 조정한다.
- 런타임 해금 엔진(unlocks 평가·`Metrics.unlock` 기록)과 30분 규칙 시뮬레이터(tools/sim)는 S4.
- 세이브 v5 의 `regions` 값은 JSON 왕복이 값을 바꾸지 않도록 bool·문자열·문자열 목록만 넣는다. 정수 카운트가 필요해지면 정규화 단계를 추가한다.

영향받는 파일/문서: src/core/day_timeline.gd, src/autoload/{clock,events,save_manager,game_state,data_registry,metrics}.gd, src/systems/*, src/ui/hud.gd, src/yokai/*, src/house/house_view.gd, src/core/resources/*_data.gd(10 신설), data/csv/*(10 신설 + events·hints·items·tuning·strings_ko), tools/data/build_resources.py, tools/playtest/summarize.py, test/unit/test_day_timeline.gd, test/integration/{test_smoke,test_save_roundtrip,test_data_build,test_day_cycle,test_seven_day_loop,test_hud_tutorial}.gd, test/tools/*, docs/verification_checklist.md, docs/playtest/{README,observer_sheet}.md
