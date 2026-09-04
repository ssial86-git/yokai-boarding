# P3-S4 — 자동화 전환(위임 슬롯 3)·챕터 2 게이트·정착 에필로그 뼈대·P3 게이트 킷
날짜: 2026-09-04
결정:
- **위임 슬롯을 가상 배치 칸 셋으로 더했다** (`Assignment.GATHER/FISHING/MARKET`, 정원 tuning `*_workers_max`=1). 텃밭·동행과 같은 규칙(아침에만 배치, 컨디션 소모, 세이브 그대로). 배치 패널에 **둘째 드롭존 줄**(채집·낚시·판매)이 생기고, 각 존은 unlocks feature `delegate_gather`(23일)·`delegate_fishing`(27일)·`delegate_market`(36일)이 열려야 보인다(`delegation_open_check`).
- **대신 일하기**: 채집 위임은 낮에 `delegate_gather_region`(뒷산)의 남은 포인트 × `automation_efficiency`(0.6) 만큼 집 도구로 캘 수 있는 것을 캐 온다(`GatherSystem.auto_gather`). 낚시 위임은 낮에 `delegate_fishing_casts`(2)번 던져 효율 확률로 고물 아닌 어종을 낚는다(`FishingSystem.auto_fish`, 절기·시간대·낚싯대 규칙 그대로). 판매 위임은 저녁 정산 뒤 `auto_sell_kinds`(물고기·수확물)를 종류별 `auto_sell_keep`(3)개만 남기고 대문간 값 × 효율로 판다(`MarketSystem.auto_sell`). 위임 결과도 `activity_done` 을 쏘아 목표가 진행되고, 지표 `delegation`(slot;yokai;amount)에 남는다 — P3 게이트 "위임을 스스로 함" 의 계측.
- **시뮬레이터 2b 절**: 하루 산출 가치(텃밭·채집·낚시·판매) 중 위임분 비율을 날마다 내고, 슬롯이 전부 열린 뒤 **50% 이상**이면 통과(`DELEGATION_SHARE_TARGET`). 효율 0.6 이면 112일차 60%.
- **챕터 2 게이트**(chapters.csv c2): 문서고 위치(바리 3막 flag) / 하숙생 여섯 / 적 서른 / 단오 6점 중 2 → c3(자리표시). 챕터 2 이벤트 1(바리의 지도, 성주 영감). **정착 에필로그 뼈대**: events kind `epilogue` 신설 — 뚝딱이 정착(호감도 5 + flag chapter_c3), 사연 3막 수에 섞이지 않는다.
- **P3 게이트 킷**: summarize.py `delegation_actions / delegation_slots / loads` 열과 P3 요약 줄, 설문 11(위임)·12(재접속 의사), Go/No-Go P3 표, README P3 안내.
- 릴리스 내보내기는 이 환경에 Godot export templates 가 없어 실행하지 못했다(`%APPDATA%\Godot\export_templates` 비어 있음) — 사용자 PC 에서 `--export-release "Windows Desktop" build/yokai-boarding.exe` 실행 필요. export_presets.cfg 는 그대로 유효.

이유:
- docs/01 v3 2.2 자동화 층: 플레이어가 직접 하던 일을 "효율 60%" 로 넘기는 트레이드오프를 텃밭 하나에서 네 갈래로 넓혀야 후반(12시간)에 하루가 위임 위주로 바뀐다. 슬롯을 가상 배치 칸으로 둔 것은 배치 UI·정산·세이브를 전부 재사용하기 위해서.
- 판매 위임이 종류별 3개를 남기는 것은 요리·명절 재료가 자동으로 팔려 나가는 사고를 막기 위해서(안전 여유는 tuning).

대안과 기각 사유:
- 위임을 방(rooms.csv)으로: 슬롯이 방을 차지해 증축과 경쟁한다. 가상 칸으로.
- 판매 위임이 회색 시장 시세를 쓰기: 밤·음기 조건과 이동이 필요해 "대문간 행상" 으로 한정.

미해결·사용자 결정 필요:
- 효율 0.6·낚시 2회·남김 3개·해금 날짜는 초안. 위임 비중 목표 50% 는 docs/04 문구를 그대로 수치화한 것.
- 챕터 2 이후 서사(문서고 심부)·정착 에필로그 나머지 9명은 P4.
- 내보내기·12시간 플레이테스트는 사용자 몫(템플릿 설치 + 테스터).

영향받는 파일/문서: data/csv/{tuning,strings_ko,metrics_events,unlocks,chapters,goals,events,dialogue}.csv, tools/data/build_resources.py(event_kind epilogue), tools/sim/autoplay.py(2b 위임 비중), tools/playtest/summarize.py, src/core/assignment.gd, src/autoload/game_state.gd, src/world/gather_system.gd, src/systems/{fishing_system,market_system}.gd, src/ui/{assignment_panel,yokai_card,hud_text}.gd, src/main.gd, test/integration/{test_delegation,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md, docs/playtest/{README,questionnaire,go_no_go_template}.md
