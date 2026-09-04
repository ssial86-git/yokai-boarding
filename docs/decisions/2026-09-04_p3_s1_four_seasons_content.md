# P3-S1 — 4절기 순환 콘텐츠와 여름·가을 명절
날짜: 2026-09-04
결정:
- **절기는 데이터 행으로만 늘어난다.** 여름·가을·겨울 날씨 6행(폭염·소나기·갈바람·서리·눈·눈보라, weather.csv), 남은 소절기 6개(유성우·삼복·태풍·단풍 절정·첫눈·눈보라, season_events.csv — 총 8), 명절 2(단오 여름 5일 수리취떡·백중 가을 15일 밤밥, festivals.csv — 총 3) + 준비 목표 6·오늘 목표 6. 코드 변경은 필터 두 곳뿐.
- **materials.season / fish.season 을 실제로 연결했다**: `GatherPoints.roll(..., season_id)` 와 `Fishing.candidates(..., season_id)` 가 절기 재료·어종을 그 절기에만 뽑는다(음기 조건과 같은 규칙, 풀이 다 빠지면 조건 무시). 절기 재료 4(산딸기 여름·밤·송이 가을·얼음조각 겨울)를 뒷산 풀에, 절기 작물 3(오이·호박 여름, 메밀 가을)을 회색 시장 씨앗으로, 절기 어종 2(뱀장어 여름 밤·빙어 겨울 낮)를 개울에. 전부 chains 3칸.
- **도구 Lv3** 4행(tools.csv, 잿불돌·철광석 비용) — StationSystem 벼리기가 데이터로 처리.
- **unlocks 를 56일까지 30분 규칙으로 채우고** 가을·겨울은 뼈대 14행(절기 시작·작물·재료·소절기·명절·도구·연말). 시뮬레이터 기본 일수 28→56, 케이던스 검사 통과. 가을·겨울 조밀화는 P3-S2·S3.
- 112일 자동 진행 통합 테스트: 봄→여름→가을→겨울→봄, 매일 날씨가 절기 표 안, 소절기 8·명절 3이 제 날에 시작.
- **동지는 P2 결정대로 봄 28일에 남겨 둔다.** 겨울로 옮기면 P2 게이트(28일 안 명절)와 목표·해금 창이 흔들린다 — 사용자 결정 항목.

이유:
- P2 에서 스키마를 전부 열어 두었기 때문에(절기 4행, 날씨 season, 이벤트·명절 절기 컬럼) P3 의 "절기당 신작물 3+" 은 CSV 행 추가로 끝난다(CLAUDE.md 5.1 상시 검증). 유일하게 코드가 필요했던 곳(절기 필터 미연결)은 설계 결함으로 보고 이번에 닫았다.

대안과 기각 사유:
- 절기별 지역 풀 컬럼(spring_pool…): 재료 행의 season 컬럼이 이미 있어 중복. 필터로 해결.
- 겨울 이승 작물 금지 규칙 추가: 이미 제철(Farm.in_season) 판정이 있어 겨울에 심을 이승 씨앗이 없으면 자연히 마계 작물만 남는다.

미해결·사용자 결정 필요:
- 동지의 절기 위치(봄 28일 유지 vs 겨울 28일 + 정월대보름 봄 15일).
- 새 날씨 가중치·음기 범위, 절기 재료 가격, 도구 Lv3 비용은 초안.
- 절기 재료가 늘어 뒷산 풀이 11→15 로 커졌다. 절기 필터 뒤 실제 풀은 절기당 12 안팎.

영향받는 파일/문서: data/csv/{weather,season_events,festivals,goals,items,crops,materials,regions,recipes,fish,chains,market_prices,tools,unlocks,strings_ko}.csv, tools/data/build_resources.py(fish.season), tools/sim/autoplay.py(56일), src/core/{gather_points,fishing}.gd, src/core/resources/fish_data.gd, src/world/gather_system.gd, src/systems/fishing_system.gd, test/unit/test_season_filters.gd, test/integration/{test_season_flow,test_data_build}.gd, docs/04_first_session_prompt.md(P3 프롬프트)
