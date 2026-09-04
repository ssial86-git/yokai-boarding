# CLAUDE.md — 요괴 하숙집 (가제) (사이드뷰 생활·경영·탐험 시뮬, Godot 4.7)

이 파일은 Claude Code가 이 저장소에서 작업할 때 항상 따르는 규약이다.
**큰 틀(재미 원칙·경험 곡선·분량)**은 `docs/08_master_design.md`, **현 단계 목표**는 `docs/01_vertical_slice_scope.md`(P1), **컨셉**은 `docs/00`, **아트**는 `docs/02`, **서사·로스터·심사**는 `docs/05~07`이 진실 공급원이다. 이 파일은 **어떻게 작업하는가**만 다룬다. 둘이 충돌하면 작업을 멈추고 사용자에게 알린다.

---

## 1. 프로젝트 한 줄 요약

마계의 폭군을 피해 도망쳐온 요괴들을 받아들여 하숙집을 키우는 사이드뷰 생활·경영·탐험 시뮬레이션 (프리미엄 PC — 방치형·광고 훅 금지). 주인공을 직접 조작하고(생활·탐험), 전투는 동료 요괴가 자동 수행하며, 하루는 실시간(페이즈 강제 진행 없음)이다. 현재 단계는 **P1 「하루의 재미」**이며 스코프는 `docs/01` v3의 수치로 고정되어 있다. 설계 판단 기준은 항상 `docs/08`의 재미 원칙 6이다. 수치를 넘는 기능 요청이 오면 구현 전에 스코프 문서 개정 여부를 먼저 묻는다.

## 2. 환경

