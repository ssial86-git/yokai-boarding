# P2-S1 — 절기 달력·음기 날씨·소절기 이벤트
날짜: 2026-09-04
결정:
- **절기 달력은 순수 로직 `Calendar`(core)가 들고 GameState 가 소유한다.** `seasons.csv`(id·이름·순서·길이 28·다음 절기)로 4절기 순환을 데이터로 두되, P2 콘텐츠는 봄 한 절기까지만 채운다. 하루를 넘기는 곳은 `GameState.advance_day()` 하나(Clock.sleep 만 부른다)이고, 절기의 마지막 날을 넘기면 `Events.season_changed`. 통산 일차(`GameState.day`)는 그대로 두고 달력이 옆에 붙는다 — unlocks/events/hints 의 day_min 체계를 흔들지 않기 위해.
- **세이브 v6**: `game_state.calendar{season, day_of_season}` + `yin`. v5 마이그레이션은 달력을 비워 두고 `Calendar.from_absolute_day(day)` 로 계산한다 (1일차 = 봄 1일 → 30일차 = 여름 2일). 왕복·마이그레이션 테스트 갱신.
- **날씨 × 음기 추첨표 `weather.csv`** 가 "비 오는 날 = 음기" 임시 규칙을 대체한다. 행 = 날씨(맑음·비·안개(봄)·달무리) × 절기 조건 × 가중치 × 음기 범위(0~3) × 이승/마계 손님 배율 × 비 물주기 보너스. `WeatherRoll`(core)이 절기별 후보에서 뽑고 음기는 그 범위 안에서 다시 뽑는다. 추첨 RNG 는 방문자 RNG 를 소모하지 않도록 시드+날짜 파생(채집 리스폰과 같은 규칙). `tuning.rain_chance` 삭제.
- **음기의 세 효과**를 기존 로직에 연결했다: (1) 손님 종족 가중치 × 갈래 배율 — `guest_species.realm`(mortal/demon) 신설, `VisitorRoll.roll(..., realm_multipliers)` 실수 가중 경로 추가(배율을 비우면 기존 정수 경로 그대로여서 시드 테스트가 안 흔들린다), (2) 작물 `yin_growth_bonus` 는 `GameState.is_yin_high()`(tuning `yin_high_threshold`=2) 로, (3) 채집 추첨이 `materials.yin_condition` 을 존중 — high 재료는 짙은 날만, low 재료는 짙은 날 빼고. 조건으로 풀이 다 빠지면 조건을 무시해 구역이 비지 않는다. 잿빛 풀은 `high → any` 로 바꿔 잿빛 들이 평일에도 캘 게 있게 했고, 그늘이끼(rare)만 짙은 날 보상으로 남겼다.
- **제철**: `crops.season` 을 드디어 쓴다. `Farm.sow(..., season_key)` 가 제철 아니면 `OUT_OF_SEASON`, `FarmSystem.seed_choice()` 는 제철 씨앗만 고른다. 비 오는 아침은 `weather.crop_water_bonus` 만큼 자라는 칸이 절로 젖는다(장마의 체감).
- **소절기 이벤트 `season_events.csv`** (P2 범위 2개: 장마 시작 봄 10~11일 = 비 고정, 만월 봄 20~21일 = 달무리 고정·마계 손님 ×1.5·채집 ×1.2). 활성 판정·배율은 `Calendar.events_on/weather_override/demon_guest_multiplier/gather_multiplier`. 시작 날 아침에 `season_event_started` + 메시지 로그 한 줄 + 지표. 채집 배율의 소수 부분은 그 확률로 +1 (1.2 → 20%).
- **UI**: HUD 시계 카드 1줄 "06:00 아침 · 봄 1일", 2줄 "맑음 · 음기 ●○○ · 하숙집". 장부 메뉴에 **달력 탭 [K]** — 제목(절기 — n/28일, 통산 일차), 7열 격자(● 오늘 주황 · ◆ 소절기 · 지난 날 흐림), 범례, "다가오는 것" 목록. 열 때마다 지표 `calendar_opened`(P2 게이트의 "달력을 봤는가").
- **빌드 검증** `check_seasons`: 음기 0~3, 절기 이벤트 날짜·기간이 절기 길이 안, 길이·순서 양수.
- **검증 에이전트가 잡은 UI 손질**: 장부·작업대 패널 시작을 16%→20%(시계 카드 아래, 겹침 10px 제거), 행 목록 높이는 고정 비율 대신 `ListMenu._fit_rows()` 가 "화면 아래 여백까지 남는 공간"으로 맞춘다(탭 줄이 있는 장부에서 닫기가 화면 밖으로 밀리던 것). 메시지 로그는 한 줄 = 칩 상자(토스트)로 바꾸고 폭을 tuning `message_log_width_ratio`(0.29)로 제한 — 집 단면·실외 스프라이트 위에서도 상자 덕에 읽힌다(스타듀밸리 HUD 메시지 관행). 더미가 위로 자라 시계 카드·안내 줄을 덮지 않도록 높이 상한(tuning `message_log_top_ratio` 0.36 아래)을 넘으면 오래된 줄부터 지운다. 플레이스루에 `calendar_rows_fit`·`menu_below_clock_card`·`menu_close_on_screen` 검사 추가.

