# 무료 CC0 팩으로 아트 매니페스트 104키 임시 충전
날짜: 2026-09-04
결정:
- 정식 에셋이 오기 전까지 **CC0 팩(Kenney 5종, ansimuz 3종, stealthix 슬라임)** 에서 게임 규격 시트를 조립해 `art_assets.csv` 104키 전부를 실제 그림으로 채운다. 원본은 `assets/art/packs/<pack>/`(라이선스 파일 동봉, 수정 금지), 산출물은 `assets/art_generated/packs/`(재생성 가능), 조립기는 `tools/art/import_free_packs.py`, 팔레트 양자화는 `tools/art/palette_quantize.py`.
- **팔레트 강제 유지**: 팩 색을 32색 공통 팔레트로 양자화한다(validate_assets.py 통과). 마계·시장은 양자화 전 색 곱(tint)으로 톤을 나눈다.
- **밀도 통일 임시 규칙**: 16px 원본을 32 크기 개체(요괴·NPC·플레이어·큰 적)에 쓸 때 2배 최근접 확대. 16 크기 개체(소형 손님·소형 적)는 원본 그대로.
- **애니메이션 합성**: 정지 1장에서 idle 4(들썩)/walk 6(다리 좌우 밀기)/work 4(흔들림)/joy 2/sad 2 를 만든다. 슬라임은 팩의 idle·이동 프레임을 그대로 쓴다. 시트 표준(가로 18프레임)과 `anims` 문법은 정식 에셋과 동일하므로 키 단위로 갈아 끼우면 된다.
- 일러스트 17장은 스프라이트 24배 확대 자리표시(1024) — 정식 일러스트가 오면 교체.

이유: 사용자가 "게임의 느낌"을 실제 그림으로 판단하려면 모든 키가 채워져야 하고, 무료·상업 이용 가능(CC0)이어야 스토어 리스크가 없다. 매니페스트·폴백 구조 덕분에 코드 수정 없이 CSV·이미지만으로 끝났다.

대안과 기각 사유:
- itch.io 유료/무료 팩(0x72 DungeonTileset II 등): 다운로드가 로그인·클릭 기반이라 자동화 불가. 사용자가 직접 받아 `assets/art/packs/` 에 넣으면 조립기 매핑만 추가하면 된다.
- 팔레트 검증 해제: 규격 원칙(CLAUDE.md 5.6) 훼손. 양자화 결과가 다소 탁하지만 톤 통일이 더 중요.

미해결·사용자 결정 필요:
- 방 바닥이 팔레트 탓에 주황빛이 강함. 팔레트 재설계(docs/02 6절)는 사람이 결정.
- 한국 요괴 실루엣은 Kenney 몬스터로 대체 중(뚝딱이=주황 뿔 괴물, 어둑이=유령 …). 핵심 요괴 6~8명은 docs/10 권고대로 AI 초안·외주로 교체.

영향받는 파일/문서: assets/art/packs/**, assets/art_generated/packs/**, data/csv/art_assets.csv, tools/art/{import_free_packs,palette_quantize}.py, docs/asset_licenses.md, CLAUDE.md(명령 추가)
