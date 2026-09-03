class_name TestMarket
extends GdUnitTestSuite
## 판매: 팔 수 있는 종류·가격·창고 차감.


func _item(id: String, kind: String, value: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.kind = kind
	item.base_value = value
	return item


func _catalog() -> Dictionary:
	return {
		"dish": _item("dish", "food", 14),
		"wood": _item("wood", "material", 6),
		"seed_radish": _item("seed_radish", "seed", 3),
		"record_piece": _item("record_piece", "key", 0),
		"doodle": _item("doodle", "misc", 3),
	}


func test_sellable_and_price() -> void:
	var catalog := _catalog()
	assert_bool(Market.is_sellable(catalog["dish"])).is_true()
	assert_bool(Market.is_sellable(catalog["seed_radish"])).is_false()
	assert_bool(Market.is_sellable(catalog["record_piece"])).is_false()
	assert_bool(Market.is_sellable(null)).is_false()
	assert_int(Market.unit_price(catalog["dish"], 1.0)).is_equal(14)
	assert_int(Market.unit_price(catalog["dish"], 0.5)).is_equal(7)
	assert_int(Market.unit_price(catalog["doodle"], 0.1)).is_equal(1)  # 최소 1
	assert_int(Market.unit_price(catalog["seed_radish"], 1.0)).is_equal(0)


func test_sell_removes_from_inventory() -> void:
	var catalog := _catalog()
	var inventory := Inventory.new()
	inventory.add("dish", 2)
	inventory.add("wood", 5)
	inventory.add("seed_radish", 3)
	assert_array(Market.sellable_ids(inventory, catalog)).contains_exactly(["dish", "wood"])
	assert_int(Market.sell(inventory, catalog, "dish", 2, 1.0)).is_equal(28)
	assert_int(inventory.get_count("dish")).is_equal(0)
	assert_int(Market.sell(inventory, catalog, "wood", 9, 1.0)).is_equal(0)  # 모자라면 팔지 않는다
	assert_int(inventory.get_count("wood")).is_equal(5)
	assert_int(Market.sell(inventory, catalog, "seed_radish", 1, 1.0)).is_equal(0)
	assert_int(Market.sell(inventory, catalog, "missing", 1, 1.0)).is_equal(0)
