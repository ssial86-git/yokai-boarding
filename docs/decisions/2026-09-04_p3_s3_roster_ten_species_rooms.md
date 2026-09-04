# P3-S3 — 하숙생 10·뜨내기 12종·승격 3·가호 확장·방 2
날짜: 2026-09-04
결정:
- **장기 하숙생 10** (yokai.csv): 시작 2(뚝딱이·어둑이) + 도착 5(달갤 2일, 바리 30일, 아홉 44일, 무쇠 58일, 그슨대 99일 — join_mode intake 의 빈 카드 심사) + 승격 3(금줄이·옹기·달토끼 — guest_species.promotes_to). 바리는 P1 파이프라인 검증용 행(in_slice false)을 실전 행으로 올렸다. 각자 **사연 3막**(events story 3 + dialogue 3~5줄, 호감도 0/1/2 게이트, 아버지 단서 1개씩)과 **가호 1행 + 시너지 2·간섭 1** — 초안, 사람 퇴고 필요.
- **뜨내기 12종**: 8종 추가(옹기귀·보부상귀·바람뭉치·달토끼·눈아이·먹물 요정·등불고기·돌미륵), 희귀도 4단계(**legendary** 신설, 가중치 1). 등장 조건은 weather id(갈바람·달무리·눈·눈보라)로 절기 감각을 준다.
- **해금 타입 2 신설**: `species`(guest_species) — `IntakeSystem.open_species()` 가 가리키는 행이 열린 종족만 추첨에 넣는다; `room`(rooms) — `BuildMenu` 가 열린 방만 보인다(가리키는 행이 없으면 늘 열림). 방 2: 서고(service, 조용, 작업장 필요)·온돌방(lodging 3, 객실 필요).
- unlocks 85~112일을 30분 규칙으로 채웠다(온돌방 87·눈아이 95·서고 97·그슨대 99·돌미륵 101·등불고기 103·가호 2회 106·연말 예고 108·승격 2 110). 여름·가을에도 종족·하숙생 도착 행을 얹었다. 시뮬레이터 기본 일수 **112**(한 해).
- `blessing_two_per_day` feature(뚝딱이 호감도 3): 하루 가호 한도 +1(tuning `blessing_per_day_bonus`).
- 자리표시 스프라이트·일러스트는 `gen_placeholder.py` 재실행으로 생성(새 요괴 5·종족 8·방 2).

이유:
- P3 게이트 "12시간 뒤 재접속" 은 1~5시간 구간 1시간당 1명 입주 케이던스(docs/08 6절)에 기댄다. 도착 날짜를 30·44·58·99 로 벌리고 승격 3 을 사이에 둬 한 해 내내 새 얼굴이 온다.
- 종족·방 해금을 unlocks 타입으로 둔 것은 "새 콘텍츠 = CSV 행" 을 지키면서 케이던스 검사기가 그 등장을 보게 하려는 것.

대안과 기각 사유:
- 하숙생을 가중치 추첨으로 무작위 도착: 서사 순서(바리 → 문서고 위치)가 필요해 날짜 고정.
- 희귀도 4단계 대신 weight 만: 명부의 "전설" 표기(수집욕)가 목적.

미해결·사용자 결정 필요:
- 대사 90줄(사연 18막)·가호 수치·도착 날짜·방 비용은 초안.
- 서고는 아직 고유 기능이 없다(조용한 service 방). P4 도감/위장에서 쓸 자리.
- 승격 2·3(옹기귀·달토끼)의 조건은 금줄이와 같은 tuning(방문 2·평판 5)을 쓴다.

영향받는 파일/문서: data/csv/{yokai,guest_species,blessings,synergies,chains,rooms,events,dialogue,unlocks,tuning,strings_ko}.csv, assets/art_generated/(자리표시 신규), tools/data/build_resources.py, tools/sim/autoplay.py(112일), src/systems/{intake_system,unlock_system,blessing_system}.gd, src/ui/build_menu.gd, src/main.gd, test/integration/{test_roster_p3,test_data_build}.gd
