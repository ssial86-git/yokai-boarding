# P1-S4 잿빛 들 — 데이터 배치 적·동료 자동 전투·부적 사용·시뮬레이터·게이트 지표
날짜: 2026-09-03
결정:
- **탐험지는 regions.csv 로만 조립한다.** `enemy_count`(신설 컬럼)만큼 `enemy_pool` 에서 뽑아 구역 폭의 `enemy_spawn_x_from~to` 비율에 고르게 놓고, `boss_id` 는 `boss_spawn_x` 자리에 둔다. 추첨 RNG 는 `시드:날짜:구역` 해시로 파생해 방문자 RNG 를 소모하지 않는다. 처치한 적은 그날 다시 나오지 않고(`region_states[*].enemies_defeated`, 하루 시작에 비움) 미니보스는 `boss_defeated` 로 남는다. 재도전(feature `boss_rematch`, 11일차)이 열리면 `boss_rematch_multiplier` 배 체력으로 다시 나온다.
- **동료는 아침 배치의 '동행' 슬롯이다.** `Assignment.PARTY`(가상 칸, 정원 `party_max`=2) — 텃밭(FIELD)과 같은 방식이라 검증·직렬화·정산(일한 것으로 컨디션 차감)을 그대로 쓴다. 집 밖 어느 구역에서든 `CompanionActor` 로 따라오고(2026-09-04: 처음엔 탐험지에서만 소환해 "슬롯에 놨는데 안 된다" 는 혼란이 있었다), 탐험지에서는 플레이어 반경(`companion_leash_px`) 안의 가장 가까운 적과 자동 교전하고, 적이 없으면 플레이어 뒤로 돌아온다. 체력·피해·간격은 `Combat`(core)이 능력치 + 배식 버프에서 계산한다(담력→체력, 힘→피해, 솜씨→간격). 쓰러지면 이번 탐험에서 빠진다.
- **플레이어는 체력이 없다.** 적의 공격은 스태미너를 깎고(`enemy_hit_stamina_per_attack`) 밀어낸다. 0 이 되면 우물로 물러난다(`expedition_retreat_region`) — 강제 기절·게임오버 없음(docs/01 v3 2.1 벌 최소화). 탐험지 진입에도 스태미너가 든다(`regions.stamina_enter_cost`).
- **부적은 Q/R/G 다.** 투척(Q): 바라보는 쪽으로 `TalismanProjectile` 이 날아가 첫 적을 맞히고 밀어낸다, 쿨다운 `cooldown_seconds`. 귀환(R): 어디서든 집으로. 채집(G): `gather_talisman_duration_seconds` 동안 채집마다 `power` 개 추가. 셋 다 창고에서 하나씩 쓴다. 입력 액션은 main.gd 가 코드로 등록한다.
- **전리품이 사슬을 닫는다.** 잿불 도깨비불→잿빛 풀(0.7), 재구렁 개→잿불돌(0.6), 잿빛 파수꾼→그늘이끼(1.0). 투척 부적 재료를 `천 + 잿불돌`, 채집 부적을 `천 + 나뭇가지` 로 바꿔 탐험 전리품 → 제작, 잿빛 풀·그늘이끼 → 티어 2 요리로 이어진다(chains.csv 검증 통과).
- **시뮬레이터 `tools/sim/autoplay.py` 는 CI 게이트다** (`--check`). (1) 케이던스: unlocks.csv 의 expected_day 를 실시간 분으로 펴서 해금 없는 구간이 30분을 넘으면 실패 — 현재 최대 공백 12분. (2) 위임 손익 교차점: 되찾은 스태미너로 채집해 얻는 가치 − 잃는 수확 − 주방 산출 손실이 양수가 되는 첫날(위임 해금 이후) — 현재 8일차(목표 6~8). (3) 경제 곡선 초안은 표만 낸다. 모델 상수는 전부 CSV 에서 읽고 가정은 출력에 적는다.
- **P1 게이트 지표**: `Metrics` 의 `day_ended.activities`(그날 쓴 동사 종류 수)를 `summarize.py` 가 `days_4plus_activities` 로 집계한다. `docs/playtest/go_no_go_template.md` 를 P1 게이트(발화 + 하루 4개 활동 + 케이던스 + 위임 교차점 + 세이브 왕복 + 행 추가)로 바꾸고 M5 표는 참고로 남겼다.

이유:
- docs/08 원칙 1(동사: 탐험·전투 지시·부적 투척)·2(스태미너가 예산이자 체력)·3(전리품 세 갈래)·6(케이던스를 데이터로 검사)을 이 세션에서 닫아야 P1 게이트 판정이 가능하다.
- 자동 전투에서 플레이어의 개입감은 투척 부적 하나에 달려 있다(docs/01 v3 7절 리스크). 쿨다운·궤적·밀림을 tuning 으로 노출했고, 밋밋하면 조준형으로 승격하는 예비안은 그대로다.

대안과 기각 사유:
- 플레이어 체력·게임오버: 벌 최소화 원칙에 어긋난다. 스태미너 하나가 이동·작업·전투 예산을 겸한다.
- 적 AI 를 NavigationAgent 로: 가로 이동만 있는 단면이라 x 축 추적으로 충분하다(내비메시 금지).
- 동행 편성을 별도 UI 로: 아침 배치 패널의 드롭 영역 하나가 가장 적은 학습 비용이다.
- 시뮬레이터를 실제 게임 로직 재사용(GDScript)으로: Python 이 CI·튜닝 반복에 빠르고, 모델은 의도적으로 단순하다(사람이 확정).

미해결·사용자 결정 필요:
- 전투 수치(적 체력·공격·속도, 동료 체력/피해 계수, 스태미너 피해 6/공격, 투척 부적 피해 2·쿨다운 3초)는 초안이다. 투척의 개입감(밋밋하면 조준형 승격)은 직접 플레이 후 판단.
- 위임 교차점 모델은 "되찾은 스태미너를 전부 채집에 쓴다" 가정이다. 실플레이 로그와 비교해 상수를 고쳐야 한다.
- 작업장을 지어야 부적을 만들 수 있다는 안내가 아직 없다(S3 미해결 그대로).

영향받는 파일/문서: src/core/{combat,assignment,day_settlement}.gd, src/systems/expedition_system.gd, src/companions/companion_actor.gd, src/world/{enemy_actor,talisman_projectile,region_view,region_manager,gather_system}.gd, src/player/player_controller.gd, src/ui/{assignment_panel,hud_text,yokai_card}.gd, src/yokai/yokai_manager.gd, src/autoload/game_state.gd, src/core/resources/region_data.gd, src/main.gd, data/csv/{regions,enemies,talismans,tuning,strings_ko,unlocks}.csv, tools/data/build_resources.py, tools/sim/autoplay.py, tools/playtest/summarize.py, docs/playtest/{README,go_no_go_template}.md, .github/workflows/ci.yml, test/unit/test_combat.gd, test/integration/{test_expedition,test_data_build,test_station_fishing}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
