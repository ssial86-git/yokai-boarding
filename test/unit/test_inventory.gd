class_name TestInventory
extends GdUnitTestSuite


func test_add_remove_count() -> void:
	var inv := Inventory.new()
	assert_bool(inv.is_empty()).is_true()
	inv.add("meal", 2)
	inv.add("meal", 3)
	inv.add("wood", 0)
	inv.add("", 5)
	assert_int(inv.get_count("meal")).is_equal(5)
	assert_int(inv.get_count("wood")).is_equal(0)
	assert_bool(inv.has("meal", 5)).is_true()
	assert_bool(inv.has("meal", 6)).is_false()
	assert_bool(inv.remove("meal", 6)).is_false()
	assert_int(inv.get_count("meal")).is_equal(5)
	assert_bool(inv.remove("meal", 5)).is_true()
	assert_bool(inv.is_empty()).is_true()


func test_serialization_round_trip_and_validation() -> void:
	var inv := Inventory.new()
	inv.add("meal", 2)
	inv.add("trinket", 1)
	var data := inv.to_dict()
	var restored := Inventory.new()
	assert_bool(restored.from_dict({"meal": 2.0, "trinket": 1.0, "zero": 0.0})).is_true()
	assert_dict(restored.to_dict()).is_equal(data)
	assert_bool(restored.from_dict({"meal": -1})).is_false()
	assert_bool(restored.from_dict({"meal": 1.5})).is_false()
	assert_bool(restored.from_dict({"meal": "x"})).is_false()
	assert_dict(restored.to_dict()).is_equal(data)
