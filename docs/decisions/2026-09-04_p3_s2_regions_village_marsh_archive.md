# P3-S2 — 지역 4: 마을 상점가·달무리 늪·문서고 외곽 + 상점 일반화
날짜: 2026-09-04
결정:
- **구역 3행 추가로 지역 4 를 채웠다** (regions.csv): 마을 상점가 `r_village`(이승, kind **village** 신설 — 밤에 닫힘, tuning `village_closed_band`), 달무리 늪 `r_moon_marsh`(마계 탐험지, 회색 시장 너머, 채집 6·적 3·보스 늪어미·낚시 자리, 밤 변형 늪귓것 4), 문서고 외곽 `r_archive_gate`(마계 탐험지, 잿빛 들 심부 너머, 단차 바닥, 채집 6·적 4·보스 **회수 집행관**, 밤 변형 장부 불꽃 5). 문은 기존 행의 doors 에 추가(마당 160 → 마을, 회색 시장 448 → 늪, 심부 608 → 외곽). 적 8행(보스 2), 마계 재료 6, 늪 어종 3 — chains 3칸.
- **상점을 일반화했다**: regions 의 `merchant_x` 를 `npcs`("spirit_id:shop_id:x" 목록)로 바꿔 구역에 NPC 여럿을 두고, `market_prices.csv` 에 `shop` 컬럼(id = "<shop>_<item>")을 넣어 상점별 시세·재고를 갈랐다(회색 시장 gray / 마을 잡화점 village / 약방 apothecary). `MarketSystem`·`MarketMenu` 는 shop_id 를 받고, 하루 재고는 시세 행 id 로 상점마다 따로 산다. NPC 첫 인사 규칙은 `ev_<npc>_greet` 이벤트 + `<npc>_met` 플래그로 통일(회색 장꾼의 merchant_met → gray_merchant_met 로 개명, 챕터 1 게이트·이벤트도 함께).
- 마을 잡화상은 이승 씨앗(제철 8종)·밥·천을 회색 시장보다 싸게 팔고 곡식·발효 음식을 사며, 약방 할미는 약초·샘물을 팔고 약초·나물·물고기·약초차를 산다. 마을 NPC 대화는 아버지의 흔적을 한 줄씩 흘린다(초안).
- unlocks 57~84일을 30분 규칙으로 채우고(마을 58·늪 63·늪등불 65·외곽 68·골렘 70·집행관 72·밤 늪 76·밤 외곽 80·늪진주 82·빛장어 84) 시뮬레이터 기본 일수 84.

이유:
- P2 에서 만든 파생 리소스(밤 변형)·표 기반 시세·NPC 인터랙터블이 있어 지역 3개가 CSV 행 + 문 추가로 끝났다. 유일한 구조 변경은 "구역당 NPC 하나" 가정을 깬 것 — 마을 상점가는 상점 둘이 있어야 이승 경제(싼 씨앗 vs 마계 프리미엄)가 대비된다.
- 문서고 외곽의 보스를 회수 집행관으로 둔 것은 챕터 1 서사(감사)와 챕터 2 게이트(문서고) 를 공간으로 잇기 위해서.

대안과 기각 사유:
- 마을을 kind market 으로 두고 개장 조건만 다르게: 조건이 정반대(낮 vs 밤·음기)라 kind 를 나누는 게 데이터에서 읽기 쉽다.
- 상점별 CSV 파일(market_gray.csv…): 테이블이 늘고 검증 코드가 복제된다. shop 컬럼으로.

미해결·사용자 결정 필요:
- 마을 상점가는 P4 위장/인간 NPC 의 무대다 — 지금은 NPC 가 요괴 손님을 "묻지 않는" 대사만. 인간 NPC 상호작용은 만들지 않았다.
- 늪·외곽 적 능력치·드롭 확률·시세는 초안. 문서고 외곽(진입 20)은 동료 없이는 버티기 어렵게 잡았다.
- 새 구역·NPC 그림은 자리표시.

영향받는 파일/문서: data/csv/{regions,enemies,items,materials,fish,chains,market_prices,spirits,dialogue,events,goals,unlocks,tuning,strings_ko}.csv, tools/data/build_resources.py(npcs·shop), tools/sim/autoplay.py(84일), src/core/market_prices.gd, src/core/resources/{region_data,market_price_data}.gd, src/autoload/data_registry.gd, src/systems/market_system.gd, src/ui/market_menu.gd, src/world/{region_view,region_manager}.gd, src/main.gd, test/integration/{test_regions_p3,test_chapter_night,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
