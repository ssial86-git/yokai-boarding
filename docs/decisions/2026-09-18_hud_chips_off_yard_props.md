# HUD 칩 위치 이동 — 마당 소품을 덮지 않게
날짜: 2026-09-18
결정:
- 메시지 토스트(MessageLog)를 왼쪽 아래 → **왼쪽 위(시계 카드 아래)** 로 옮기고 아래로 쌓는다. 하한은 tuning `message_log_bottom_ratio`(0.44 = 마당 소품 위 y≈158). 기존 `message_log_top_ratio` 는 삭제. 한 줄 폭은 0.29 → 0.27(성주 영감 안내 줄 왼쪽에서 끝나도록).
- E 안내 알약·탐험 조작 칩을 오른쪽 아래 → **오른쪽 위(취침·메뉴 버튼 아래)** 로. `Hud.set_prompt_bottom` → `layout_chips(top, bottom)`. 체력 바는 그대로 왼쪽 아래(패널 위).
- 성주 영감 안내 줄 폭 0.6 → 0.4(집 단면 폭). 왼쪽 위 토스트와 겹치지 않는다.
- 플레이스루에 `prompt_above_props`·`log_above_props` 검사 추가(카메라 기준 바닥선 - 64px 위). 스튜디오 HUD 모의도 같은 배치.

이유: 집 양옆 마당 소품(prop.house_deco_left/right, 바닥선 위 64px)을 왼쪽 토스트와 오른쪽 E 알약이 덮었다(사용자 지적). 화면 위쪽(카드 줄 아래 ~ 지붕 위)만 비어 있어 그리로 올렸다.

대안과 기각 사유:
- 소품을 더 바깥으로: 카메라가 집 중심 고정이라 화면 밖으로 나간다.
- 토스트를 집 위(가운데)에: 성주 영감 안내 줄 자리와 충돌.

영향받는 파일/문서: src/main.gd, src/ui/{hud,message_log}.gd, data/csv/tuning.csv, test/tools/playthrough_check.gd, docs/verification_checklist.md, tools/art/studio/app.js
