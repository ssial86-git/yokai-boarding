# OpenAI gpt-image-1 로 아트 매니페스트 109키 일괄 생성
날짜: 2026-09-18
결정:
- 사용자가 ChatGPT 로 만든 컨셉 4장(`assets/art/concepts/`)을 스타일 레퍼런스로 넣고, `tools/art/ai_prompts.py` 의 발주표(캐릭터 42·방 8·일러스트 17·구역 레이어 33·소품 7·띠 3)를 `tools/art/ai_batch.py` 가 OpenAI 이미지 편집 API(gpt-image-1, quality medium)로 생성한다. 키는 사용자 환경변수 `OPENAI_API_KEY`(코드·로그에 남기지 않음).
- 원본은 `assets/art/ai_raw/*.webp`(손실 q88, 28MB) 에 보관해 재후처리(`--no-generate`, 비용 0)·후보정이 가능하게 하고, 게임 시트는 기존 규칙대로 상자 축소 + 32색 양자화해 `assets/art_generated/ai/` 에 둔다. 캐릭터는 정지 1장에서 18프레임을 합성(import_free_packs 와 같은 방식). 일러스트는 양자화 없이 1024 정사각 256색 PNG(`assets/art/illust/ai_*.png`).
- 후처리 규칙: 투명 출력 실패 시 귀퉁이 색 flood-fill 제거, far/ground/지붕 띠는 12% 교차 혼합으로 가로 반복, 낮 하늘은 양자화 전 파랑 색 곱(`SKY_TINT`) — 팔레트에 연한 하늘색이 적어 연두로 눌리던 문제. 물 2번째 프레임은 AI 대신 8px 밀기.
- UI 9-patch 3키는 Kenney CC0 유지(AI 생성 부적합). CC0 팩 시트는 파일로 남겨 두어 매니페스트에서 키 단위로 되돌릴 수 있다(`import_free_packs.py` 재실행 = 전부 팩으로).

이유: 사용자가 "쓸만한 그래픽"을 요구했고, 무료 팩은 한국 요괴 실루엣·한옥을 못 낸다. 컨셉 레퍼런스 + 발주표 방식이면 코드 수정 없이 프롬프트 행만 고쳐 키 단위로 재생성할 수 있다(5.1 데이터 주도 원칙의 아트 적용). 비용은 115장 ≈ $5.

대안과 기각 사유:
- 컨셉 이미지를 직접 잘라 쓰기: 방 12칸은 가능했지만 캐릭터·배경은 배경 제거·해상도 문제로 품질이 낮다. 레퍼런스로만 쓴다.
- PixelLab(픽셀 애니메이션 API): 프레임 일관성은 더 좋으나 별도 구독. 지금은 정지 1장 합성 애니메이션으로 충분하고, 요괴 핵심 6~8명은 나중에 PixelLab 또는 외주로 교체.

미해결·사용자 결정 필요:
- 이미지 검수: 어둑이·그슨대 등 검은 실루엣은 밤 색조에서 잘 안 보일 수 있다. 달갤(달걀)은 팔레트 탓에 테두리 위주로 보인다. 마음에 안 드는 키는 `ai_prompts.py` 문구를 고치고 `--keys <키> --force` 로 재생성(장당 $0.04).
- AI 생성 표기: `docs/asset_licenses.md` 에 기록됨. 스토어 제출 시 공개 필요.

영향받는 파일/문서: tools/art/{ai_batch,ai_prompts}.py, assets/art/{concepts,ai_raw,illust}/, assets/art_generated/ai/, data/csv/art_assets.csv, docs/asset_licenses.md, CLAUDE.md(명령 추가)
