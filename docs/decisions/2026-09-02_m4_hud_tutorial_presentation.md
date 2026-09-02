# M4 HUD·튜토리얼·연출·임시 사운드
날짜: 2026-09-02
결정:
- **HUD 분리**: `Hud`(상단 바 — 날짜·페이즈·날씨·돈·평판·침대, 행동 버튼, 하숙부·명부, 창고 줄, 안내 줄, 낮 진행 바) + `MessageLog`(왼쪽 아래, `Events.message_posted` 문장을 N줄 유지·페이드) + `DebugOverlay`(F1, 디버그 빌드 전용: 저장/불러오기/돈). 시그널→문장 변환은 `HudText`(순수)로 모았다. `DebugHud` 삭제.
- **성주 영감 안내(조용한 튜토리얼)**: `hints.csv`(페이즈·날짜·필요 플래그·차단 플래그·우선순위) + `HintPicker`(순수). `TutorialSystem` 이 첫 배치·첫 낮·첫 건설·첫 심사·객실 추가를 `first_*` 플래그로 남기고, 상황에 맞는 문구를 `hint_changed` 로 HUD 에 보낸다. 대화형 튜토리얼(events.csv tutorial 4개)과 짝을 이룬다. 플래그는 세이브에 포함.
- **어둑이 또렷해짐**: `yokai.csv` `clarity_by_affinity` + `Clarity.alpha_for()`(순수). 호감도 0 → 투명도 `clarity_alpha_min`(0.4), `clarity_affinity_max`(3) 에서 1.0. 액터 스프라이트와 배치 카드 아이콘에 같이 적용. 밤에는 `night_worker` 요괴 주변에 `PointLight2D`(등불지기). 픽셀 스냅을 깨는 스케일 변화는 쓰지 않았다.
- **임시 사운드**: `tools/audio/gen_placeholder_audio.py` 가 표준 라이브러리만으로 WAV 9종을 합성(절차적 → 라이선스 불요, `docs/asset_licenses.md` 기록). `sfx.csv`(id·파일·볼륨·루프) 가 데이터, 어떤 Events 에 어떤 소리를 붙일지는 `AudioSystem`(코드). 비 오는 날 낮·저녁 빗소리 루프.
- **하숙부**(`RosterPanel`): 하숙생별 호감도·사연 진행(본 막/전체). docs/06 의 '기록된 이름은 지워지지 않는다' 를 UI 문장으로 노출.

이유:
- 완료 판정("신규 테스터가 설명 없이 3일차 도달")은 사람 테스트 영역. 제가 할 수 있는 것은 (1) 첫 행동마다 다음 행동을 안내하고 (2) 결과를 문장으로 보여주고 (3) 어둑이 규칙을 말없이 보이게 하는 것까지.
- 효과음을 절차 합성한 것은 에셋 라이선스 검토 없이 즉시 피드백을 줄 수 있어서다. 교체는 파일만 바꾸면 된다.

대안과 기각 사유:
- 어둑이를 스케일로 키우기(전승 '올려다보면 커짐'): 정수 배율이 아닌 스케일은 픽셀 격자를 깨뜨림. 투명도 + 밤 빛으로 대체. 정식 아트에서 단계별 스프라이트 변형으로 표현(docs/06 발주 명시).
- 튜토리얼을 강제 순서(모달) 로: 배치 퍼즐 검증에 방해. 안내 문구는 비모달로만.

영향받는 파일/문서: data/csv/{hints,sfx,yokai,tuning,strings_ko}.csv, tools/audio/gen_placeholder_audio.py, assets/audio/generated/, src/core/{hint_picker,clarity}.gd, src/core/resources/{hint,sfx}_data.gd, src/systems/{tutorial_system,audio_system,story_system}.gd, src/ui/{hud,hud_text,message_log,debug_overlay,roster_panel,yokai_card,assignment_panel}.gd, src/yokai/{yokai_actor,yokai_manager}.gd, src/house/house_view.gd, src/main.gd, src/autoload/{events,data_registry}.gd, test/unit/test_hint_clarity.gd, test/integration/test_hud_tutorial.gd, docs/asset_licenses.md
