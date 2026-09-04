# 에셋 출처·라이선스 대장

규칙 (CLAUDE.md 8절): 라이선스 미확인 에셋은 `assets/` 에 넣지 않는다. 넣을 때 이 표에 출처·라이선스·구매일을 기록한다. AI 생성 이미지는 "AI 생성" 을 명기한다 (Steam 공개 요구 대응).

| 경로 | 종류 | 출처 | 라이선스 | 취득일 | AI 생성 | 비고 |
|---|---|---|---|---|---|---|
| `data/palette.hex` | 팔레트 32색 | 프로젝트 자체 구성 (Claude Code 초안) | 프로젝트 소유 | 2026-09-02 | 아니오 (수치 직접 지정) | 임시. 정식 팔레트는 슬라이스 후 사람이 재설계 (docs/02 6절) |
| `assets/art_generated/*.png` | 임시 스프라이트 | `tools/art/gen_placeholder.py` 생성 (색 블록+라벨) | 프로젝트 소유 | 2026-09-02 | 아니오 (절차적 생성) | 재생성 가능한 툴 산출물. 수동 편집 금지 |
| `assets/audio/generated/*.wav` | 임시 효과음 9종 | `tools/audio/gen_placeholder_audio.py` 합성 (사인파·노이즈) | 프로젝트 소유 | 2026-09-02 | 아니오 (절차적 생성) | 재생성 가능한 툴 산출물. 정식 사운드로 교체 예정 |
| `icon.svg` | 프로젝트 아이콘 | 직접 작성 (단순 도형) | 프로젝트 소유 | 2026-09-02 | 아니오 | 임시 |
| `addons/gdUnit4/` | 테스트 프레임워크 | github.com/godot-gdunit-labs/gdUnit4 v6.2.1 | MIT (`addons/gdUnit4/LICENSE`) | 2026-09-02 | — | 코드. 에셋 아님 |
| `assets/art/packs/kenney_tiny_dungeon/` | 픽셀 타일·캐릭터 시트 (Tiny Dungeon 1.0) | Kenney, kenney.nl/assets/tiny-dungeon | CC0 (동봉 License.txt) | 2026-09-04 | 아니오 | 요괴·손님·NPC·적·문 자리 임시 |
| `assets/art/packs/kenney_tiny_town/` | 픽셀 마을 타일 (Tiny Town) | Kenney, kenney.nl/assets/tiny-town | CC0 (동봉 License.txt) | 2026-09-04 | 아니오 | 빈터·채집물·마을 원경·장꾼 간판 |
| `assets/art/packs/kenney_pixel_platformer_farm/` | 농장 타일 (Pixel Platformer Farm Expansion) | Kenney, kenney.nl/assets/pixel-platformer-farm-expansion | CC0 (동봉 License.txt) | 2026-09-04 | 아니오 | 텃밭 4단계 |
| `assets/art/packs/kenney_pixel_ui/` | UI 9-slice (Pixel UI Pack, Ancient) | Kenney, kenney.nl/assets/pixel-ui-pack | CC0 (동봉 License.txt) | 2026-09-04 | 아니오 | 패널·칩·버튼 |
| `assets/art/packs/kenney_roguelike_indoors/` | 실내 가구 타일 (Roguelike Indoors) | Kenney, kenney.nl/assets/roguelike-indoors | CC0 (동봉 License.txt) | 2026-09-04 | 아니오 | 방 8칸 64×48 조립 |
| `assets/art/packs/ansimuz_parallax_forest/` | 숲 패럴랙스 레이어 | Luis Zuno (ansimuz), opengameart.org/content/forest-background | CC0 (동봉 license.txt) | 2026-09-04 | 아니오 | 뒷산·개울·달무리 늪 원경 |
| `assets/art/packs/ansimuz_parallax_mountain/` | 산 패럴랙스 레이어 | Luis Zuno (ansimuz), opengameart.org/content/mountain-at-dusk-background | CC0 (동봉 license.txt) | 2026-09-04 | 아니오 | 마당·잿빛 들·문서고 원경 |
| `assets/art/packs/ansimuz_country_platform/` | 시골 플랫폼 타일·배경 | Luis Zuno (ansimuz), opengameart.org/content/country-side-platform-tiles | CC0 (동봉 license.txt) | 2026-09-04 | 아니오 | 풀 바닥 타일 |
| `assets/art/packs/oga_slimes/` | 16×16 슬라임 애니메이션 6종 | stealthix, opengameart.org/content/16x16-animated-slimes | CC0 (페이지 표기) | 2026-09-04 | 아니오 | 소형 적 4종·늪어미 |
| `assets/art_generated/packs/*.png` | 위 팩에서 조립·팔레트 양자화한 게임 규격 시트 | `tools/art/import_free_packs.py` 산출물 | 원본 CC0 → 파생물 프로젝트 소유 | 2026-09-04 | 아니오 | 재생성 가능. 수동 편집 금지. 정식 에셋으로 키 단위 교체 예정 |
