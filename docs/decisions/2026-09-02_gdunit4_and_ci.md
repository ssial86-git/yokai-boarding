# gdUnit4 설치 방식과 CI 구성
날짜: 2026-09-02
결정:
- gdUnit4 **v6.2.1**(2026-08-20) 을 소스 태그 zip 에서 `addons/gdUnit4/` 만 추출해 저장소에 포함한다. 저장소는 `github.com/godot-gdunit-labs/gdUnit4` (구 MikeSchulze/gdUnit4 에서 이전됨).
- 로컬 실행은 프로젝트 루트에서 `.\addons\gdUnit4\runtest.cmd -a res://test`. 래퍼는 `GODOT_BIN` 환경변수 또는 `--godot_binary <경로>` 인자를 요구하며, Godot 프로세스의 종료 코드를 그대로 반환한다.
- CI(GitHub Actions, ubuntu)는 Godot 4.7 linux 바이너리를 `godot-builds` 릴리스에서 직접 받아 `--import → build_resources.py → validate_assets.py → git diff(생성물 커밋 확인) → gdUnit4` 순으로 돈다. gdUnit4 전용 액션은 쓰지 않는다.
- CI 의 gdUnit4 는 래퍼 대신 `GdUnitCmdTool.gd` 를 `--headless` 로 직접 호출하고 `--ignoreHeadlessMode` 를 붙인다. gdUnit4 v6 는 headless 를 기본 거부(종료 코드 103)하며, 래퍼 `runtest.sh/.cmd` 는 `--headless` 를 넘길 수 없다(툴이 알 수 없는 인자로 거부). 로컬 검증: 같은 명령이 Windows 에서 8/8 통과, 종료 코드 0.
- headless 에서는 InputEvent 가 전달되지 않으므로, UI 입력을 시뮬레이션하는 테스트를 추가할 때는 CI 통과 여부를 별도로 확인해야 한다 (M2 배치 UI 테스트 시 재검토).
- autoload 스크립트에는 `class_name` 을 붙이지 않는다 (autoload 이름과 전역 클래스명이 겹치면 Godot 이 충돌 경고). CLAUDE.md 5.5 의 class_name 규칙은 autoload 에 한해 예외.
- `data/csv/`, `tools/`, `docs/` 에 `.gdignore` 를 두어 Godot 스캔에서 제외한다 (CSV 가 번역 리소스로 임포트되는 것을 막음).

이유:
- v6.2.1 릴리스에는 첨부 자산이 없어 소스 zip 이 유일한 배포 경로. Asset Library 경유는 에디터 GUI 가 필요해 headless 셋업에 부적합.
- 전용 액션 대신 바이너리 직접 다운로드: 파이프라인 4단계를 같은 Godot 바이너리로 돌려야 하고, 버전을 한 곳(`GODOT_VERSION`)에서 고정하기 위함.
- `git diff --exit-code data/resources`: 생성물을 git 에 포함한다는 CLAUDE.md 7절 규약이 지켜지는지 CI 가 강제.

대안과 기각 사유:
- `MikeSchulze/gdUnit4-action`: Godot 설치까지 액션이 떠맡아 import/빌드 단계와 바이너리가 분리됨. 기각.
- `chickensoft-games/setup-godot`: 의존 액션 하나 추가에 비해 이점 적음. 기각.

영향받는 파일/문서: addons/gdUnit4/, .github/workflows/ci.yml, project.godot([editor_plugins], [gdunit4]), CLAUDE.md 3절·5.5, src/autoload/*.gd
