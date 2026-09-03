class_name TestBlessingMarket
extends GdUnitTestSuite
## 가호 접붙이기(합성 id·효과·시너지/간섭·부여 규칙)와 회색 시장 시세(결정성·범위·구매·재고·개장) 순수 로직 (P2-S3).


func _blessing(id: String, seed_bonus: int, dish_bonus: int, talisman_bonus: int, affinity_min: int = 1) -> BlessingData:
	var blessing := BlessingData.new()
	blessing.id = id
	blessing.yokai_id = "y_" + id
	blessing.affinity_min = affinity_min
	blessing.seed_yield_bonus = seed_bonus
	blessing.dish_buff_bonus = dish_bonus
	blessing.talisman_power_bonus = talisman_bonus
	return blessing


func _synergy(id: String, blessing_id: String, kind: String, context_id: String, delta: int) -> SynergyData:
	var synergy := SynergyData.new()
	synergy.id = id
	synergy.blessing_id = blessing_id
	synergy.context_kind = kind
	synergy.context_id = context_id
	synergy.delta = delta
	return synergy


func _item(id: String, kind: String, value: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.name_ko = id
	item.kind = kind
	item.base_value = value
	return item


func _row(item_id: String, sell_mult: float, buy_mult: float, swing: float, stock: int) -> MarketPriceData:
	var row := MarketPriceData.new()
	row.id = item_id
	row.item_id = item_id
	row.sell_mult = sell_mult
	row.buy_mult = buy_mult
	row.swing = swing
	row.stock = stock
	return row


func test_composite_ids() -> void:
	var id := BlessingRules.compose("seed_radish", "b_ttuk")
	assert_str(id).is_equal("seed_radish@b_ttuk")
	assert_bool(BlessingRules.is_blessed(id)).is_true()
	assert_bool(BlessingRules.is_blessed("seed_radish")).is_false()
	assert_str(BlessingRules.base_id(id)).is_equal("seed_radish")
	assert_str(BlessingRules.base_id("seed_radish")).is_equal("seed_radish")
	assert_str(BlessingRules.blessing_of(id)).is_equal("b_ttuk")
	assert_str(BlessingRules.blessing_of("seed_radish")).is_equal("")


func test_target_kinds() -> void:
	assert_str(BlessingRules.target_kind(_item("s", "seed", 1), false)).is_equal("seed")
	assert_str(BlessingRules.target_kind(_item("d", "food", 1), true)).is_equal("dish")
	assert_str(BlessingRules.target_kind(_item("meal", "food", 1), false)).is_equal("")  # 레시피 없는 음식은 대상 아님
	assert_str(BlessingRules.target_kind(_item("t", "talisman", 1), false)).is_equal("talisman")
	assert_str(BlessingRules.target_kind(_item("m", "material", 1), false)).is_equal("")
	assert_str(BlessingRules.target_kind(null, false)).is_equal("")


func test_bonus_with_synergy_and_interference_clamped() -> void:
	var ttuk := _blessing("b_ttuk", 1, 1, 2)
	var synergies := {
		"a": _synergy("a", "b_ttuk", "talisman_effect", "throw", 2),
		"b": _synergy("b", "b_ttuk", "crop_realm", "demon", -1),
		"c": _synergy("c", "b_ttuk", "yokai", "y03", -1),
		"d": _synergy("d", "b_other", "talisman_effect", "throw", 5),  # 다른 가호의 행
	}
	assert_int(BlessingRules.bonus(ttuk, "talisman", synergies, {"talisman_effect": "throw"})).is_equal(4)
	assert_int(BlessingRules.bonus(ttuk, "talisman", synergies, {"talisman_effect": "gather"})).is_equal(2)
	assert_int(BlessingRules.bonus(ttuk, "seed", synergies, {"crop_realm": "demon"})).is_equal(0)  # 1 - 1
	assert_int(BlessingRules.bonus(ttuk, "seed", synergies, {"crop_realm": "mortal"})).is_equal(1)
	assert_int(BlessingRules.bonus(ttuk, "dish", synergies, {"yokai": "y03", "recipe_stat": "strength"})).is_equal(0)
	assert_int(BlessingRules.bonus(ttuk, "dish", synergies, {"yokai": "y01"})).is_equal(1)
	assert_int(BlessingRules.bonus(null, "dish", synergies, {})).is_equal(0)
	var weak := _blessing("b_weak", 0, 0, 0)
	synergies["e"] = _synergy("e", "b_weak", "recipe_stat", "sight", -3)
	assert_int(BlessingRules.bonus(weak, "dish", synergies, {"recipe_stat": "sight"})).is_equal(0)  # 음수는 0 으로
	assert_int(BlessingRules.matching_synergies("b_ttuk", synergies, {"talisman_effect": "throw", "crop_realm": "demon"}).size()).is_equal(2)


func test_grant_rules_and_inventory_variants() -> void:
	var blessing := _blessing("b_ttuk", 1, 1, 1, 2)
	assert_bool(BlessingRules.can_grant(1, blessing, 0, 1)).is_false()  # 호감도 부족
	assert_bool(BlessingRules.can_grant(2, blessing, 0, 1)).is_true()
	assert_bool(BlessingRules.can_grant(5, blessing, 1, 1)).is_false()  # 오늘 다 붙였다
	assert_bool(BlessingRules.can_grant(5, null, 0, 1)).is_false()
	var inventory := Inventory.new()
	inventory.add("seed_radish", 3)
	assert_bool(BlessingRules.grant(inventory, "seed_radish", "b_ttuk")).is_true()
	assert_int(inventory.get_count("seed_radish")).is_equal(2)
	assert_int(inventory.get_count("seed_radish@b_ttuk")).is_equal(1)
	assert_bool(BlessingRules.grant(inventory, "seed_radish@b_ttuk", "b_dal")).is_false()  # 이미 가호가 붙음
	assert_bool(BlessingRules.grant(inventory, "seed_cabbage", "b_ttuk")).is_false()  # 없음
	assert_array(BlessingRules.variants_in(inventory, "seed_radish")).contains_exactly(["seed_radish@b_ttuk", "seed_radish"])
	assert_int(BlessingRules.count_variants(inventory, "seed_radish")).is_equal(3)
	assert_int(BlessingRules.count_variants(inventory, "seed_cabbage")).is_equal(0)


func test_market_prices_deterministic_and_within_swing() -> void:
	var item := _item("m_moss", "material", 20)
	var row := _row("m_moss", 1.5, 0.0, 0.3, 0)
	var gate := Market.unit_price(item, 0.6)  # 12
	assert_int(gate).is_equal(12)
	var seen_min := 999
	var seen_max := 0
	for day in range(1, 60):
		var price := MarketPrices.sell_price(item, row, 0.6, 1.0, 42, day)
		assert_int(price).is_equal(MarketPrices.sell_price(item, row, 0.6, 1.0, 42, day))  # 같은 날 같은 값
		seen_min = mini(seen_min, price)
		seen_max = maxi(seen_max, price)
	# 12 × 1.5 × [0.7, 1.3] = [12.6, 23.4] → 반올림 13~23
	assert_int(seen_min).is_greater_equal(13)
	assert_int(seen_max).is_less_equal(23)
	assert_bool(seen_max > seen_min).is_true()  # 날마다 흔들린다
	# 행이 없으면 대문간 가격 × 기본 배율
	assert_int(MarketPrices.sell_price(item, null, 0.6, 1.0, 42, 3)).is_equal(12)
	assert_int(MarketPrices.sell_price(item, null, 0.6, 0.5, 42, 3)).is_equal(6)
	assert_int(MarketPrices.sell_price(_item("key", "key", 0), row, 0.6, 1.0, 42, 3)).is_equal(0)  # 팔 수 없는 것


func test_market_buy_stock_and_open_rule() -> void:
	var seed := _item("seed_cabbage", "seed", 4)
	var row := _row("seed_cabbage", 0.5, 2.0, 0.0, 2)
	var no_buy := _row("m_moss", 1.5, 0.0, 0.0, 0)
	assert_int(MarketPrices.buy_price(seed, row, 1, 1)).is_equal(8)
	assert_int(MarketPrices.buy_price(seed, no_buy, 1, 1)).is_equal(0)
	assert_int(MarketPrices.buyable_rows({"a": row, "b": no_buy}).size()).is_equal(1)
	var inventory := Inventory.new()
	var bought := {}
	assert_int(MarketPrices.buy(inventory, seed, row, bought, 7, 1, 1)).is_equal(0)  # 돈 부족
	assert_int(MarketPrices.buy(inventory, seed, row, bought, 100, 1, 1)).is_equal(8)
	assert_int(MarketPrices.buy(inventory, seed, row, bought, 100, 1, 1)).is_equal(8)
	assert_int(MarketPrices.stock_left(row, bought)).is_equal(0)
	assert_int(MarketPrices.buy(inventory, seed, row, bought, 100, 1, 1)).is_equal(0)  # 재고 소진
	assert_int(inventory.get_count("seed_cabbage")).is_equal(2)
	assert_bool(MarketPrices.is_open(0, 2, false)).is_false()
	assert_bool(MarketPrices.is_open(2, 2, false)).is_true()
	assert_bool(MarketPrices.is_open(0, 2, true)).is_true()
