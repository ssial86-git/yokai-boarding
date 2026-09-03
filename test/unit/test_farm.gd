class_name TestFarm
extends GdUnitTestSuite
## 텃밭: 괭이질 → 파종(씨앗 소모) → 물주기 → 하루 성장 → 수확, 요괴 자동 물주기(효율 0.6)의 느린 성장, 직렬화.


func _crop(id: String, grow_days: int, water_per_day: int = 1, yin_bonus: float = 0.0) -> CropData:
	var crop := CropData.new()
	crop.id = id
	crop.seed_item = "seed_%s" % id
	crop.harvest_item = id
	crop.grow_days = grow_days
	crop.water_per_day = water_per_day
	crop.yield_min = 2
	crop.yield_max = 2
	crop.yin_growth_bonus = yin_bonus
	return crop


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return rng


func test_full_cycle_till_sow_water_grow_harvest() -> void:
	var farm := Farm.new(2)
	var radish := _crop("radish", 2)
	var catalog := {"radish": radish}
	var inventory := Inventory.new()
	inventory.add("seed_radish", 1)

	assert_int(farm.sow(0, radish, inventory)).is_equal(Farm.Outcome.NOT_TILLED)
	assert_int(farm.till(0)).is_equal(Farm.Outcome.OK)
	assert_int(farm.till(0)).is_equal(Farm.Outcome.NOT_EMPTY)
	assert_int(farm.water(0)).is_equal(Farm.Outcome.NOT_GROWING)
	assert_int(farm.sow(0, radish, inventory)).is_equal(Farm.Outcome.OK)
	assert_int(inventory.get_count("seed_radish")).is_equal(0)
	assert_int(farm.till(1)).is_equal(Farm.Outcome.OK)
	assert_int(farm.sow(1, radish, inventory)).is_equal(Farm.Outcome.NO_SEED)
	assert_int(farm.sow(9, radish, inventory)).is_equal(Farm.Outcome.OUT_OF_RANGE)

	assert_int(farm.water(0)).is_equal(Farm.Outcome.OK)
	assert_array(farm.advance_day(catalog)).is_empty()
	assert_float(farm.get_plot(0).growth).is_equal(1.0)
	assert_float(farm.get_plot(0).water).is_equal(0.0)  # 물은 마른다
	assert_array(farm.advance_day(catalog)).is_empty()  # 물을 안 주면 자라지 않는다
	assert_float(farm.get_plot(0).growth).is_equal(1.0)
	farm.water(0)
	assert_array(farm.advance_day(catalog)).contains_exactly([0])
	assert_int(farm.get_plot(0).state).is_equal(Farm.PlotState.READY)
	assert_dict(farm.harvest(1, catalog, _rng())).is_empty()
	var result := farm.harvest(0, catalog, _rng())
	assert_str(str(result["item"])).is_equal("radish")
	assert_int(int(result["count"])).is_equal(2)
	assert_int(farm.get_plot(0).state).is_equal(Farm.PlotState.TILLED)  # 수확한 칸은 갈아 둔 채로 남는다


func test_auto_water_efficiency_grows_slower_and_yin_bonus() -> void:
	var farm := Farm.new(1)
	var moon := _crop("moon", 3, 1, 1.0)
	var catalog := {"moon": moon}
	var inventory := Inventory.new()
	inventory.add("seed_moon", 1)
	farm.till(0)
	farm.sow(0, moon, inventory)
	assert_int(farm.water_all(0.6)).is_equal(1)
	farm.advance_day(catalog)
	assert_float(farm.get_plot(0).growth).is_equal_approx(0.6, 0.0001)  # 요괴 물주기 = 하루에 0.6일
	farm.water_all(0.6)
	farm.water_all(0.6)  # 두 번 주면 1.0 으로 잘린다
	assert_float(farm.get_plot(0).water).is_equal(1.0)
	farm.advance_day(catalog, true)  # 음기 짙은 날: 마계 작물 2배
	assert_float(farm.get_plot(0).growth).is_equal_approx(2.6, 0.0001)
	farm.water(0)
	assert_array(farm.advance_day(catalog)).contains_exactly([0])


func test_expand_and_serialization_roundtrip() -> void:
	var farm := Farm.new(2)
	farm.expand(4)
	assert_int(farm.size()).is_equal(4)
	farm.expand(1)
	assert_int(farm.size()).is_equal(4)
	var inventory := Inventory.new()
	inventory.add("seed_radish", 1)
	farm.till(2)
	farm.sow(2, _crop("radish", 3), inventory)
	farm.water(2, 0.6)
	var restored := Farm.new()
	assert_bool(restored.from_dict(farm.to_dict())).is_true()
	assert_int(restored.size()).is_equal(4)
	assert_int(restored.get_plot(2).state).is_equal(Farm.PlotState.GROWING)
	assert_str(restored.get_plot(2).crop_id).is_equal("radish")
	assert_float(restored.get_plot(2).water).is_equal_approx(0.6, 0.0001)
	assert_int(restored.count_state(Farm.PlotState.EMPTY)).is_equal(3)
	assert_bool(restored.from_dict({"plots": "x"})).is_false()
	assert_bool(restored.from_dict({"plots": [1]})).is_false()
