# 에셋 출처·라이선스 대장

규칙 (CLAUDE.md 8절): 라이선스 미확인 에셋은 `assets/` 에 넣지 않는다. 넣을 때 이 표에 출처·라이선스·구매일을 기록한다. AI 생성 이미지는 "AI 생성" 을 명기한다 (Steam 공개 요구 대응).

| 경로 | 종류 | 출처 | 라이선스 | 취득일 | AI 생성 | 비고 |
|---|---|---|---|---|---|---|
| `data/palette.hex` | 팔레트 32색 | 프로젝트 자체 구성 (Claude Code 초안) | 프로젝트 소유 | 2026-09-02 | 아니오 (수치 직접 지정) | 임시. 정식 팔레트는 슬라이스 후 사람이 재설계 (docs/02 6절) |
| `assets/art_generated/*.png` | 임시 스프라이트 | `tools/art/gen_placeholder.py` 생성 (색 블록+라벨) | 프로젝트 소유 | 2026-09-02 | 아니오 (절차적 생성) | 재생성 가능한 툴 산출물. 수동 편집 금지 |
| `assets/audio/generated/*.wav` | 임시 효과음 9종 | `tools/audio/gen_placeholder_audio.py` 합성 (사인파·노이즈) | 프로젝트 소유 | 2026-09-02 | 아니오 (절차적 생성) | 재생성 가능한 툴 산출물. 정식 사운드로 교체 예정 |
| `icon.svg` | 프로젝트 아이콘 | 직접 작성 (단순 도형) | 프로젝트 소유 | 2026-09-02 | 아니오 | 임시 |
| `addons/gdUnit4/` | 테스트 프레임워크 | github.com/godot-gdunit-labs/gdUnit4 v6.2.1 | MIT (`addons/gdUnit4/LICENSE`) | 2026-09-02 | — | 코드. 에셋 아님 |
