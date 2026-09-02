# M5 플레이테스트 킷과 파이프라인 실험(Go/No-Go 3번)
날짜: 2026-09-02
결정:
- M5 는 사람이 하는 검증(테스터 5명)이다. Claude Code 의 몫은 킷 준비: `docs/playtest/`(진행 안내·설문·관찰 시트·판정 템플릿), `PlaytestLog`(user://playtest/session_*.jsonl, tuning `playtest_log_enabled`), `tools/playtest/summarize.py`(세션별 지표 + Go/No-Go 2번 자동 힌트), `export_presets.cfg`(Windows Desktop, 릴리스, pck 내장, tools/docs/test/addons 제외).
- **Go/No-Go 3번 실험 결과: Go.** Y04 바리를 `yokai.csv` 한 행(`join_mode=intake, join_day=0` 이라 슬라이스에서는 등장하지 않음, `in_slice=false`) 추가 + `gen_placeholder.py` 재실행(스프라이트·일러스트 자리표시 자동 생성)만으로 빌드·아트 검증·테스트가 통과했다. 코드 수정 0. 유일한 변경은 `test_data_build.gd` 가 하숙생 총수 3 을 고정하고 있던 것으로, 슬라이스 수(3)만 고정하도록 테스트를 고쳤다 — 테스트가 콘텐츠 수를 하드코딩하면 안 된다는 교훈.
- 설문·관찰 시트의 문장은 유도 질문을 피하도록 고정했다(15분 질문은 "지금 무슨 생각을 하고 있어요?" 한 문장만).

이유:
- Go/No-Go 1·5·6 은 사람의 말과 관찰이 근거이므로 종이 시트가 필요하고, 2 는 로그로 반쯤 자동화할 수 있다. 4 는 이미 CI 가 매번 검증.
- 로그는 개인정보 없이 게임 상태만 남긴다.

대안과 기각 사유:
- 인게임 설문 UI: 테스터의 첫 플레이 흐름을 방해. 종이/문서로.
- 원격 텔레메트리 업로드: 슬라이스 단계에 과함. 파일 회수로 충분.

미해결: Windows export templates(4.7-stable, 약 1.28 GB) 가 이 PC 에 없어 exe 내보내기는 사용자 승인 후 진행한다. 템플릿 없이도 `docs/playtest/README.md` 의 소스 실행 방식으로 테스트는 가능하다.

영향받는 파일/문서: docs/playtest/*, src/systems/playtest_log.gd, src/main.gd, tools/playtest/summarize.py, export_presets.cfg, .gitignore, data/csv/{yokai,tuning}.csv, assets/art_generated/*bari*, test/integration/test_data_build.gd
