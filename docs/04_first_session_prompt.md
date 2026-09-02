# 04. Claude Code 첫 세션 프롬프트 v2 (M0 셋업 — 요괴 하숙집)

사용 방법: 빈 폴더에 `docs/00~07` 문서와 `CLAUDE.md`(03 파일 이름 변경)를 넣고 Claude Code 실행 후 아래를 붙여 넣는다. Godot 경로는 실제 경로로 교체.

사전 준비 (사람이 직접):
1. Godot 4.7 stable(콘솔 버전 포함) 설치
2. `git init` + 원격 저장소 (권장 슬러그: `yokai-boarding`)
3. Python 3 + `pip install pillow pandas`
4. (미결 없음 — 아트 규격 등은 01 문서 8절의 작업 기본값 채택됨: 요괴 32px, 뷰포트 640×360, 낮 페이즈 4분)

---

## M0 프롬프트

```
이 저장소는 Godot 4.7 기반 '요괴 하숙집'(단면 뷰 경영 시뮬)의 수직 슬라이스 프로젝트다.
CLAUDE.md 를 먼저 읽고, docs/00(컨셉)·01(스코프)·06(로스터)·07(심사)을 훑은 뒤 시작해라.

환경:
- Windows PowerShell. Godot 실행 파일: <경로> (환경변수 GODOT_BIN 등록)
- Python 3, pillow, pandas 설치됨
- 아트 규격 확정: 격자 16px, 요괴 32×32 (뜨내기 소형종 16×16 허용), 뷰포트 640×360

이번 세션 목표는 마일스톤 M0(셋업) 완료다. 순서:

1. 착수 전에 작업 계획을 파일 목록 수준으로 보여 주고, 승인 후 진행해라.
2. Godot 프로젝트 생성. CLAUDE.md 5.6의 픽셀 설정을 project.godot 에 반영해라.
3. CLAUDE.md 4절 디렉터리 구조 생성 (빈 폴더는 .gitkeep).
4. Autoload 골격: Events, GameState, DataRegistry, Clock(아침/낮/저녁/밤 페이즈), SaveManager — 시그니처만, 정적 타이핑.
5. gdUnit4 v6.x 설치, `.\addons\gdUnit4\runtest.cmd -a res://test` 로 예제 테스트 통과 확인(종료 코드 0). 래퍼가 요구하는 환경변수는 스크립트를 읽고 확인해 CLAUDE.md 3절을 실제 동작 형태로 수정해라.
6. tools/data/build_resources.py: data/csv/ 의 yokai.csv, guest_species.csv, rooms.csv, tuning.csv 를 읽어 .tres 생성하는 최소 구현 + 검증(필수 컬럼·키 중복·참조 무결성). 샘플 행: 하숙생은 docs/06 의 뚝딱이·어둑이·달갤 3행(능력치 4종 힘/재주/눈/담력 포함), 뜨내기는 docs/06 4절의 4종족, 방은 객실·주방·작업장·대문간·창고·빈터 6행. 스키마는 docs/decisions/ 에 ADR로 남겨라.
7. tools/art/validate_assets.py (트랙별 규격: 픽셀 16px 격자 / 일러스트 1024px) + data/palette.hex (임시 32색 저채도 팔레트, 출처 표기).
8. tools/art/gen_placeholder.py: yokai.csv·rooms.csv 를 읽어 규격에 맞는 색 블록+라벨 임시 스프라이트를 assets/art_generated/ 에 생성.
9. test/integration/test_smoke.gd: 메인 씬 headless 로드 1프레임 테스트.
10. GitHub Actions CI: --import → build_resources.py → validate_assets.py → gdUnit4 순서.
11. 전부 실제로 실행해 통과 로그를 보여 준 뒤 관심사 단위로 커밋해라. push 는 하지 마라.

주의:
- .tscn 은 메인 씬 1개만. 나머지는 코드 조립 (CLAUDE.md 5.2).
- M1 항목(방 그리드 렌더링, 증축 UI)은 이번 세션에 만들지 마라.
- 확실하지 않은 것은 추측하지 말고 확인 후 진행, 확인 못 한 항목은 마지막에 목록으로 보고.
- 종료 시 CLAUDE.md 9절 루틴대로 3줄 보고.
```

## M1 프롬프트 (참고용 — M0 완료 후)

```
M0 완료 상태다. CLAUDE.md 9절 시작 루틴 후 M1(하숙집 뷰·증축)을 시작해라.

이번 세션 범위:
- src/core/RoomGrid: 층×칸 배열(최대 3×4), 방 설치·개조·철거 로직과 비용 검증. 순수 클래스 + 단위 테스트.
- src/house/: RoomGrid 상태를 구독해 단면을 그리는 씬. 방 = rooms.csv 기반, 임시 스프라이트 사용.
- 증축 UI: 빈터 클릭 → 방 종류 선택 → 비용 지불 → 설치. Events.room_changed 발신.
- 카메라: 마우스 휠 줌 + 드래그 스크롤, 집 경계 클램프, 픽셀 스냅 유지.
- 조명: CanvasModulate 로 하루 페이즈별 색조 변화 (Clock 연동), 방 안 등불 PointLight2D 1종.
- 세이브: RoomGrid 직렬화 왕복 테스트.

UI의 손맛(클릭 반응, 하이라이트, 트랜지션 시간)은 수치를 tuning.csv 에 노출하고
기본값만 넣은 뒤 나에게 직접 플레이 후 조정을 요청해라.
완료 조건은 docs/01 4절 M1 행: 3층 증축·저장 왕복 무결.
```
