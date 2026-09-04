# P1 「하루의 재미」 / P2 「한 절기의 재미」 플레이테스트 진행 안내

P2 (2026-09-04 추가): 같은 진행에 설문 9·10번(다음에 할 일 3개, 달력/할 일 열람)과 `go_no_go_template.md` 의 P2 표가 붙는다.
조작이 늘었다: K 달력, H 할 일, 하숙생 앞 E 가호, 우물 아래 회색 시장(음기 짙은 날·밤), 밤의 뒷산. 여전히 **설명하지 않는다.**

목적: docs/08 7절 · docs/01 v3 1절 P1 게이트 판정 — "오늘 할 일이 밀려서 즐거웠다" 는 발화 + 로그상 하루 4개 이상 활동 혼합.
테스터 5명, 1인당 45~75분(하루 12분 × 3~5일). 조작: A/D 이동, Shift 달리기, W/S 계단, E 상호작용, Q/R/G 부적, ESC 메뉴 닫기, F1 디버그(시간 건너뛰기).
원칙: **설명하지 않는다.** 게임 안의 성주 영감 안내만으로 마당·뒷산·잿빛 들에 닿는지도 함께 본다.

## 진행자 준비

1. 빌드: `build/yokai-boarding.exe` (내보내기 방법은 아래). 테스터 PC 에 폴더째 복사.
2. 테스터마다 새 세션으로 시작한다 (기존 세이브 슬롯 1 은 F1 디버그에서만 접근되므로 그대로 둬도 됨).
3. 로그는 자동으로 `%APPDATA%\Godot\app_userdata\yokai-boarding\metrics\session_<시각>.jsonl` 에 남는다. 세션이 끝나면 이 파일을 회수한다.
4. 관찰자는 `observer_sheet.md` 를 옆에서 채운다. 15분 시점 질문(1번 기준)은 반드시 정해진 문장으로만 묻는다.
5. 끝나면 `questionnaire.md` 를 테스터가 직접 적는다.

## 테스터에게 하는 말 (이 이상 말하지 않는다)

"낡은 하숙집을 물려받았습니다. 마음대로 해 보세요. 궁금한 게 있어도 제가 답하지 않습니다. 45분 뒤에 멈추겠습니다."

## 집계

```powershell
python tools/playtest/summarize.py <로그 폴더>
```

세션별 지표(플레이 분, 도달 일차, 배치 횟수, 건설, 심사 결과, 사연 수, 어둑이 호감도, 저장) 와 Go/No-Go 2번 자동 힌트가 나온다. 1·5·6 번은 설문·관찰 시트로, 3·4 번은 아래 자동 검증으로 판정한 뒤 `go_no_go_template.md` 를 채운다.

## Go/No-Go 3·4 번 (자동)

- 3번 파이프라인: 2026-09-02 실험 — Y04 바리를 `yokai.csv` 행 + `gen_placeholder.py` 스프라이트만으로 추가하고 코드 수정 없이 빌드·테스트 통과 (`docs/decisions/2026-09-02_m5_playtest_kit.md`).
- 4번 세이브 왕복: `test/integration/test_save_roundtrip.gd`, `test_seven_day_loop.gd` 가 CI 에서 매번 검증.

## 빌드 내보내기

Godot 4.7 export templates 가 설치돼 있어야 한다 (`%APPDATA%\Godot\export_templates\4.7.stable\`). 설치 후:

```powershell
& $env:GODOT_BIN --headless --path . --export-release "Windows Desktop" build/yokai-boarding.exe
```

`export_presets.cfg` 가 저장소에 있다. 내보낸 exe 는 디버그 오버레이(F1)가 빠진 릴리스 빌드다.
