class_name TestRentVisitorRoll
extends GdUnitTestSuite


func _item(id: String, kind: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.kind = kind
	return item


func _yokai(id: String, rent_type: String, rent_item: String, amount: int, interval: int, join_mode := "start", join_day := 0) -> YokaiData:
	var y := YokaiData.new()
	y.id = id
	y.rent_type = rent_type
	y.rent_item = rent_item
	y.rent_amount = amount
	y.rent_interval_days = interval
	y.join_mode = join_mode
	y.join_day = join_day
	return y


func _species(id: String, rent_type: String, money: int, item: String, amount: int, weight: int, condition := "", omen := 0) -> GuestSpeciesData:
	var s := GuestSpeciesData.new()
	s.id = id
	s.name_ko = id
	s.rent_type = rent_type
	s.rent_money = money
	s.rent_item = item
	s.rent_amount = amount
	s.weight = weight
	s.appear_condition = condition
	s.omen = omen
	return s


func _visitor(id: String, kind: String, weight: int, omen_min: int, omen_max: int, mishap := 0) -> VisitorData:
	var v := VisitorData.new()
	v.id = id
	v.kind = kind
	v.weight = weight
	v.omen_min = omen_min
	v.omen_max = omen_max
	v.mishap_money = mishap
	v.mishap_text_ko = "{name} 사고"
	return v


func _items() -> Dictionary:
	return {"wood": _item("wood", "material"), "scrap": _item("scrap", "material"), "meal": _item("meal", "food")}


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_resolve_item_random_kind_is_deterministic() -> void:
	assert_str(Rent.resolve_item("meal", _items(), _rng(1))).is_equal("meal")
	var picked := Rent.resolve_item("kind:material", _items(), _rng(7))
	assert_array(["wood", "scrap"]).contains([picked])
	assert_str(Rent.resolve_item("kind:material", _items(), _rng(7))).is_equal(picked)
	assert_str(Rent.resolve_item("kind:key", _items(), _rng(7))).is_empty()


func test_resident_rent_types_and_interval() -> void:
	var catalog := {
		"a": _yokai("a", "items", "kind:material", 1, 1),
		"b": _yokai("b", "errand", "", 10, 1),
		"c": _yokai("c", "money", "", 25, 2),
		"d": _yokai("d", "none", "", 0, 1),
	}
	var residents: Array[String] = ["a", "b", "c", "d"]
	var day1 := Rent.settle_residents(residents, catalog, _items(), 1, _rng(3))
	assert_int(day1.payments.size()).is_equal(2)  # c 는 2일마다, d 는 없음
	assert_int(day1.condition_bonus).is_equal(10)
	assert_int(day1.money).is_equal(0)
	assert_int(day1.items.values().reduce(func(acc: int, v: int) -> int: return acc + v, 0)).is_equal(1)
	var day2 := Rent.settle_residents(residents, catalog, _items(), 2, _rng(3))
	assert_int(day2.money).is_equal(25)
	assert_int(day2.payments.size()).is_equal(3)


func test_guest_checkout_pays_and_troublemaker_mishaps() -> void:
	var species := {
		"ibul": _species("ibul", "buff", 30, "", 15, 40),
		"mong": _species("mong", "items", 30, "doodle", 1, 40),
	}
	var visitors := {"v_guest": _visitor("v_guest", "guest", 60, 0, 1), "v_trouble": _visitor("v_trouble", "troublemaker", 10, 1, 3, 25)}
	var guests: Array = [
		{"species_id": "ibul", "visitor_id": "v_guest", "arrived_day": 2, "depart_day": 3, "omen": 0},
		{"species_id": "mong", "visitor_id": "v_trouble", "arrived_day": 2, "depart_day": 3, "omen": 2},
		{"species_id": "ibul", "visitor_id": "v_guest", "arrived_day": 3, "depart_day": 4, "omen": 0},
	]
	var result := Rent.settle_guests(guests, species, visitors, 3)
	assert_int(result.departed.size()).is_equal(2)
	assert_int(result.money).is_equal(60)
	assert_int(result.condition_bonus).is_equal(15)
	assert_dict(result.items).is_equal({"doodle": 1})
	assert_int(result.mishap_money).is_equal(25)
	assert_array(result.mishap_texts).contains_exactly(["mong 사고"])


func test_scripted_arrival_beats_random_roll() -> void:
	var catalog := {"y3": _yokai("y3", "none", "", 0, 1, "intake", 2), "y1": _yokai("y1", "none", "", 0, 1)}
	var residents: Array[String] = ["y1"]
	assert_object(VisitorRoll.scripted(catalog, residents, 1, "v_erased")).is_null()
	var visitor := VisitorRoll.scripted(catalog, residents, 2, "v_erased")
	assert_str(visitor.kind).is_equal("erased")
	assert_str(visitor.yokai_id).is_equal("y3")
	residents.append("y3")
	assert_object(VisitorRoll.scripted(catalog, residents, 2, "v_erased")).is_null()


func test_roll_respects_chance_weights_and_weather() -> void:
	var visitors := {"v_guest": _visitor("v_guest", "guest", 60, 0, 1), "v_erased": _visitor("v_erased", "erased", 0, 0, 0)}
	var species := {"rain_only": _species("rain_only", "info", 40, "", 0, 100, "rain"), "always": _species("always", "buff", 30, "", 15, 1)}
	assert_object(VisitorRoll.roll(visitors, species, _rng(1), 0.0, "clear")).is_null()
	for seed in 20:
		var clear := VisitorRoll.roll(visitors, species, _rng(seed), 1.0, "clear")
		assert_str(clear.species_id).is_equal("always")  # 비 전용 종족은 맑은 날 제외
		assert_str(clear.kind).is_equal("guest")  # weight 0 인 erased 는 절대 안 뽑힘
		assert_int(clear.omen).is_between(0, 1)
	var rainy_seen := {}
	for seed in 40:
		rainy_seen[VisitorRoll.roll(visitors, species, _rng(seed), 1.0, "rain").species_id] = true
	assert_bool(rainy_seen.has("rain_only")).is_true()