이유:
- 재미 원칙 6(케이던스)과 P2 목표 "절기 하나를 돌면 다음 절기가 궁금하다"의 뼈대가 달력이다. 통산 일차를 유지한 것은 P1 의 37개 해금·이벤트 조건이 전부 day 기준이라 깨뜨릴 이유가 없었기 때문.
- 날씨를 표로 빼면 절기별 날씨(겨울 눈 등)가 CSV 행 추가로 끝난다 (CLAUDE.md 5.1). 음기 0~3 은 docs/08 의 "이승 날씨가 마계를 흔든다" 를 수치 하나로 만든 것.
- 시드 파생 RNG: 날씨 추첨이 방문자 RNG 를 소모하면 P1 의 시드 고정 테스트·플레이스루가 전부 흔들린다.

대안과 기각 사유:
- 절기를 통산 일차에서 매번 계산(`(day-1) % 28`): 절기 길이가 다르거나 이벤트로 절기를 늘리는 확장이 막힌다. 상태로 들고 세이브했다.
- 음기를 별도 추첨(날씨와 독립): 안개·달무리가 짙고 맑음이 옅다는 직관이 표 하나에 있는 게 읽기 쉽다. 범위(min~max)로 약간의 흔들림만 남겼다.
- 달력을 독립 메뉴로: UI 정리 결정(탭 하나)에 맞춰 장부 탭에 넣었다.

미해결·사용자 결정 필요:
- 날씨 가중치(50/25/15/10)·음기 임계 2·장마/만월 날짜는 초안. 봄 이후 절기의 날씨·이벤트 행은 P2 후반에.
- 로드 직후 그날 날씨는 세이브에서 복원되지만, 다음 날 추첨은 메모리의 RNG 시드에 의존한다(채집 리스폰과 같은 한계).
- 소절기 이벤트 8 중 6개(docs/01 P2 표)는 CSV 행만 추가하면 된다 — 콘텐츠 작업으로 넘김.

영향받는 파일/문서: data/csv/{seasons,weather,season_events}.csv(신설), {guest_species,materials,tuning,strings_ko,metrics_events}.csv, tools/data/build_resources.py, src/core/{calendar,weather_roll}.gd(신설), src/core/{visitor_roll,gather_points,farm}.gd, src/core/resources/{season_data,weather_data,season_event_data,guest_species_data}.gd, src/autoload/{game_state,save_manager,clock,events,data_registry}.gd, src/systems/{day_cycle,intake_system}.gd, src/world/{farm_system,gather_system}.gd, src/ui/{hud,menu_hub,list_menu}.gd, src/main.gd, test/unit/{test_calendar,test_weather_roll}.gd, test/integration/{test_season_flow,test_save_roundtrip,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
