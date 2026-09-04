# P2-S4 — 챕터 1 서사·뜨내기 승격·밤 변형 뒷산·P2 게이트 킷
날짜: 2026-09-04
결정:
- **챕터는 게이트 한 행이다 (`chapters.csv`).** 병렬 목표(goals.csv id 목록) 중 `gate_required` 개가 완료되면 다음 챕터로 넘어가며 `flag chapter_<id>` 를 남긴다 (docs/05 7절: 서사를 읽지 않아도 막히지 않게). 챕터 1 「폭군의 장부」 게이트 = 하숙생 셋 / 2층 / 회색 장꾼 인사 / 동지 6점 중 **2개**. 챕터 2 는 P3 자리표시. 진행은 할 일 탭 '장기' 헤더 "챕터 1 「…」 — 게이트 n/4 (필요 2)". 세이브 v9 `chapter`.
- **챕터 서사 8개 이벤트**는 `events.csv` kind **chapter** (사연 story 와 같이 시간대 트리거로 뜨되 우선순위 20 으로 먼저; 로스터 사연 수에는 안 셈) + `requires_flag` 사슬: 상속(3일차 밤) → [장꾼 인사 flag merchant_met] → 회색 시장의 소문(flag rumor_ledger) → 하숙부의 진실(flag ledger_truth) → 회수 집행관의 편지(10일차 저녁, 아이템 통지서·flag collector_letter) → 뚝딱이의 두려움(선택지)·달갤과 장부 → 집행관 3급의 감사(20일차 저녁, 선택지: 수수료 100 / 문전박대) → 결계가 단단해졐다(flag chapter_c2 로 열림). 새 화자 `spirits.csv` collector. **대사는 Claude 초안 — 사람 퇴고 필요** (docs/04 공통 주의).
- **뜨내기 승격**: `guest_species.promotes_to`(→ yokai.csv 행, join_mode intake) 신설. `ChapterRules.promotable_yokai` 가 방문 누계 ≥ tuning `promote_visits`(2) · 평판 ≥ `promote_reputation`(5) · 미입주 를 판정, `PromotionSystem` 이 아침에 예고하고 플래그(값 = 하숙생 id)를 심으면 `IntakeSystem` 이 그날 저녁 **kind promotion** 카드(visitors.csv v_promotion, 카드 문구 "장기 계약을 청한다")로 내민다. 받기 = `Intake.decide` 가 erased 와 같이 하숙생 입주(빈 침대 필요), 거절 = 다음 날 다시 청함. 금줄이(g_geumjuri) → `y05_geumjuri`(in_slice, 1막 사연 y05_act1). 해금 `u_promotion` 25일.
- **밤 변형 구역**: `regions.csv` 에 night_gather_pool / night_enemy_pool / night_enemy_count / night_sky_color 컬럼. `DataRegistry.get_region("<base>@night")` 가 base 를 duplicate 해 풀·색·이름("뒷산 (밤)")을 바꾼 파생 리소스를 캐시하고, 적 풀이 있으면 kind 를 **expedition** 으로 (동료 전투·진입 비용 규칙). `RegionManager.travel` 이 밤 + feature `night_<base>` 해금이면 변형 id 로 해석하고, 아침엔 기본으로 돌아온다. 변형의 채집 상태는 `region_states["r_back_hill@night"]` 에 따로 살고 아침 리스폰 때 비워진다. 뒷산 밤 = 버섯·약초·그늘이끼·**달빛 이슬**(신설 재료, chains 3칸) + 잿불 도깨비불 2. 해금 `u_night_hill` 21일.
- **P2 게이트 킷**: `summarize.py` 에 calendar_opened / goals_opened / goals_completed / festival_prep / festival_score / market_trades / blessings / night_regions / chapter 열과 P2 게이트 요약 줄, 설문 9(다음에 할 일 3개)·10(달력/할 일 열람), go_no_go P2 표, README P2 안내. 시뮬레이터는 이미 28일.

이유:
- P2 게이트 "다음에 할 일 3개" 는 서사(챕터 게이트)·승격·밤 변형이 각각 다른 갈래의 '다음' 을 만든다. 게이트를 병렬 목표 n개로 둔 것은 콘텐츠를 강제 순서로 잠그지 않기 위해서.
- 승격을 심사 카드 흐름에 얹은 것은 "밤에 문을 두드린다" 는 게임의 단일 입구를 지키고, 기존 Intake/roster/사연 파이프라인을 그대로 쓰기 위해서. yokai.csv 행 추가로 끝난다(CLAUDE.md 5.1).
- 밤 변형을 파생 리소스 + id 접미로 만든 것은 regions.csv 행을 늘리지 않고(7 + 밤 7 = 14행이 아니라 컬럼 4개), 채집·적·문·카메라 코드가 base 와 같은 경로를 타게 하려는 것.

대안과 기각 사유:
- 챕터 이벤트를 별도 chapter_events.csv 로: events.csv 의 스케줄러(시간대·플래그·1회)가 이미 필요한 전부다. kind 만 추가.
- 승격 전용 UI: 카드 한 장이면 충분하고, "장기 계약" 안내 문구만 바꿨다.
- 밤 변형을 별도 regions 행(r_back_hill_night)으로: 문·레이아웃 컬럼을 복제해야 하고 문의 대상 id 가 시간대마다 갈라진다. 접미 해석으로 대체.

미해결·사용자 결정 필요:
- 챕터 대사 8편(56줄)은 초안 — 톤·길이(docs/05 6절)를 사람이 퇴고. 회수 집행관의 감사 선택지 결과(수수료 100 vs 평판 무변)는 임시.
- 승격 조건(방문 2·평판 5)과 금줄이 능력치·하숙비(컨디션 회복 15, 2일)는 초안. 승격 하숙생의 스프라이트는 자리표시.
- 밤 뒷산은 동료 없이도 들어갈 수 있어(문 통과) 적에게 맞으면 스태미너로 우물로 물러난다 — 밤 진입 경고 문구를 문 프롬프트에 넣을지.

영향받는 파일/문서: data/csv/chapters.csv(신설), {goals,yokai,guest_species,visitors,spirits,items,materials,chains,regions,events,dialogue,unlocks,tuning,metrics_events,strings_ko}.csv, tools/data/build_resources.py, tools/playtest/summarize.py, src/core/chapter_rules.gd(신설), src/core/{goal_rules,intake}.gd, src/core/resources/{chapter_data,guest_species_data,region_data}.gd, src/systems/{chapter_system,promotion_system}.gd(신설), src/systems/intake_system.gd, src/world/{region_manager,gather_system}.gd, src/autoload/{game_state,save_manager,events,data_registry}.gd, src/ui/{intake_panel,hud_text,menu_hub}.gd, src/main.gd, test/unit/test_chapter_rules.gd, test/integration/{test_chapter_night,test_save_roundtrip,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md, docs/playtest/{README,questionnaire,go_no_go_template}.md