- Godot **4.7 stable**, GDScript only (C# 사용 금지)
- 개발 OS: Windows (PowerShell). 셸 명령은 PowerShell 기준으로 작성하고, bash 전용 문법을 쓰지 않는다.
- Godot 실행 파일 경로는 환경변수 `GODOT_BIN`으로 참조한다. (예: `$env:GODOT_BIN = "C:\tools\godot\Godot_v4.7-stable_win64_console.exe"`)
- 테스트: **gdUnit4 v6.x** (`addons/gdUnit4/`, v6.2.1 기준 Godot 4.5~4.7.1 호환 확인)
- Python 3.x: `tools/` 아래 파이프라인 스크립트용 (Pillow, pandas)

## 3. 자주 쓰는 명령

```powershell
# 에셋 임포트만 (씬 열지 않고 .import 갱신)
& $env:GODOT_BIN --headless --path . --import

# 게임 headless 실행 (스모크 테스트: 메인 씬 로드 후 N초 뒤 종료)
& $env:GODOT_BIN --headless --path . --quit-after 300

# 단위 테스트 전체 (gdUnit4 CLI 래퍼. 내부적으로 res://addons/gdUnit4/bin/GdUnitCmdTool.gd 를 실행함.
# 종료 코드: 0 통과 / 100 실패 / 101 경고. 래퍼가 GODOT_BIN 환경변수를 참조함)
.\addons\gdUnit4\runtest.cmd -a res://test
# 특정 스위트 제외: -i ClassATest   /  fail-fast 끄기: -c

# 데이터 파이프라인: CSV → .tres Resource 재생성
python tools/data/build_resources.py

# 아트 검증 (규격/팔레트/파일명)
python tools/art/validate_assets.py

# 무료 CC0 팩(assets/art/packs)에서 게임 규격 시트 조립 + art_assets.csv 채우기 (팔레트 양자화 포함)
python tools/art/import_free_packs.py
# 단일 이미지 팔레트 양자화 (에셋팩·AI 산출물 → art_generated)
python tools/art/palette_quantize.py <in.png> <out.png> [--tint RRGGBB:0.8]

# 아트 매니페스트 동기화 (콘텐츠 CSV 의 모든 그림 키를 art_assets.csv 에 채움, 새 요괴·방·구역 추가 뒤)
python tools/art/manifest_sync.py

# 웹 Asset Studio (에셋 서재·스프라이트 테스트·화면 배치 A/B·매니페스트 저장) → http://127.0.0.1:8765
python tools/art/studio/server.py
```

그림은 코드에서 파일 경로를 직접 열지 않고 `ArtLibrary` 키(`char.<id>` / `room.<id>` / `region.<id>.sky` …)로만 얻는다. 키 규칙은 `src/core/resources/art_asset_data.gd`, 매니페스트는 `data/csv/art_assets.csv`.

작업 완료 전 반드시 `--import` → 데이터 빌드 → 테스트 순으로 실행하고 결과를 보고한다. 테스트를 돌리지 않고 "될 것이다"라고 보고하지 않는다.

## 4. 디렉터리 구조

```
project.godot
addons/gdUnit4/           # 테스트 프레임워크 (수정 금지)
assets/
  art/                    # 원본 이미지 (에셋팩 원본은 여기, 라이선스 기록 필수)
  art_generated/          # 툴이 생성한 임시/양자화 이미지 (git 추적, 수동 편집 금지)
  audio/
data/
  csv/                    # ★ 콘텐츠 진실 공급원: yokai.csv, guest_species.csv, spirits.csv, rooms.csv, visitors.csv, rumors.csv, items.csv, recipes.csv(요리), dialogue.csv, events.csv, tuning.csv, strings_ko.csv
                          #   + P1 신설: materials.csv, crops.csv, fish.csv, talismans.csv, tools.csv, regions.csv, enemies.csv, unlocks.csv(해금 케이던스), chains.csv(용도 3칸 검증), metrics_events.csv
  resources/              # build_resources.py 가 생성한 .tres (수동 편집 금지)
src/
  autoload/               # Events.gd(이벤트 버스), GameState.gd, DataRegistry.gd, Clock.gd(실시간 하루·시간대 트리거), SaveManager.gd, Metrics.gd(내장 지표 JSONL)
  player/                 # 플레이어 컨트롤러(이동·상호작용·스태미너·도구), 컨텍스트 프롬프트
  core/                   # 노드 의존 없는 순수 로직 (RefCounted): Inventory, Crafting, Economy, RoomGrid, Assignment(배치), Intake(심사), Affinity(호감도), EventLog, (Tier2) ExpeditionSim
  house/                  # 단면 하숙집 씬(걸어다니는 집): 방 슬롯 그리드, 증축 UI, 방 내부
  world/                  # 이승(마당·뒷산·개울)과 마계 탐험지 씬 — regions.csv 로 채집 포인트·적 스포너 조립
  companions/             # 동료 요괴 AI(자동 전투: 근접 교전 + 플레이어 반경 복귀)
  yokai/                  # 요괴 노드(상태머신: 이동→일→휴식), 가택신 NPC
  ui/                     # HUD, 배치 패널, 심사 카드, 대화창(일러스트 표시), 도감
  systems/                # 노드가 필요한 시스템 (DayCycle, Lighting, 사건 스포너)
scenes/                   # .tscn — 노드 구성만. 수치·콘텐츠 넣지 않음
test/
  unit/                   # core/ 대상 gdUnit4 테스트
  integration/            # 씬 로드·세이브 왕복 등
tools/
  data/build_resources.py
  art/validate_assets.py, palette_quantize.py, sheet_slicer.py, atlas_builder.py, gen_placeholder.py
  sim/                    # Python 경제 시뮬레이터 (M3)
docs/
  01_vertical_slice_scope.md
  02_art_sourcing_strategy.md
  decisions/              # ADR: 날짜_제목.md (결정과 이유만 짧게)
  asset_licenses.md
```

## 5. 아키텍처 규약

### 5.1 데이터 주도
- 요괴·가택신·방·방문자·아이템·레시피·대사·이벤트·UI 문자열은 **`data/csv/`에만** 정의한다. GDScript나 .tscn에 콘텐츠 수치를 하드코딩하지 않는다. 밸런스 상수(페이즈 길이, 시설 산출량, 하숙비, 호감도 증가량 등)도 `data/csv/tuning.csv`에 둔다.
- `tools/data/build_resources.py`가 CSV를 검증(필수 컬럼, 키 중복, 참조 무결성)하고 `data/resources/*.tres`를 생성한다. 검증 실패 시 빌드를 중단하고 어느 행이 문제인지 출력한다.
- 런타임은 `DataRegistry` autoload를 통해서만 데이터에 접근한다.
- 새 콘텐츠 추가 = CSV 행 추가 + (필요 시) 아트 파일 추가. 코드 수정이 필요하면 그것은 설계 결함이므로 보고한다.

### 5.2 씬과 스크립트
- 씬(.tscn)은 얇게 유지한다. 노드 트리와 최소한의 export 연결만. 동작은 `.gd`.
- Claude Code는 **.tscn을 직접 편집하지 않는 것을 원칙**으로 한다. 노드 구성이 필요하면 (a) 코드로 `add_child` 조립, (b) `tools/`의 씬 생성 스크립트(EditorScript / `PackedScene.pack()`), (c) 사용자에게 에디터 작업 요청 중 하나를 택하고 이유를 남긴다. 부득이하게 .tscn을 편집하면 `--import`와 씬 로드 스모크 테스트로 깨지지 않았음을 확인한다.
- `.tres`는 툴 생성물만 존재한다. 손으로 만든 .tres가 필요하면 먼저 묻는다.

### 5.3 순수 로직 분리
- `src/core/`의 클래스는 `RefCounted`를 상속하고 노드·씬트리·입력·렌더링에 의존하지 않는다. 이 계층은 전부 단위 테스트 대상이다.
- 노드는 `src/core/`의 객체를 소유하고 시그널로 UI에 전달하는 얇은 어댑터다.

### 5.4 통신
- 시스템 간 통신은 `Events` autoload의 시그널로 한다. 예: `item_added(item_id, count)`, `day_ended(day)`, `cell_changed(coords, block_id)`, `quest_completed(quest_id)`.
- 노드가 다른 노드를 `get_node("../../..")`로 찾지 않는다. `@export` 참조 또는 `Events`.

### 5.5 GDScript 스타일
- **정적 타이핑 필수**: 모든 변수·인자·반환값에 타입을 명시한다. `var x := 0`, `func f(a: int) -> void`.
- `class_name` 부여, 파일명은 snake_case, 클래스명은 PascalCase, 시그널은 과거형 동사(`item_added`), 상수는 UPPER_SNAKE.
- 매직 넘버 금지 → `tuning.csv` 또는 명명 상수.
- 한 파일 300줄을 넘으면 분리 이유를 검토한다.
- 주석은 "왜"만. 무엇을 하는지는 코드가 말하게 한다.

### 5.6 아트 규격 (변경 시 사용자 승인 필요)
- 픽셀 트랙: 격자 16px, 요괴 24×24~32×32 (확정은 `docs/01` 8절), 뷰포트 640×360, 정수 배율 스트레치, Nearest, 2D 픽셀 스냅 ON
- 일러스트 트랙: 도감·대화 원본 1024×1024, 해당 노드만 Linear 필터 예외
- 픽셀 애니메이션 프레임 표준: idle 4 / walk 6 / work 4 / 감정 2종
- 이 규격은 `tools/art/validate_assets.py`가 트랙별 규칙으로 강제한다.

### 5.7 하숙집 구조
- 집은 **방 슬롯 그리드**(층×칸 배열)이며 각 슬롯에 room_id가 놓인다. 자유 타일 건설이 아니다.
- 증축·개조는 `RoomGrid`(core)의 상태 변경 + `Events.room_changed` 발신. 렌더링(`src/house/`)은 그 상태를 구독해 그린다.
- 요괴 이동은 방 그래프 탐색(계단·복도 연결)으로 처리한다. 내비메시를 도입하지 않는다. 플레이어만 CharacterBody2D 물리 이동.
- 탐험지는 `regions.csv` 데이터로 조립한다(수제 씬 하드코딩 금지). 정밀 플랫포밍 금지 — 이동·사다리·단차까지만.
- 직렬화(세이브 v5): 방 배열 + 요괴 상태 + 인벤토리 + 호감도 + 이벤트 로그 + 실시간 시계 + 플레이어 위치 + 탐험지 상태. v4 → v5 마이그레이션 필수.

### 5.8 세이브
- `SaveManager`가 JSON 한 파일로 저장한다. 버전 필드 필수. 스키마 변경 시 마이그레이션 함수를 추가하고 왕복 테스트를 갱신한다.
- `user://saves/slot_N.json`

## 6. 테스트 규약

- `src/core/` 클래스는 **테스트와 함께** 작성한다. 테스트 없는 core 코드는 미완성으로 간주한다.
- 최소 통합 테스트: (1) 메인 씬 headless 로드, (2) 세이브 → 로드 왕복 동일성, (3) CSV 빌드 성공.
- 버그를 고치면 재현 테스트를 먼저 추가한다.
- 플레이 감(이동·상호작용 반응, 부적 투척 타격감, 하루 템포, UI 피드백)은 테스트로 검증할 수 없다. 이 영역은 수치를 `tuning.csv`에 노출하고 사용자에게 "직접 플레이 후 수치 조정 요청"을 명시적으로 넘긴다. 감에 대한 판단을 Claude가 내리지 않는다.
- 새 콘텐츠 추가 = CSV 행 추가로 끝나는지가 상시 검증 대상이다.
- **chains.csv 검증**: 모든 콘텐츠(재료·작물·요리·부적)는 용도 3칸이 차야 한다. 미달 시 build_resources.py 가 빌드를 실패시킨다 (docs/08 재미 원칙 3의 기계 강제).
- **케이던스 검증**: tools/sim/ 의 자동 플레이 시뮬레이터로 unlocks.csv 를 검사해 "처음 보는 것 없는 실플레이 30분"이 없는지 확인한다 (재미 원칙 6).

## 7. Git 규약

- 관심사 단위로 커밋하는 것은 허용. 커밋 메시지는 `type(scope): 요약` (feat / fix / data / art / tool / test / docs / chore).
- **push는 사용자 허락을 받은 뒤에만.**
- `data/resources/`, `assets/art_generated/`는 생성물이지만 git에 포함한다 (Godot 에디터 없이도 clone 직후 실행 가능해야 함).
- `.godot/`은 무시.
- 작업 폴더는 클라우드 동기화 폴더일 수 있다. 동기화 충돌 파일(`* (conflicted copy)`, `*.sync-conflict*`)을 발견하면 즉시 보고하고 임의로 삭제하지 않는다.

## 8. 하지 말 것

- 스코프 문서의 수량을 넘는 콘텐츠·시스템을 "김에" 추가하지 않는다.
- 테스트를 돌리지 않고 완료 보고하지 않는다.
- 에셋팩 원본을 수정하지 않는다 (양자화 결과는 `art_generated/`로).
- 라이선스 미확인 에셋을 `assets/`에 넣지 않는다. 넣을 때 `docs/asset_licenses.md`에 출처·라이선스·구매일을 기록한다.
- AI 생성 이미지를 쓰면 `docs/asset_licenses.md`에 "AI 생성" 표기를 남긴다 (Steam 공개 요구 대응).
- 픽셀 규격·팔레트·프레임 표준을 임의로 바꾸지 않는다.
- `.tscn`/`.tres`를 손으로 대량 편집하지 않는다.

## 9. 세션 시작·종료 루틴

시작: `docs/01` 4절 마일스톤에서 현재 위치 확인 → `docs/decisions/` 최신 3개 읽기 → `git status`, 테스트 실행 → 오늘 할 일 제안 후 착수.
종료: 테스트 통과 확인 → 커밋 → 결정 사항이 있었으면 `docs/decisions/YYYY-MM-DD_제목.md` 작성 → 남은 일·막힌 일·사용자 결정 필요 항목을 3줄로 보고.

## 10. 결정 기록 (ADR) 형식

```
# 제목
날짜:
결정:
이유:
대안과 기각 사유:
영향받는 파일/문서:
```
