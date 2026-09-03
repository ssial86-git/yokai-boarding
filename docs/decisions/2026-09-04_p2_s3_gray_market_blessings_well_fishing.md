# P2-S3 — 회색 시장·가호 접붙이기·우물 낚시
날짜: 2026-09-04
결정:
- **회색 시장은 구역 한 행 + 시세 표다.** `regions.csv` 에 `r_gray_market`(realm demon, kind **market** 신설, 우물 아래에서 문, `merchant_x` 컬럼 신설로 장꾼 자리) 을 두고, 문은 `RegionManager.is_region_open_now()` 가 **음기 ≥ tuning `market_yin_threshold`(2) 또는 밤**일 때만 연다(해금 `u_gray_market` 12/13일과 별개). 잠긴 문 문구는 시장 전용("음기 짙은 날이나 밤에만 열린다"). `market_prices.csv`(item_id, sell_mult, buy_mult, swing, stock) 로 판매 배율·구매 배율·하루 흔들림·하루 재고를 데이터로 두고, `MarketPrices`(core) 가 시드·날·아이템에서 파생한 RNG 로 그날 시세를 낸다(방문자 RNG 를 소모하지 않음). 씨앗(배추·마늘·고구마·마계 2종)·천·밥은 사기만, 마계 재료·발효 음식·잉어는 후하게 산다. 하루 구매 재고는 `GameState.market_bought`(취침에 비움).
- **장꾼 NPC** 는 `spirits.csv` 행(gray_merchant)으로 대사 화자를 얻고, 첫 E 는 `events.csv` kind **npc**(시간대 트리거로 뜨지 않도록 `EventScheduler.eligible` 이 건너뜀) 대화 → 효과 `flag:merchant_met` → 이후 E 는 `MarketMenu`(사기 줄 + 팔기 줄, 대문간 대비 ±%).
- **가호는 아이템 id 접미로 산다**: `"<item>@<blessing>"` 합성 id. `DataRegistry.get_item/item_name/recipe_for_dish/get_market_price` 와 `Market` 이 base id 로 풀어 주므로 창고·판매·배식 등 기존 코드가 그대로 동작하고, 이름은 "[뚝] 무 씨앗". `blessings.csv`(하숙생 3명, 호감도 조건, 씨앗 수확/요리 버프/부적 위력 기본 보너스) + `synergies.csv`(문맥 yokai/talisman_effect/crop_realm/recipe_stat × delta, **시너지 6 · 간섭 4**). 최종 효과 = 기본 + 문맥 일치 delta 합, 0 미만은 0 (`BlessingRules`). 적용 지점: 씨앗은 `Farm.Plot.blessing_id` 에 남아 수확 때 +n(문맥 작물 갈래), 요리는 배식 버프 +n(문맥 먹는 하숙생·버프 능력치), 부적은 투척 피해·채집 보너스 +n(문맥 부적 갈래). 텃밭·부적은 가호 붙은 것을 먼저 쓴다.
- **부여 UI**: 하숙생 앞 E → 사연이 없으면 `BlessingMenu`(가호 설명, 대상마다 효과 미리보기 + 시너지/간섭 설명, 부여). 하루 `blessing_per_day`(1)회/하숙생, 해금 `u_blessings`(16일, 뚝딱이 호감도 1). 하숙부 탭에 "가호 n회" 기록(`blessing_log`). chains.csv 에 content_type **blessing** 을 추가해 가호도 3칸 용도를 강제(`farm` 용도 신설).
- **우물 낚시**: `r_well.fishing_x` 로 자리를 두고 `fishing_<region>` feature 해금(`u_well_fishing` 19일)으로 자리를 연다(`FishingSystem.has_spot`). 어종: 고물(trinket) 50 · 기억 조각(record_piece, 밤) 20 · 그늘이끼 9 · **물에 젖은 손님 1**(`fish.visitor_species` 컬럼 신설 → 아이템 대신 그날 밤 우산손이 문을 두드림). "반드시 오는 손님" 플래그는 `IntakeSystem.FLAG_FORCED_VISITOR`(값 = 종족 id) 로 일반화해 명절 만점과 공유한다.
- **세이브 v8**: blessings_today / blessing_log / market_bought. 시뮬레이터는 시장 개장 뒤 채집 수입에 재료 행 평균 배율을 곱한다.

이유:
- 회색 시장은 "음기 짙은 날에 할 일" 을 하나 더 만들고(달력 확인 유도 — P2 게이트), 씨앗 공급 문제(달무리 참외 등이 손님 하숙비로만 들어오던 것)를 데이터로 푼다.
- 합성 id 방식은 인벤토리 스키마(id→개수)와 세이브를 바꾸지 않고 "가호 붙은 물건" 을 표현하는 가장 작은 변경이다. 대안(별도 blessed 목록)은 소비 지점마다 두 컬렉션을 맞춰야 했다.
- 시너지·간섭을 문맥 표로 둔 것은 P3 의 하숙생 10명 × 대상 3종 조합이 CSV 행으로 끝나게 하려는 것.

대안과 기각 사유:
- 시장 시세를 실시간 변동: 하루 단위 결정성이 테스트·세이브에 유리하고 "달력을 보고 온다" 는 안내와 맞다.
- 가호를 하숙생 배치(방)로 자동 부여: 직접 조작(재미 원칙 1) 에 어긋난다. E 메뉴로.
- 장꾼을 yokai.csv 행으로: 하숙생 로스터·배치에 섞인다. spirits(가택신·NPC) 로.

미해결·사용자 결정 필요:
- 시세 배율·흔들림·재고, 가호 보너스·시너지 값은 초안. 마계 씨앗 구매가(×2.5)가 초반 자금에 비해 높은지 플레이 후 판단.
- 회색 장꾼의 "소문" 은 P2-S4 챕터 1 에서 붙인다(대화에 예고만).
- 장꾼·시장 배경은 팔레트 사각 자리표시 — docs/02 아트 트랙.

영향받는 파일/문서: data/csv/{blessings,synergies,market_prices}.csv(신설), {regions,fish,items,spirits,dialogue,events,chains,unlocks,metrics_events,tuning,strings_ko}.csv, tools/data/build_resources.py, tools/sim/autoplay.py, src/core/{blessing_rules,market_prices}.gd(신설), src/core/{farm,market,event_scheduler}.gd, src/core/resources/{blessing_data,synergy_data,market_price_data}.gd(신설), {region_data,fish_data}.gd, src/systems/{blessing_system,market_system}.gd(신설), src/systems/{station_system,expedition_system,fishing_system,intake_system,festival_system}.gd, src/world/{farm_system,region_manager,region_view}.gd, src/autoload/{game_state,save_manager,events,data_registry}.gd, src/ui/{blessing_menu,market_menu}.gd(신설), src/ui/menu_hub.gd, src/main.gd, test/unit/test_blessing_market.gd, test/integration/{test_market_blessing,test_save_roundtrip,test_data_build}.gd, test/tools/playthrough_check.gd, docs/verification_checklist.md
