# 아트 매니페스트(art_assets.csv)·ArtLibrary·웹 Asset Studio
날짜: 2026-09-04
결정:
- **그림은 전부 논리 키로 꽂는다.** `data/csv/art_assets.csv`(key, track, file, frame_w/h, anims, parallax, repeat, note)가 `char.<하숙생>` / `guest.<종족>` / `enemy.<적>` / `npc.<NPC>` / `room.<방>` / `illust.<id>` / `region.<구역>.sky|far|ground` / `prop.<gather_point|farm_plot|door|water|merchant>` / `ui.<panel|chip|button>` 키를 파일과 시트 규격(프레임 크기, `idle:0-3:6;walk:4-9:10;work:…;joy:…;sad:…`)에 맵한다. `tools/art/manifest_sync.py` 가 콘텐츠 CSV 에서 키 목록을 뽑아 빠진 행을 자리표시(art_generated)로 채우고, 빌드가 파일 실재·프레임 나눗셈·구간 범위를 검증한다.
- **런타임은 `ArtLibrary`(core, 정적 캐시) 하나만 거친다**: 키 → Texture2D / 첫 프레임 아이콘 / SpriteFrames / 발이 원점인 AnimatedSprite2D. 행이 없거나 파일이 없으면 자리표시로 폴백하고, 자리표시도 없는 키(적·소품·배경·UI)는 null 을 돌려 렌더러가 코드 그림(사각·원·색 상자)을 그린다. 그래서 **에셋을 하나씩 갈아 끼워도 게임이 늘 돈다**.
- **렌더 층 교체**: 요괴·손님 액터, 플레이어, 동료, 적, 구역 NPC 가 AnimatedSprite2D(상태 → idle/walk/work, 없으면 idle 유지, work 가 없으면 자리표시 들썩임 유지); 방 그림·대화 초상·카드/심사 아이콘이 매니페스트 키; 구역 배경은 sky(늘림)·far(가로 반복)·ground(평평한 구간 위 띠 반복) 3레이어; 문·물·채집물·텃밭 소품은 프레임 인덱스로 상태(열림/잠김, 빈 칸/갈아 둠/자라는 중/다 자람); UI 패널·칩은 `ui.*` 9-patch 가 있으면 텍스처 스타일. 자리표시 화면은 이전과 동일(플레이스루 90/90).
- **웹 Asset Studio** (`python tools/art/studio/server.py` → http://127.0.0.1:8765): 로컬 서버가 저장소를 읽고 쓴다. 네 탭 — 서재(에셋 목록·16px 격자/일러스트 1024/팔레트 검사·업로드 시 `docs/asset_licenses.md` 자동 기록), 스프라이트(시트 프레임 격자·구간 재생·배율·발 기준선), 화면(하숙집 단면·모든 구역을 regions/tuning 수치로 640×360 에 배치, HUD·배치 패널 모의, 시간대 색조 곱, 카메라 x, 슬롯에 에셋 드롭, **A/B** 후보 토글 `b`), 매니페스트(행 편집·저장 → 서버가 CSV 쓰고 `build_resources.py` 실행 → 게임 재실행 시 반영, 규격 검증 버튼).

이유:
- 사용자가 "실제 화면 구성을 보고 판단" 하려면 에셋 교체가 코드 수정 없이, 그리고 게임 화면 수치 그대로 이뤄져야 한다. 매니페스트 + 폴백 구조는 CLAUDE.md 5.1(데이터 주도)과 5.6(규격 강제)을 아트에도 적용한 것.
- 웹으로 만든 이유: Godot 에디터 없이 브라우저에서 바로 비교·업로드·라이선스 기록. 한계(조명·셰이더 미재현, 로컬 서버 필요)는 docs/10 과 서버 docstring 에 명시.

대안과 기각 사유:
- Godot 에디터 플러그인: 에디터 실행·.tscn 편집이 필요하고 CLAUDE.md 5.2 원칙과 충돌. 비교·업로드 UX 도 브라우저가 낫다.
- SpriteFrames .tres 를 툴로 생성해 커밋: 시트 규격만 CSV 에 두면 .tres 없이 런타임에 만들 수 있어 손 편집·중복이 없다.

미해결·사용자 결정 필요:
- 화면 컴포저의 HUD 는 모의(글자·상자)라 실제 UI 와 1~2px 차이가 있을 수 있다. 정확한 비교는 게임 스크린샷(playthrough_check)과 병행.
- 배경 레이어의 시차(parallax)는 게임에 아직 카메라 연동이 없다(정적 반복). 실제 에셋이 들어오면 카메라 오프셋 연동 추가.
- 실제 에셋 조달은 docs/10 권고에 따라 사용자 결정(구매·AI·외주).

영향받는 파일/문서: data/csv/art_assets.csv(신설, 104행), tools/art/{manifest_sync.py,studio/server.py,studio/index.html,studio/app.js}(신설), tools/data/build_resources.py, src/core/art_library.gd(신설), src/core/resources/art_asset_data.gd(신설), src/autoload/data_registry.gd, src/yokai/{yokai_actor,yokai_manager}.gd, src/player/player_controller.gd, src/companions/companion_actor.gd, src/systems/expedition_system.gd, src/world/{enemy_actor,gather_point_node,farm_plot_node,region_view}.gd, src/house/house_view.gd, src/ui/{dialogue_box,assignment_panel,intake_panel,ui_styles}.gd, test/integration/test_art_library.gd, docs/10_asset_sourcing_recommendations.md, CLAUDE.md(명령 추가)
