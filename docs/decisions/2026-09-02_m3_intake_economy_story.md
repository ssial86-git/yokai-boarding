# M3 심사·경제·사연 모델
날짜: 2026-09-02
결정:
- **침대**: 객실(lodging) capacity 합 = 침대 수. 하숙생 + 체류 손님이 하나씩 쓴다. 빈 침대가 없으면 심사에서 받을 수 없다(`Intake.Outcome.NO_BED`). 새 게임 객실은 2침대이고 하숙생 2명이 차지하므로, 2일차 달갤을 받으려면 객실을 하나 지어야 한다 — 증축 동기의 첫 발동.
- **입주 방식**: `yokai.csv` `join_mode`(start/intake)·`join_day`. 달갤은 `intake`/2 — 2일차 저녁에 '빈 카드'(erased) 방문자로 고정 도착하고, 받으면 `joined_<yokai_id>` 플래그가 남아 도착 튜토리얼이 걸린다.
- **방문자 추첨** (`VisitorRoll`): 고정 도착 > `visitor_chance` 판정 > `visitors.csv` 가중치(guest 60 / troublemaker 10 / erased 0=고정 전용) > `guest_species.csv` 가중치(날씨 조건 `appear_condition` 필터). 액운 = max(유형 범위 난수, 종족 기본값). RNG 는 `GameState.rng` 하나로 통일하고 상태를 세이브(문자열)해 로드 후에도 이어진다. 시드 `tuning.visitor_seed`(0=무작위).
- **심사 결정** (`Intake`): 받기/거절. '하룻밤만' 은 슬라이스에서 받기와 동일. 액운 < `decline_omen_threshold` 인 손님을 거절하면 평판 -1, 받으면 +1. 사고뭉치는 체크아웃 때 `mishap_money` 를 잃는다.
- **하숙비** (`Rent`): 하숙생은 `rent_type` 별 — items(`rent_item` 이 `kind:<종류>` 면 그 종류 중 무작위), errand/buff(모두의 컨디션 +`rent_amount`), money, none. `rent_interval_days` 주기. 손님은 체크아웃(다음 저녁) 때 `rent_money` + 특이 하숙비. 경제 순환: 손님 숙박비(30~60) → 객실 증축(100) → 침대 ↑ → 손님 ↑.
- **날씨**: 아침마다 `rain_chance` 로 비/맑음. 우산손은 비 오는 날만 등장. 다른 효과 없음.
- **사연**: `events.csv`(조건: 페이즈·날짜·입주·호감도·소지품·플래그·once) + `dialogue.csv`(dialogue_id 별 노드 그래프, 선택지 2개, 효과 `affinity/item/flag/money`). 한 페이즈 전환당 이벤트 하나. 같은 우선순위면 **호감도가 낮은 하숙생의 사연을 먼저** 띄워 3명이 돌아가며 나온다. 달갤 2·3막은 `record_piece` 가 있어야 열린다(Tier 2 파견에서 획득 — 슬라이스에서는 데이터만).
- **가택신**: `spirits.csv` 3행. 성주(튜토리얼 내레이터), 조왕(정산 대사), 문돌이(심사 카드) — 대사 화자로만 등장하고 별도 노드는 없다.
- **UI**: `IntakePanel`(카드 + 받기/거절, 빈 침대 없으면 받기 비활성), `DialogueBox`(일러스트 자리표시 1024² 를 96px 로 축소, Linear 필터), `LedgerPanel`(손님 명부). 대화창이 열려 있으면 심사 카드는 대화가 끝난 뒤 뜬다.
- **세이브 v4**: guests / ledger / flags / seen_events / pending_visitor / weather / rng_state.

이유:
- 7일 경제 순환(완료 판정)은 `test_seven_day_loop` 가 시드 고정으로 자동 진행하며 확인한다: 달갤 입주, 손님 숙박비 수입, 명부 기록, 튜토리얼 4 + 사연 1막 3개, 세이브 왕복.
- 호감도 낮은 순 로테이션이 없으면 우선순위·id 순서 때문에 달갤 사연이 7일 안에 한 번도 안 나온다(테스트로 확인).
- 대사 텍스트는 Claude 초안이다. docs/01 7절대로 사람 퇴고가 필수이며, CSV 만 고치면 된다.

대안과 기각 사유:
- 손님도 방에 배치(일)시키기: docs/06 은 뜨내기를 플레이버+하숙비+스프라이트로 한정. 기각.
- 밤에 조건 맞는 이벤트를 전부 연달아 띄우기: 밤 페이즈 길이가 늘고 텍스트 피로. 하루 하나로 제한.
- 방문자 RNG 를 시스템별로 분리: 세이브·재현이 복잡해짐. 하나로 통일.

영향받는 파일/문서: data/csv/{yokai,guest_species,visitors,spirits,events,dialogue,rooms,tuning,strings_ko}.csv, tools/data/build_resources.py(grouped 테이블·대사 검증), src/core/{lodging,rent,visitor_roll,intake,dialogue_graph,event_scheduler}.gd, src/core/resources/{visitor,spirit,event,dialogue}_data.gd, src/systems/{day_cycle,intake_system,story_system}.gd, src/ui/{intake_panel,dialogue_box,ledger_panel,debug_hud}.gd, src/yokai/yokai_manager.gd, src/autoload/{game_state,save_manager,data_registry,events}.gd, tools/art/gen_placeholder.py(illust 자리표시), test/unit/test_{lodging_intake,rent_visitor_roll,dialogue_events}.gd, test/integration/{test_seven_day_loop,test_save_roundtrip,test_day_cycle}.gd
